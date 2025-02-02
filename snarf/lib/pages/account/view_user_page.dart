import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _initLocation() async {
    Location location = Location();
    var position = await location.getLocation();
    _myLatitude = position.latitude;
    _myLongitude = position.longitude;
  }

  Future<void> _checkIfFavorite() async {
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetFavorites,
      {},
    );
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);
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
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } catch (e) {
      showSnackbar(context, "Erro ao alterar favorito: $e");
    }
  }

  bool get _isOnline {
    if (_lastActivity == null) return false;
    final difference = DateTime.now().difference(_lastActivity!);
    return difference.inMinutes < 1;
  }

  void _handleSignalRMessage(List<Object?>? args) {
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
        }
      } else if (eventType ==
          SignalREventType.UserDisconnected.toString().split('.').last) {
        final mapData = data['Data'] as Map<String, dynamic>;
        final String userId = mapData['userId'];
        if (userId == widget.userId) {
          setState(() {
            _lastActivity = DateTime.now().add(Duration(days: -1));
          });
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
              break;
            }
          }
        }
      }
    } catch (e) {
      showSnackbar(context, "Erro ao processar favoritos: $e");
    }
  }

  Future<void> _initiateCall(String targetUserId) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.VideoCallInitiate,
        {
          "TargetUserId": targetUserId,
        },
      );
    } catch (e) {
      showSnackbar(context, "Erro ao iniciar chamada: $e");
    }
  }

  Future<void> _loadUserInfo() async {
    await _initLocation();
    final userInfo = await ApiService.getUserInfoById(widget.userId);

    SignalRManager().listenToEvent("ReceiveMessage", _handleSignalRMessage);

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
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');
    }
  }

  Widget _buildUserImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
        image: _userImageUrl != null
            ? DecorationImage(
                image: NetworkImage(_userImageUrl!),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Usuário'),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _isOnline
                ? () => _initiateCall(widget.userId)
                : () => showSnackbar(
                      context,
                      "Usuário está offline",
                    ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _userEmail ?? 'E-mail não disponível',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_latitude != null && _longitude != null) ...[
                        Text('Distância: ${DistanceUtils.calculateDistance(
                          _myLatitude!,
                          _myLongitude!,
                          _latitude!,
                          _longitude!,
                        ).toStringAsFixed(2)} km')
                      ] else ...[
                        const Text('Distância indisponível'),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOnline ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
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
                        child: const Text(
                          'Iniciar Chat Privado',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
