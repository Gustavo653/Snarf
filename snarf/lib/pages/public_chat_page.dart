import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ChatMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final Color? messageColor;
  final String time;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isMine,
    required this.messageColor,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: messageColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMine ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMine ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(message['senderImage']),
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message['senderName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 18),
              child: Align(
                alignment:
                    isMine ? Alignment.centerRight : Alignment.centerLeft,
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
  }
}

class AuthService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

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

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await _authService.getUserIdFromToken();
    setState(() {
      _userId = userId;
    });
  }

  Future<void> _setupSignalRConnection() async {
    log("Setting up SignalR connection...", name: "PublicChatPage");

    try {
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PublicChatHub',
        onMethods: ['ReceiveMessage'],
        eventHandlers: {
          'ReceiveMessage': (args) {
            final date = DateTime.parse(args?[0] as String)
                .add(const Duration(hours: -3));
            final userId = args?[1] as String;
            final userName = args?[2] as String;
            final message = args?[3] as String;
            final senderImage = args?[4] as String;
            setState(() {
              _messages.add({
                'senderName': userName,
                'message': message,
                'senderImage': senderImage,
                'isMine': userId == _userId,
                'createdAt': date,
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message['isMine'] as bool;
                      final time = DateJSONUtils.formatMessageTime(
                        message['createdAt'],
                      );
                      final messageColor =
                          isMine ? myMessageColor : otherMessageColor;

                      return ChatMessageWidget(
                        message: message,
                        isMine: isMine,
                        messageColor: messageColor,
                        time: time,
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
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
