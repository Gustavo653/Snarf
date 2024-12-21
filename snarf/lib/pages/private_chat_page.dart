import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class PrivateChatPage extends StatefulWidget {
  final String userId;

  const PrivateChatPage({super.key, required this.userId});

  @override
  _PrivateChatPageState createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late HubConnection _chatHubConnection;
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
  }

  Future<String> getAccessToken() async {
    return await _storage.read(key: 'token') ?? '';
  }

  Future<void> _setupSignalRConnection() async {
    _chatHubConnection = HubConnectionBuilder()
        .withUrl(
            '${ApiConstants.baseUrl.replaceAll('/api', '')}/PrivateChatHub',
            options: HttpConnectionOptions(
                accessTokenFactory: () async => await getAccessToken()))
        .withAutomaticReconnect()
        .build();

    _chatHubConnection.on("ReceivePreviousMessages", (args) {
      if (args == null || args.isEmpty) return;

      final jsonString = args[0] as String;
      log("JSON recebido: $jsonString");

      final List<dynamic> previousMessages = json.decode(jsonString);

      setState(() {
        _messages = previousMessages.map((msg) {
          return {
            "createdAt": DateTime.parse(msg['CreatedAt']),
            "message": msg['Message'],
            "isMine": msg['SenderId'] != widget.userId,
          };
        }).toList();
      });

      _scrollToBottom();
    });

    _chatHubConnection.on("ReceivePrivateMessage", (args) {
      final message = args?[0] as String;
      log("Mensagem recebida: $message");
      setState(() {
        _messages.add({
          "createdAt": DateTime.now(),
          "message": message,
          "isMine": false,
        });
      });

      _scrollToBottom();
    });


    try {
      await _chatHubConnection.start();
      log("Conexão com o SignalR estabelecida.");
      await _loadPreviousMessages(widget.userId);
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao conectar ao chat privado: $err")),
      );
    }
  }

  Future<void> _loadPreviousMessages(String receiverUserId) async {
    try {
      await _chatHubConnection
          .invoke("GetPreviousMessages", args: [receiverUserId]);
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erro ao carregar mensagens anteriores: $err")));
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;

    if (message.isNotEmpty) {
      try {
        await _chatHubConnection.invoke(
          "SendPrivateMessage",
          args: [widget.userId, message],
        );

        setState(() {
          _messages.add({
            "createdAt": DateTime.now(),
            "message": message,
            "isMine": true,
          });
          _messageController.clear();
        });

        _scrollToBottom();
      } catch (err) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao enviar mensagem: $err")));
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final myMessageColor = isDarkMode ? Colors.blue[400] : Colors.blue[300];
    final otherMessageColor = isDarkMode ? Colors.grey[700] : Colors.grey[500];

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat com ${widget.userId}'),
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

                return Align(
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine ? myMessageColor : otherMessageColor,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 18,
                          ),
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
