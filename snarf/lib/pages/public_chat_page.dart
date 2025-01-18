import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class PublicChatPage extends StatefulWidget {
  const PublicChatPage({super.key});

  @override
  _PublicChatPageState createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final SignalRService _signalRService = SignalRService();
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  String? _userId;
  bool _isLoading = true;

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
    _getUserId();
  }

  Future<void> _getUserId() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      final userId = getUserIdFromToken(token);
      setState(() {
        _userId = userId;
      });
    }
  }

  String? getUserIdFromToken(String token) {
    Map<String, dynamic> payload = Jwt.parseJwt(token);
    return payload['nameid'];
  }

  Future<void> _setupSignalRConnection() async {
    log("Setting up SignalR connection...", name: "PublicChatPage");

    try {
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PublicChatHub',
        onMethods: ['ReceiveMessage'],
        eventHandlers: {
          'ReceiveMessage': (args) {
            final date = DateTime.parse(args?[0] as String);
            final userId = args?[1] as String;
            final userName = args?[2] as String;
            final message = args?[3] as String;
            setState(() {
              _messages.add({
                'senderName': userName,
                'message': message,
                'isMine': userId == _userId,
                'createdAt': date,
              });

              log(_messages.toString(), name: "PublicChatPage");
            });
            if (!_isLoading) {
              _scrollToBottom();
            }
          },
        },
      );
      log("SignalR connection established.", name: "PublicChatPage");
      await _signalRService.invokeMethod("GetPreviousMessages", []);
    } catch (e) {
      log("Error setting up SignalR connection: $e",
          name: "PublicChatPage", level: 1000);
      showSnackbar(context, "Erro ao conectar com o servidor.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      log("Sending message: $message", name: "PublicChatPage");

      try {
        await _signalRService.invokeMethod("SendMessage", [message]);
        setState(() {
          _messageController.clear();
        });
        _scrollToBottom();
      } catch (e) {
        log("Error sending message: $e", name: "PublicChatPage", level: 1000);
        showSnackbar(context, "Erro ao enviar mensagem.");
      }
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

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
    final otherMessageColor = isDarkMode ? Colors.grey[700] : Colors.grey[500];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Público'),
        actions: [
          ThemeToggle(),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isMine = message['isMine'] as bool;
                  final time =
                      DateJSONUtils.formatMessageTime(message['createdAt']);
                  final messageColor =
                      isMine ? myMessageColor : otherMessageColor;

                  return Align(
                    alignment:
                        isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMine)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                message['senderName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 18),
                            child: Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                message['message'],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              time,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Digite uma mensagem",
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          ),
        ],
      ),
    );
  }
}
