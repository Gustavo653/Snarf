import 'dart:async';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
import 'package:snarf/providers/call_manager.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/distance_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class ViewUserPage extends StatefulWidget {
  final String userId;

  const ViewUserPage({super.key, required this.userId});

  @override
  _ViewUserPageState createState() => _ViewUserPageState();
}

class _ViewUserPageState extends State<ViewUserPage> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  String? _userName;
  String? _userEmail;
  String? _userImageUrl;
  double? _latitude;
  double? _longitude;
  DateTime? _lastActivity;
  bool _isLoading = true;
  double? _myLatitude;
  double? _myLongitude;
  bool _isFavorite = false;

  bool get _isOnline {
    if (_lastActivity == null) return false;
    final difference = DateTime.now().difference(_lastActivity!);
    return difference.inMinutes < 1;
  }

  @override
  void initState() {
    super.initState();
    _analytics.logScreenView(
        screenName: 'ViewUserPage', screenClass: 'ViewUserPage');
    _loadUserInfo();
  }

  Future<void> _initLocation() async {
    Location location = Location();
    var position = await location.getLocation();
    _myLatitude = position.latitude;
    _myLongitude = position.longitude;
  }

  Future<void> _loadUserInfo() async {
    await _initLocation();
    SignalRManager().listenToEvent("ReceiveMessage", _handleSignalRMessage);
    final userInfo = await ApiService.getUserInfoById(widget.userId);
    if (userInfo != null) {
      setState(() {
        _userName = userInfo['name'];
        _userEmail = userInfo['email'];
        _userImageUrl = userInfo['imageUrl'];
        _lastActivity = DateTime.parse(userInfo['lastActivity']).toLocal();
        _latitude = (userInfo['lastLatitude'] as num).toDouble();
        _longitude = (userInfo['lastLongitude'] as num).toDouble();
        _isLoading = false;
      });
      await _analytics.logEvent(
          name: 'view_user_info_loaded', parameters: {'userId': widget.userId});
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');
      setState(() => _isLoading = false);
      await _analytics.logEvent(
          name: 'view_user_info_error', parameters: {'userId': widget.userId});
    }
  }

  void _handleSignalRMessage(List<Object?>? args) async {
    if (args == null || args.isEmpty) return;
    try {
      final Map<String, dynamic> data = jsonDecode(args[0] as String);
      final String? eventType = data['Type'];
      if (eventType == null) return;
      if (eventType ==
          SignalREventType.MapReceiveLocation.toString().split('.').last) {
        final mapData = data['Data'] as Map<String, dynamic>;
        final String userId = mapData['userId'];
        if (userId == widget.userId) {
          setState(() {
            _latitude = (mapData['Latitude'] as num).toDouble();
            _longitude = (mapData['Longitude'] as num).toDouble();
            _lastActivity = DateTime.now();
          });
          await _analytics.logEvent(
              name: 'view_user_location_update',
              parameters: {
                'userId': widget.userId,
                'latitude': _latitude!,
                'longitude': _longitude!
              });
        }
      } else if (eventType ==
          SignalREventType.UserDisconnected.toString().split('.').last) {
        final mapData = data['Data'] as Map<String, dynamic>;
        final String userId = mapData['userId'];
        if (userId == widget.userId) {
          setState(() {
            _lastActivity = DateTime.now().subtract(const Duration(days: 1));
          });
          await _analytics.logEvent(
              name: 'view_user_disconnected',
              parameters: {'userId': widget.userId});
        }
      } else if (eventType ==
          SignalREventType.PrivateChatReceiveFavorites.toString()
              .split('.')
              .last) {
        final List<dynamic> favorites = data['Data'] as List<dynamic>;
        for (var item in favorites) {
          if (item is Map<String, dynamic> && item['Id'] == widget.userId) {
            setState(() {
              _isFavorite = true;
            });
            await _analytics.logEvent(
                name: 'view_user_favorite_detected',
                parameters: {'userId': widget.userId});
            break;
          }
        }
      }
    } catch (e) {
      showSnackbar(context, "Erro ao processar favoritos: $e");
      await _analytics.logEvent(
          name: 'view_user_signalr_error', parameters: {'error': e.toString()});
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatRemoveFavorite,
          {'ChatUserId': widget.userId},
        );
      } else {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatAddFavorite,
          {'ChatUserId': widget.userId},
        );
      }
      setState(() => _isFavorite = !_isFavorite);
      await _analytics.logEvent(
          name: 'view_user_toggle_favorite',
          parameters: {'userId': widget.userId, 'now_favorite': _isFavorite});
    } catch (e) {
      showSnackbar(context, "Erro ao alterar favorito: $e");
      await _analytics.logEvent(
          name: 'view_user_toggle_favorite_error',
          parameters: {'error': e.toString()});
    }
  }

  Future<void> _initiateCall(String targetUserId) async {
    try {
      final callManager = Provider.of<CallManager>(context, listen: false);
      callManager.startCall(targetUserId);
      await _analytics.logEvent(
          name: 'view_user_initiate_call',
          parameters: {'targetUserId': targetUserId});
    } catch (e) {
      showSnackbar(context, "Erro ao iniciar chamada: $e");
      await _analytics.logEvent(
          name: 'view_user_initiate_call_error',
          parameters: {'error': e.toString()});
    }
  }

  Widget _buildUserImage() {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: config.secondaryColor, width: 2),
        image: _userImageUrl != null
            ? DecorationImage(
                image: InterceptedImageProvider(
                    originalProvider: NetworkImage(_userImageUrl!),
                    hideImages: config.hideImages),
                fit: BoxFit.cover,
              )
            : const DecorationImage(
                image: AssetImage('assets/images/user_anonymous.png'),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    return Scaffold(
      backgroundColor: config.primaryColor,
      appBar: AppBar(
        backgroundColor: config.primaryColor,
        iconTheme: IconThemeData(color: config.iconColor),
        title: Text('Perfil do Usuário',
            style: TextStyle(color: config.textColor)),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border,
                color: config.iconColor),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: config.iconColor),
            onPressed: () => _initiateCall(widget.userId),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: config.iconColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildUserImage(),
                      const SizedBox(height: 20),
                      Text(
                        _userName ?? 'Nome não disponível',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: config.textColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _userEmail ?? 'E-mail não disponível',
                        style: TextStyle(
                            fontSize: 16,
                            color: config.textColor.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 10),
                      if (_latitude != null && _longitude != null) ...[
                        Text(
                          'Distância: ${DistanceUtils.calculateDistance(_myLatitude!, _myLongitude!, _latitude!, _longitude!).toStringAsFixed(2)} km',
                          style: TextStyle(color: config.textColor),
                        ),
                      ] else ...[
                        Text('Distância indisponível',
                            style: TextStyle(color: config.textColor)),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOnline
                              ? config.customGreen
                              : config.customOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.secondaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _userName != null && _userImageUrl != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PrivateChatPage(
                                      userId: widget.userId,
                                      userName: _userName!,
                                      userImage: _userImageUrl!,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text('Iniciar Chat Privado',
                            style: TextStyle(color: config.textColor)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}