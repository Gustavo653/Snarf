import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:location/location.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ChatMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final Color? messageColor;
  final double? distance;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isMine,
    required this.messageColor,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMine && distance != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${distance!.toStringAsFixed(2)} km',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine)
              CircleAvatar(
                backgroundImage: NetworkImage(message['senderImage']),
                radius: 20,
              ),
            if (!isMine) const SizedBox(width: 8),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: messageColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft:
                        isMine ? const Radius.circular(12) : Radius.zero,
                    bottomRight:
                        isMine ? Radius.zero : const Radius.circular(12),
                  ),
                ),
                child: Text(
                  message['message'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getUserIdFromToken() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      return payload['nameid'];
    }
    return null;
  }
}

class PublicChatPage extends StatefulWidget {
  const PublicChatPage({super.key});

  @override
  _PublicChatPageState createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SignalRService _signalRService = SignalRService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _messages = [];

  String? _userId;
  bool _isLoading = true;

  double? _myLatitude;
  double? _myLongitude;
  bool _sortByDate = true;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _setupSignalRConnection();
  }

  Future<void> _loadUserId() async {
    final userId = await _authService.getUserIdFromToken();
    setState(() {
      _userId = userId;
    });
  }

  Future<void> _initLocation() async {
    Location location = Location();
    var position = await location.getLocation();
    _myLatitude = position.latitude;
    _myLongitude = position.longitude;
  }

  Future<void> _setupSignalRConnection() async {
    log("Setting up SignalR connection...", name: "PublicChatPage");

    try {
      await _initLocation();
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PublicChatHub',
        onMethods: ['ReceiveMessage'],
        eventHandlers: {
          'ReceiveMessage': (args) {
            final date = DateTime.parse(args?[0] as String)
                .add(const Duration(hours: -3));
            final userId = args?[1] as String;
            final userName = args?[2] as String;
            final messageText = args?[3] as String;
            final senderImage = args?[4] as String;
            final senderLat = args?[5] as double?;
            final senderLng = args?[6] as double?;

            double? distance;
            if (senderLat != null &&
                senderLng != null &&
                _myLatitude != null &&
                _myLongitude != null) {
              distance = _calculateDistance(
                _myLatitude!,
                _myLongitude!,
                senderLat,
                senderLng,
              );
            }

            setState(() {
              _messages.add({
                'createdAt': date,
                'senderName': userName,
                'message': messageText,
                'senderImage': senderImage,
                'isMine': userId == _userId,
                'distance': distance,
              });
            });

            if (!_isLoading) _scrollToBottom();
          },
        },
      );

      log("SignalR connection established.", name: "PublicChatPage");

      await _signalRService.invokeMethod("GetPreviousMessages", []);
    } catch (e) {
      log("Error setting up SignalR connection: $e",
          name: "PublicChatPage", level: 1000);
      if (mounted) {
        showSnackbar(context, "Erro ao conectar com o servidor.");
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      try {
        await _signalRService.invokeMethod("SendMessage", [message]);
        setState(() {
          _messageController.clear();
        });
        _scrollToBottom();
      } catch (e) {
        log("Error sending message: $e", name: "PublicChatPage", level: 1000);
        if (mounted) {
          showSnackbar(context, "Erro ao enviar mensagem.");
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    double distance = R * c;
    return distance;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  @override
  void dispose() {
    _signalRService.stopConnection();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final myMessageColor = isDarkMode ? Colors.blue[400] : Colors.blue[300];
    final otherMessageColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final sortedMessages = List<Map<String, dynamic>>.from(_messages);

    if (_sortByDate) {
      sortedMessages.sort((a, b) {
        final dateA = a['createdAt'] as DateTime;
        final dateB = b['createdAt'] as DateTime;
        return dateA.compareTo(dateB);
      });
    } else {
      sortedMessages.sort((a, b) {
        final distA = a['distance'] as double? ?? double.infinity;
        final distB = b['distance'] as double? ?? double.infinity;
        return distB.compareTo(distA);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Público'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortByDate = (value == 'date');
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date',
                child: Text('Ordenar por data'),
              ),
              const PopupMenuItem(
                value: 'distance',
                child: Text('Ordenar por distância'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: sortedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = sortedMessages[index];
                      final isMine = msg['isMine'] as bool;
                      final createdAt = msg['createdAt'] as DateTime;
                      final distance = msg['distance'] as double?;
                      final time = DateJSONUtils.formatMessageTime(createdAt);
                      final color = isMine ? myMessageColor : otherMessageColor;

                      return Column(
                        crossAxisAlignment: isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              time,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ChatMessageWidget(
                              message: msg,
                              isMine: isMine,
                              messageColor: color,
                              distance: distance,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 25),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Digite uma mensagem",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            color: Colors.blue,
            iconSize: 30,
          ),
        ],
      ),
    );
  }
}
