import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ChatMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final Color? messageColor;
  final double? distance;
  final Function(String) onDelete;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isMine,
    required this.messageColor,
    required this.distance,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final msgText = message['message'] as String;
    final msgId = message['id'] as String?;
    final senderId = message['senderId'] as String?;

    void _openViewUserPage() {
      if (senderId == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewUserPage(userId: senderId),
        ),
      );
    }

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
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine)
              GestureDetector(
                onTap: _openViewUserPage,
                child: CircleAvatar(
                  backgroundImage: NetworkImage(
                    message['senderImage'] ?? '',
                  ),
                  radius: 20,
                ),
              ),
            if (!isMine) const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: _openViewUserPage,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  child: Expanded(
                    child: Text(
                      msgText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
            if (isMine && msgText != "Mensagem excluída")
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  size: 18,
                ),
                onPressed: () {
                  if (msgId != null) {
                    onDelete(msgId);
                  }
                },
              ),
          ],
        ),
      ],
    );
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

  List<Map<String, dynamic>> _messages = [];

  String? _userId;
  bool _isLoading = true;

  double? _myLatitude;
  double? _myLongitude;
  bool _sortByDate = true;

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
  }

  Future<void> _loadUserId() async {
    final userId = await ApiService.getUserIdFromToken();
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
    await _loadUserId();
    try {
      await _initLocation();
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PublicChatHub',
        onMethods: ['ReceiveMessage', 'ReceiveMessageDeleted'],
        eventHandlers: {
          'ReceiveMessage': (args) {
            final messageId = args?[0] as String;
            final dateUtc = DateTime.parse(args?[1] as String);
            final dateLocal = dateUtc.toLocal();
            final userId = args?[2] as String;
            final userName = args?[3] as String;
            final messageText = args?[4] as String;
            final senderImage = args?[5] as String;
            final senderLat = args?[6] as double?;
            final senderLng = args?[7] as double?;

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
                'id': messageId,
                'createdAt': dateLocal,
                'senderName': userName,
                'message': messageText,
                'senderImage': senderImage,
                'senderId': userId,
                'isMine': userId == _userId,
                'distance': distance,
              });
            });

            if (!_isLoading) _scrollToBottom();
          },
          'ReceiveMessageDeleted': (args) {
            final deletedMessageId = args?[0] as String;
            final newText = args?[2] as String;

            setState(() {
              final index =
                  _messages.indexWhere((m) => m['id'] == deletedMessageId);
              if (index != -1) {
                _messages[index]['message'] = newText;
              }
            });
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

  void _deleteMessage(String messageId) async {
    try {
      await _signalRService.invokeMethod("DeleteMessage", [messageId]);
    } catch (e) {
      showSnackbar(context, "Erro ao excluir a mensagem: $e");
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
                      final senderName = msg['senderName'] as String;
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
                              '$time${!isMine ? ' • $senderName' : ''}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
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
                              onDelete: (messageId) {
                                _deleteMessage(messageId);
                              },
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
