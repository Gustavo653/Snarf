import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:intl/intl.dart';

class PublicChatPage extends StatefulWidget {
  const PublicChatPage({super.key});

  @override
  _PublicChatPageState createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late HubConnection _chatHubConnection;
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  String? _userName;

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
    _getUserName();
  }

  Future<void> _getUserName() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      final userName = getUserNameFromToken(token);
      setState(() {
        _userName = userName;
      });
    }
  }

  String? getUserNameFromToken(String token) {
    Map<String, dynamic> payload = Jwt.parseJwt(token);
    return payload['name'];
  }

  Future<String> getAccessToken() async {
    return await _storage.read(key: 'token') ?? '';
  }

  Future<void> _setupSignalRConnection() async {
    _chatHubConnection = HubConnectionBuilder()
        .withUrl('${ApiConstants.baseUrl.replaceAll('/api', '')}/PublicChatHub',
        options: HttpConnectionOptions(
            accessTokenFactory: () async => await getAccessToken()))
        .withAutomaticReconnect()
        .build();

    _chatHubConnection.on("ReceiveMessage", (args) {
      final user = args?[0] as String;
      final message = args?[1] as String;
      setState(() {
        _messages.add({
          'senderName': user,
          'message': message,
          'isMine': user == _userName,
          'createdAt': DateTime.now(),
        });
      });
      _scrollToBottom();
    });

    try {
      await _chatHubConnection.start();
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao conectar ao chat público: $err")),
      );
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      await _chatHubConnection.invoke("SendMessage", args: [message]);
      setState(() {
        _messages.add({
          'senderName': 'Eu',
          'message': message,
          'isMine': true,
          'createdAt': DateTime.now(),
        });
        _messageController.clear();
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return DateFormat.Hm().format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  @override
  void dispose() {
    _chatHubConnection.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    final myMessageColor = isDarkMode ? Colors.blue[400] : Colors.blue[300];
    final otherMessageColor = isDarkMode ? Colors.grey[700] : Colors.grey[500];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Público'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => _toggleTheme(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message['isMine'] as bool;
                final time = _formatMessageTime(message['createdAt']);
                final messageColor =
                isMine ? myMessageColor : otherMessageColor;

                return Align(
                  alignment:
                  isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                        // Exibir o nome do usuário, mas não se for a própria mensagem
                        if (!isMine)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              message['senderName'], // Nome do usuário
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