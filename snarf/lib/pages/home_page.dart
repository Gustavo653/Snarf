import 'dart:async';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import 'package:snarf/pages/account/edit_user_page.dart';
import 'package:snarf/pages/account/initial_page.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/privateChat/private_chat_navigation_page.dart';
import 'package:snarf/pages/public_chat_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class HomePage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const HomePage({super.key, this.initialLatitude, this.initialLongitude});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late LocationData _currentLocation;
  bool _isLocationLoaded = false;
  late MapController _mapController;
  late Marker _userLocationMarker;
  final Map<String, Marker> _userMarkers = {};
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  late String userImage = '';
  double _opacity = 0.0;
  late Timer _timer;
  String? _fcmToken;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeApp();
    _startOpacityAnimation();

    _analytics.logScreenView(
      screenName: 'HomePage',
      screenClass: 'HomePage',
    );
  }

  void _startOpacityAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _opacity = _opacity == 0.0 ? 1.0 : 0.0;
      });
    });
  }

  Future<void> _initializeApp() async {
    await _loadUserInfo();
    await _getFcmToken();
    await _initializeLocation();
    await _setupSignalRConnection();

    await _analytics.logEvent(
      name: 'app_initialized',
      parameters: {
        'screen': 'HomePage',
      },
    );
  }

  Future<void> _getFcmToken() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      _fcmToken = fcmToken;

      await _analytics.logEvent(
        name: 'fcm_token_received',
        parameters: {
          'token_length': fcmToken.length,
        },
      );
    }
  }

  Future<void> _loadUserInfo() async {
    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showSnackbar(context, 'Não foi possível obter ID do token');

      await _analytics.logEvent(
        name: 'error',
        parameters: {
          'message': 'Falha ao obter ID do token',
        },
      );
      return;
    }

    final userInfo = await ApiService.getUserInfoById(userId);
    if (userInfo != null) {
      userImage = userInfo['imageUrl'];
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');

      await _analytics.logEvent(
        name: 'error',
        parameters: {
          'message': 'Falha ao carregar informações do usuário',
          'user_id': userId,
        },
      );
    }
  }

  Future<void> _initializeLocation() async {
    if (await _checkLocationPermissions()) {
      _getCurrentLocation();
      _startLocationUpdates();
    }
  }

  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        await _analytics.logEvent(
          name: 'location_service_disabled',
        );
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        await _analytics.logEvent(
          name: 'location_permission_denied',
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _location.getLocation();
      setState(() {
        _isLocationLoaded = true;
        _updateUserMarker(
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        );
      });

      await _analytics.logEvent(
        name: 'location_obtained',
        parameters: {
          'latitude': _currentLocation.latitude!,
          'longitude': _currentLocation.longitude!,
        },
      );
    } catch (err) {
      showSnackbar(context, "Erro ao recuperar localização: $err");

      await _analytics.logEvent(
        name: 'location_error',
        parameters: {
          'error': err.toString(),
        },
      );
    }
  }

  void _startLocationUpdates() {
    _location.changeSettings(accuracy: LocationAccuracy.high, interval: 5000);

    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLocation) async {
      setState(() {
        _currentLocation = newLocation;
        _updateUserMarker(newLocation.latitude!, newLocation.longitude!);
      });
      if (_currentLocation.longitude != null &&
          _currentLocation.latitude != null) {
        await _sendLocationUpdate();
      }
    });
  }

  Future<void> _setupSignalRConnection() async {
    SignalRManager().listenToEvent("ReceiveMessage", _onReceiveMessage);

    await _analytics.logEvent(
      name: 'signalr_connection_initialized',
    );
  }

  void _onReceiveMessage(List<Object?>? args) async {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);

      final SignalREventType type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == message['Type'],
        orElse: () => SignalREventType.MapReceiveLocation,
      );

      final dynamic data = message['Data'];

      await _analytics.logEvent(
        name: 'signalr_message_received',
        parameters: {
          'type': message['Type'],
        },
      );

      switch (type) {
        case SignalREventType.MapReceiveLocation:
          _handleReceiveLocation(data);
          break;
        case SignalREventType.UserDisconnected:
          _handleUserDisconnected(data);
          break;
        default:
          await _analytics.logEvent(
            name: 'signalr_unrecognized_event',
            parameters: {
              'type': message['Type'],
            },
          );
      }
    } catch (e) {
      await _analytics.logEvent(
        name: 'signalr_process_error',
        parameters: {
          'error': e.toString(),
        },
      );
    }
  }

  void _handleReceiveLocation(Map<String, dynamic> data) {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    final userId = data['userId'];
    final latitude = data['Latitude'];
    final longitude = data['Longitude'];
    final userImg = data['userImage'];

    setState(() {
      _userMarkers[userId] = Marker(
        point: LatLng(latitude, longitude),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _openProfile(userId),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: config.customGreen,
                    width: 4.0,
                  ),
                ),
                child: CircleAvatar(
                  backgroundImage: InterceptedImageProvider(
                    originalProvider: NetworkImage(userImg),
                    hideImages: config.hideImages,
                  ),
                  radius: 25,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: config.customOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: config.customWhite,
                    size: 14,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: config.customGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: config.customWhite,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _handleUserDisconnected(Map<String, dynamic> data) async {
    final userId = data['userId'];
    setState(() {
      _userMarkers.remove(userId);
    });

    await _analytics.logEvent(
      name: 'user_disconnected',
      parameters: {
        'user_id': userId,
      },
    );
  }

  Future<void> _sendLocationUpdate() async {
    try {
      await SignalRManager()
          .sendSignalRMessage(SignalREventType.MapUpdateLocation, {
        "Latitude": _currentLocation.latitude,
        "Longitude": _currentLocation.longitude,
        "FcmToken": _fcmToken,
      });

      await _analytics.logEvent(
        name: 'location_update_sent',
        parameters: {
          'latitude': _currentLocation.latitude!,
          'longitude': _currentLocation.longitude!,
        },
      );
    } catch (e) {
      await _analytics.logEvent(
        name: 'location_update_failed',
        parameters: {
          'error': e.toString(),
        },
      );
    }
  }

  void _updateUserMarker(double latitude, double longitude) {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    _userLocationMarker = Marker(
      point: LatLng(latitude, longitude),
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: config.customGreen,
                width: 4.0,
              ),
            ),
            child: CircleAvatar(
              backgroundImage: InterceptedImageProvider(
                originalProvider: NetworkImage(userImage),
                hideImages: false,
              ),
              radius: 25,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: config.customOrange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam,
                color: config.customWhite,
                size: 20,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: config.customGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: config.customWhite,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _recenterMap() async {
    if (_isLocationLoaded) {
      _mapController.move(
        LatLng(
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        ),
        15.0,
      );

      await _analytics.logEvent(
        name: 'map_recentering',
        parameters: {
          'latitude': _currentLocation.latitude!,
          'longitude': _currentLocation.longitude!,
        },
      );
    }
  }

  String _getMapUrl(BuildContext context) {
    final isDarkMode = Provider.of<ConfigProvider>(context).isDarkMode;
    return isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  }

  void _openProfile(String userId) async {
    await _analytics.logEvent(
      name: 'open_other_user_profile',
      parameters: {
        'user_id': userId,
      },
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewUserPage(userId: userId),
      ),
    );
  }

  void _openPrivateChat(BuildContext context) async {
    await _analytics.logEvent(
      name: 'open_private_chat',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 50),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Provider.of<ConfigProvider>(context, listen: false)
                        .secondaryColor,
                    width: 5,
                  ),
                ),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.9,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                      bottom: Radius.circular(30),
                    ),
                    child: Scaffold(
                      body: PrivateChatNavigationPage(
                        scrollController: scrollController,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPublicChat(BuildContext context) async {
    await _analytics.logEvent(
      name: 'open_public_chat',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 50),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Provider.of<ConfigProvider>(context, listen: false)
                        .secondaryColor,
                    width: 5,
                  ),
                ),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.9,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                      bottom: Radius.circular(30),
                    ),
                    child: Scaffold(
                      body: PublicChatPage(scrollController: scrollController),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomMenu(BuildContext context, Offset offset) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    showMenu(
      context: context,
      color: configProvider.primaryColor,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 50,
        offset.dy + 50,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: configProvider.secondaryColor,
          width: 3,
        ),
      ),
      items: [
        PopupMenuItem(
          value: 'config',
          child: Row(
            children: [
              Icon(Icons.person, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text(
                "Meu Perfil",
                style: TextStyle(fontSize: 16, color: configProvider.textColor),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: SwitchListTile(
            title: Text(
              "Modo Noturno",
              style: TextStyle(fontSize: 16, color: configProvider.textColor),
            ),
            secondary:
                Icon(Icons.brightness_6, color: configProvider.iconColor),
            value: configProvider.isDarkMode,
            onChanged: (bool value) async {
              Navigator.pop(context);

              await _analytics.logEvent(
                name: 'toggle_dark_mode',
                parameters: {'value': value},
              );

              configProvider.toggleTheme();
            },
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: SwitchListTile(
            title: Text(
              "Modo Vanilla",
              style: TextStyle(fontSize: 16, color: configProvider.textColor),
            ),
            secondary: Icon(
              configProvider.hideImages
                  ? Icons.image_not_supported
                  : Icons.image,
              color: configProvider.iconColor,
            ),
            value: configProvider.hideImages,
            onChanged: (bool value) async {
              Navigator.pop(context);

              await _analytics.logEvent(
                name: 'toggle_hide_images',
                parameters: {'value': value},
              );

              configProvider.toggleHideImages();
            },
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.exit_to_app, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text(
                "Sair",
                style: TextStyle(fontSize: 16, color: configProvider.textColor),
              ),
            ],
          ),
        ),
      ],
      elevation: 8.0,
    ).then((value) async {
      if (value == 'config') {
        await _analytics.logEvent(name: 'open_profile_edit');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditUserPage()),
        );
      } else if (value == 'logout') {
        await _analytics.logEvent(name: 'logout');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const InitialPage()),
        );
      }
    });
  }

  Widget _buildFloatingButton(IconData icon, VoidCallback onPressed) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: RawMaterialButton(
        onPressed: onPressed,
        shape: const CircleBorder(),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: const EdgeInsets.all(8),
        fillColor: Colors.transparent,
        splashColor: Colors.transparent,
        elevation: 0,
        child: Icon(
          icon,
          color: configProvider.iconColor,
          size: 24,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            configProvider.isDarkMode
                ? Image.asset(
                    'assets/images/logo-black.png',
                    height: 30,
                  )
                : Image.asset(
                    'assets/images/logo-white.png',
                    height: 30,
                  ),
          ],
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.filter_list_rounded,
            color: configProvider.iconColor,
          ),
          onPressed: () async {
            await _analytics.logEvent(name: 'menu_button_pressed');
          },
        ),
        actions: [
          GestureDetector(
            onTapDown: (TapDownDetails details) {
              _showCustomMenu(context, details.globalPosition);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(
                Icons.settings,
                color: configProvider.iconColor,
              ),
            ),
          ),
        ],
      ),
      body: _isLocationLoaded
          ? Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    onMapReady: () {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (widget.initialLatitude != null &&
                            widget.initialLongitude != null) {
                          _mapController.move(
                            LatLng(
                              widget.initialLatitude!,
                              widget.initialLongitude!,
                            ),
                            15.0,
                          );
                        }
                      });
                    },
                    initialCenter: LatLng(
                      _currentLocation.latitude!,
                      _currentLocation.longitude!,
                    ),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(urlTemplate: _getMapUrl(context)),
                    MarkerLayer(
                      markers: [
                        _userLocationMarker,
                        ..._userMarkers.values,
                      ],
                    ),
                  ],
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: configProvider.iconColor),
                      const SizedBox(width: 8),
                      Text(
                        'Carregando Conteúdo',
                        style: TextStyle(color: configProvider.textColor),
                      ),
                    ],
                  ),
                  AnimatedOpacity(
                    duration: const Duration(seconds: 2),
                    opacity: _opacity,
                    child: Image.asset(
                      configProvider.isDarkMode
                          ? 'assets/images/small-logo-black.png'
                          : 'assets/images/small-logo-white.png',
                      width: 30,
                    ),
                  )
                ],
              ),
            ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFloatingButton(Icons.flight, () async {
              await _analytics.logEvent(name: 'flight_button_pressed');
            }),
            _buildFloatingButton(Icons.remove_red_eye, () async {
              await _analytics.logEvent(name: 'eye_button_pressed');
            }),
            _buildFloatingButton(Icons.crop_free, () async {
              await _analytics.logEvent(name: 'moldura_button_pressed');
            }),
            _buildFloatingButton(Icons.my_location, () {
              _recenterMap();
            }),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: configProvider.primaryColor,
        selectedItemColor: configProvider.iconColor,
        unselectedItemColor: configProvider.iconColor,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) async {
          if (index == 0) {
            _openPrivateChat(context);
          } else if (index == 1) {
            _openPublicChat(context);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: '',
          ),
        ],
      ),
    );
  }
}
