import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/config_profile_page.dart';
import 'package:snarf/pages/account/edit_user_page.dart';
import 'package:snarf/pages/account/initial_page.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/parties/create_edit_party_page.dart';
import 'package:snarf/pages/parties/party_details_page.dart';
import 'package:snarf/pages/places/create_edit_place_page.dart';
import 'package:snarf/pages/places/place_details_page.dart';
import 'package:snarf/pages/privateChat/private_chat_navigation_page.dart';
import 'package:snarf/pages/public_chat_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/location_service.dart';
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
  final _locationService = LocationService();
  late LocationData _currentLocation;
  bool _isLocationLoaded = false;
  late MapController _mapController;
  Marker? _userLocationMarker;
  final Map<String, Marker> _userMarkers = {};
  final Map<String, Marker> _partyMarkers = {};
  final Map<String, Marker> _placeMarkers = {};
  late String userImage = '';
  double _opacity = 0.0;
  late Timer _timer;
  String? _fcmToken;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  IconData getPartyTypeIcon(int type) {
    switch (type) {
      case 0:
        return Icons.local_fire_department;
      case 1:
        return Icons.bolt;
      case 2:
        return Icons.handshake;
      case 3:
        return Icons.emoji_people;
      case 4:
        return Icons.favorite;
      case 5:
        return Icons.star;
      default:
        return Icons.event;
    }
  }

  IconData getPlaceTypeIcon(int type) {
    switch (type) {
      case 0:
        return Icons.fitness_center;
      case 1:
        return Icons.wc;
      case 2:
        return Icons.local_bar;
      case 3:
        return Icons.local_cafe;
      case 4:
        return Icons.shower;
      case 5:
        return Icons.event;
      case 6:
        return Icons.videogame_asset;
      case 7:
        return Icons.hotel;
      case 8:
        return Icons.device_unknown;
      case 9:
        return Icons.local_shipping;
      case 10:
        return Icons.park;
      case 11:
        return Icons.beach_access;
      case 12:
        return Icons.hot_tub;
      default:
        return Icons.place;
    }
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeApp();
    _startOpacityAnimation();
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
    await _fetchFirstMessage();
    await _getAllParties();
    await _getAllPlaces();
    await _analytics
        .logEvent(name: 'app_initialized', parameters: {'screen': 'HomePage'});
  }

  Future<void> _getFcmToken() async {
    String? fcmToken = "";
    if (Platform.isIOS) {
      fcmToken = await FirebaseMessaging.instance.getAPNSToken();
    } else if (Platform.isAndroid) {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } else {
      throw Exception("Plataforma não suportada ${Platform.operatingSystem}");
    }
    if (fcmToken != null) {
      _fcmToken = fcmToken;
      await _analytics.logEvent(
          name: 'fcm_token_received',
          parameters: {'token_length': fcmToken.length});
    }
  }

  Future<void> _fetchFirstMessage() async {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    final messageData = await ApiService.getFirstMessageOfDay();
    if (messageData != null && messageData['firstMessageToDay'] != null) {
      config.setFirstMessageToday(
          DateTime.parse(messageData['firstMessageToDay']));
    }
  }

  Future<void> _loadUserInfo() async {
    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showErrorSnackbar(context, 'Não foi possível obter ID do token');
      await _analytics.logEvent(
          name: 'error', parameters: {'message': 'Falha ao obter ID do token'});
      return;
    }
    final userInfo = await ApiService.getUserInfoById(userId);
    if (userInfo != null) {
      userImage = userInfo['imageUrl'];
    } else {
      showErrorSnackbar(context, 'Erro ao carregar informações do usuário');
      await _analytics.logEvent(name: 'error', parameters: {
        'message': 'Falha ao carregar informações do usuário',
        'user_id': userId
      });
      await _logout(context);
    }
  }

  Future<void> _initializeLocation() async {
    final ok = await _locationService.initialize();
    if (ok) {
      _currentLocation = await _locationService.getCurrentLocation();
      setState(() {
        _isLocationLoaded = true;
        _updateUserMarker(
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        );
      });

      Future.delayed(const Duration(seconds: 60), () {
        _locationService.startUpdates();
      });

      _locationService.onLocationChanged.listen((loc) async {
        setState(() {
          _currentLocation = loc;
          _updateUserMarker(loc.latitude!, loc.longitude!);
        });
        await _sendLocationUpdate();
      });
    }
    else{
      throw Exception("Erro ao inicializar localização");
    }
  }

  Future<void> _setupSignalRConnection() async {
    SignalRManager().listenToEvent("ReceiveMessage", _onReceiveMessage);
    await _analytics.logEvent(name: 'signalr_connection_initialized');
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
          parameters: {'type': message['Type']});
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
              parameters: {'type': message['Type']});
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'signalr_process_error', parameters: {'error': e.toString()});
    }
  }

  void _handleReceiveLocation(Map<String, dynamic> data) {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    final userId = data['userId'];
    final latitude = data['Latitude'];
    final longitude = data['Longitude'];
    final userImg = data['userImage'];
    final videoCall = data['videoCall'];
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
                  border: Border.all(color: config.customGreen, width: 4.0),
                ),
                child: CircleAvatar(
                  backgroundImage: InterceptedImageProvider(
                    originalProvider: NetworkImage(userImg),
                    hideImages: config.hideImages,
                  ),
                  radius: 25,
                ),
              ),
              if (videoCall)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                        color: config.customOrange, shape: BoxShape.circle),
                    child: Icon(Icons.videocam,
                        color: config.customWhite, size: 14),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                      color: config.customGreen, shape: BoxShape.circle),
                  child:
                      Icon(Icons.person, color: config.customWhite, size: 14),
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
    await _analytics
        .logEvent(name: 'user_disconnected', parameters: {'user_id': userId});
  }

  Future<void> _sendLocationUpdate() async {
    try {
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      await SignalRManager().sendSignalRMessage(
        SignalREventType.MapUpdateLocation,
        {
          "Latitude": _currentLocation.latitude,
          "Longitude": _currentLocation.longitude,
          "FcmToken": _fcmToken,
          "VideoCall": configProvider.hideVideoCall,
        },
      );
      await _analytics.logEvent(
        name: 'location_update_sent',
        parameters: {
          'latitude': _currentLocation.latitude!,
          'longitude': _currentLocation.longitude!,
          "VideoCall": configProvider.hideVideoCall,
        },
      );
    } catch (e) {
      await _analytics.logEvent(
          name: 'location_update_failed', parameters: {'error': e.toString()});
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
              border: Border.all(color: config.customGreen, width: 4.0),
            ),
            child: CircleAvatar(
              backgroundImage: InterceptedImageProvider(
                originalProvider: NetworkImage(userImage),
                hideImages: false,
              ),
              radius: 25,
            ),
          ),
          if (config.hideVideoCall)
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                    color: config.customOrange, shape: BoxShape.circle),
                child:
                    Icon(Icons.videocam, color: config.customWhite, size: 20),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                  color: config.customGreen, shape: BoxShape.circle),
              child: Icon(Icons.person, color: config.customWhite, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getAllParties() async {
    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) return;
    final result = await ApiService.getAllParties(userId);
    if (result != null && result['data'] != null) {
      final List parties = result['data'];
      for (var p in parties) {
        final id = p['id'].toString();
        final lat = p['latitude'] is double ? p['latitude'] : 0.0;
        final lon = p['longitude'] is double ? p['longitude'] : 0.0;
        final title = p['title'].toString();
        final imageUrl = p['imageUrl'].toString();
        final userRole = p['userRole'].toString();
        final partyType = p['type'] ?? 0;
        _addPartyMarker(id, lat, lon, title, imageUrl, userRole, partyType);
      }
      setState(() {});
    }
  }

  Future<void> _getAllPlaces() async {
    final result = await ApiService.getAllPlaces();
    if (result != null && result['data'] != null) {
      final List places = result['data'];
      for (var place in places) {
        final id = place['id'].toString();
        final lat = place['latitude'] is double ? place['latitude'] : 0.0;
        final lon = place['longitude'] is double ? place['longitude'] : 0.0;
        final title = place['title'].toString();
        final imageUrl = place['imageUrl'].toString();
        final placeType = place['type'] ?? 0;
        _addPlaceMarker(id, lat, lon, title, imageUrl, placeType);
      }
      setState(() {});
    }
  }

  void _addPartyMarker(String partyId, double lat, double lon, String title,
      String imageUrl, String userRole, int type) {
    _partyMarkers[partyId] = Marker(
      point: LatLng(lat, lon),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () => _openPartyDetails(partyId),
        child: CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(getPartyTypeIcon(type), color: Colors.white),
        ),
      ),
    );
  }

  void _addPlaceMarker(String placeId, double lat, double lon, String title,
      String imageUrl, int type) {
    _placeMarkers[placeId] = Marker(
      point: LatLng(lat, lon),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () => _openPlaceDetails(placeId),
        child: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(getPlaceTypeIcon(type), color: Colors.white),
        ),
      ),
    );
  }

  void _openPartyDetails(String partyId) async {
    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyDetailsPage(
          partyId: partyId,
          userId: userId,
        ),
      ),
    );
  }

  void _openPlaceDetails(String placeId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailsPage(placeId: placeId),
      ),
    );
  }

  void _recenterMap() async {
    if (_isLocationLoaded) {
      _mapController.move(
          LatLng(_currentLocation.latitude!, _currentLocation.longitude!),
          15.0);
      await _analytics.logEvent(name: 'map_recentering', parameters: {
        'latitude': _currentLocation.latitude!,
        'longitude': _currentLocation.longitude!
      });
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
        name: 'open_other_user_profile', parameters: {'user_id': userId});
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewUserPage(userId: userId)),
    );
  }

  void _openPrivateChat(BuildContext context) async {
    await _analytics.logEvent(name: 'open_private_chat');
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
                        top: Radius.circular(30), bottom: Radius.circular(30)),
                    child: Scaffold(
                      body: PrivateChatNavigationPage(
                          scrollController: scrollController),
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
    await _analytics.logEvent(name: 'open_public_chat');
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    log("Abrindo chat para assinante: ${configProvider.isSubscriber}");
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
                        color: configProvider.secondaryColor, width: 5)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.9,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30), bottom: Radius.circular(30)),
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
          offset.dx, offset.dy, offset.dx + 50, offset.dy + 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: configProvider.secondaryColor, width: 3),
      ),
      items: [
        PopupMenuItem(
          value: 'config',
          child: Row(
            children: [
              Icon(Icons.person, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text("Meu Perfil",
                  style:
                      TextStyle(fontSize: 16, color: configProvider.textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'profile_settings',
          child: Row(
            children: [
              Icon(Icons.settings, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text("Configurações de Perfil",
                  style:
                      TextStyle(fontSize: 16, color: configProvider.textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'create_party',
          child: Row(
            children: [
              Icon(Icons.add, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text("Criar festa",
                  style:
                      TextStyle(fontSize: 16, color: configProvider.textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'create_place',
          child: Row(
            children: [
              Icon(Icons.add, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text("Criar local",
                  style:
                      TextStyle(fontSize: 16, color: configProvider.textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          enabled: true,
          child: SwitchListTile(
            title: Text("Modo Noturno",
                style:
                    TextStyle(fontSize: 16, color: configProvider.textColor)),
            secondary:
                Icon(Icons.brightness_6, color: configProvider.iconColor),
            value: configProvider.isDarkMode,
            onChanged: (_) async {
              Navigator.pop(context);
              configProvider.toggleTheme();
              await _analytics.logEvent(
                  name: 'toggle_dark_mode',
                  parameters: {'value': configProvider.isDarkMode});
            },
          ),
        ),
        PopupMenuItem(
          enabled: true,
          child: SwitchListTile(
            title: Text("Modo Vanilla",
                style:
                    TextStyle(fontSize: 16, color: configProvider.textColor)),
            secondary: Icon(
                configProvider.hideImages
                    ? Icons.image_not_supported
                    : Icons.image,
                color: configProvider.iconColor),
            value: configProvider.hideImages,
            onChanged: (_) async {
              Navigator.pop(context);
              configProvider.toggleHideImages();
              await _analytics.logEvent(
                  name: 'toggle_hide_images',
                  parameters: {'value': configProvider.hideImages});
            },
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.exit_to_app, color: configProvider.iconColor),
              const SizedBox(width: 10),
              Text("Sair",
                  style:
                      TextStyle(fontSize: 16, color: configProvider.textColor)),
            ],
          ),
        ),
      ],
      elevation: 8.0,
    ).then((value) async {
      if (value == 'config') {
        await _analytics.logEvent(name: 'open_profile_edit');
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const EditUserPage()));
      } else if (value == 'profile_settings') {
        await _analytics.logEvent(name: 'open_profile_settings');
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const ConfigProfilePage()));
      } else if (value == 'create_party') {
        await _analytics.logEvent(name: 'open_create_party');
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateEditPartyPage()));
      } else if (value == 'create_place') {
        await _analytics.logEvent(name: 'open_create_place');
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateEditPlacePage()));
      } else if (value == 'logout') {
        await _logout(context);
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    await _analytics.logEvent(name: 'logout');
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const InitialPage()));
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
        child: Icon(icon, color: configProvider.iconColor, size: 24),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    final markersToDisplay = <Marker>[];
    if (_userLocationMarker != null) {
      markersToDisplay.add(_userLocationMarker!);
    }
    markersToDisplay.addAll(_userMarkers.values);
    markersToDisplay.addAll(_partyMarkers.values);
    markersToDisplay.addAll(_placeMarkers.values);
    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            configProvider.isDarkMode
                ? Image.asset('assets/images/logo-black.png', height: 30)
                : Image.asset('assets/images/logo-white.png', height: 30),
          ],
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon:
              Icon(Icons.filter_list_rounded, color: configProvider.iconColor),
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
              child: Icon(Icons.settings, color: configProvider.iconColor),
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
                            LatLng(widget.initialLatitude!,
                                widget.initialLongitude!),
                            15.0,
                          );
                        }
                      });
                    },
                    initialCenter: LatLng(_currentLocation.latitude!,
                        _currentLocation.longitude!),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                  ),
                  children: [
                    TileLayer(urlTemplate: _getMapUrl(context)),
                    MarkerLayer(markers: markersToDisplay),
                  ],
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.location_on, color: configProvider.iconColor),
                    const SizedBox(width: 8),
                    Text('Carregando Conteúdo',
                        style: TextStyle(color: configProvider.textColor)),
                  ]),
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
              await _analytics.logEvent(name: 'crop_button_pressed');
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
            configProvider.ClearNotification();
            _openPrivateChat(context);
          } else if (index == 1) {
            _openPublicChat(context);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat),
                if (configProvider.countNotificationMessage > 0)
                  Positioned(
                    right: -4,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        configProvider.countNotificationMessage.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.group), label: ''),
        ],
      ),
    );
  }
}
