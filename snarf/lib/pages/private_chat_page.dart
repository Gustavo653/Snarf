import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class PrivateChatPage extends StatefulWidget {
  final String userId;

  const PrivateChatPage({super.key, required this.userId});

  @override
  _PrivateChatPageState createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SignalRService _signalRService = SignalRService();
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      log('Iniciando a conexão com o chat...');
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PrivateChatHub',
        onMethods: ['ReceivePreviousMessages', 'ReceivePrivateMessage'],
        eventHandlers: {
          'ReceivePreviousMessages': _handleReceivedMessages,
          'ReceivePrivateMessage': _handleNewPrivateMessage,
        },
      );
      log('Conexão estabelecida com sucesso');
      await _signalRService.invokeMethod("GetPreviousMessages", [widget.userId]);
    } catch (err) {
      log("Erro ao conectar: $err");
      showSnackbar(context, "Erro ao conectar ao chat: $err");
    }
  }

  void _handleReceivedMessages(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      log("Nenhuma mensagem recebida");
      return;
    }

    final jsonString = args[0] as String;
    log("JSON recebido: $jsonString");

    try {
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
    } catch (err) {
      log("Erro ao processar mensagens: $err");
      showSnackbar(context, "Erro ao processar mensagens: $err");
    }
  }

  void _handleNewPrivateMessage(List<Object?>? args) {
    final message = args?[0] as String;
    log("Nova mensagem recebida: $message");

    if (message != null) {
      setState(() {
        _messages.add({
          "createdAt": DateTime.now(),
          "message": message,
          "isMine": false,
        });
      });

      _scrollToBottom();
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;

    if (message.isNotEmpty) {
      try {
        log('Enviando mensagem: $message');
        await _signalRService.invokeMethod("SendPrivateMessage", [widget.userId, message]);

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
        log("Erro ao enviar mensagem: $err");
        showSnackbar(context, "Erro ao enviar mensagem: $err");
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
        title: Text('Chat com ${widget.userId}'),
        actions: [
          ThemeToggle(),
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
                final time =
                DateJSONUtils.formatMessageTime(message['createdAt']);

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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
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