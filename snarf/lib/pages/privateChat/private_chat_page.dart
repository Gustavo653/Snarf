import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class PrivateChatPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userImage;

  const PrivateChatPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userImage,
  });

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
        onMethods: [
          'ReceivePreviousMessages',
          'ReceivePrivateMessage',
          'MessageDeleted'
        ],
        eventHandlers: {
          'ReceivePreviousMessages': _handleReceivedMessages,
          'ReceivePrivateMessage': _handleNewPrivateMessage,
          'MessageDeleted': _handleMessageDeleted,
        },
      );
      log('Conexão estabelecida com sucesso');
      await _signalRService
          .invokeMethod("GetPreviousMessages", [widget.userId]);
      await _signalRService.invokeMethod('MarkMessagesAsRead', [widget.userId]);
    } catch (err) {
      log("Erro ao conectar: $err");
      showSnackbar(context, "Erro ao conectar ao chat: $err");
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      await _sendImage(base64Image, image.name);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      await _sendImage(base64Image, image.name);
    }
  }

  Future<void> _sendImage(String base64Image, String fileName) async {
    try {
      log("Enviando imagem: $fileName");
      await _signalRService.invokeMethod(
        "SendImage",
        [widget.userId, base64Image, fileName],
      );
    } catch (e) {
      log("Erro ao enviar imagem: $e");
      showSnackbar(context, "Erro ao enviar imagem: $e");
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
            "id": msg['Id'],
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
    final message = args?[3] as String;
    log("Nova mensagem recebida: $message");

    setState(() {
      _messages.add({
        "id": args?[0],
        "createdAt": DateTime.now(),
        "message": message,
        "isMine": args?[1] != widget.userId,
      });
    });

    _scrollToBottom();
  }

  void _handleMessageDeleted(List<Object?>? args) {
    final String messageId = args?[0] as String;
    setState(() {
      final messageIndex =
          _messages.indexWhere((msg) => msg['id'] == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex]['message'] = "Mensagem excluída";
      }
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      log('Solicitando exclusão da mensagem $messageId');
      await _signalRService.invokeMethod("DeleteMessage", [messageId]);
    } catch (err) {
      log("Erro ao excluir mensagem: $err");
      showSnackbar(context, "Erro ao excluir mensagem: $err");
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;

    if (message.isNotEmpty) {
      try {
        log('Enviando mensagem: $message');
        await _signalRService
            .invokeMethod("SendPrivateMessage", [widget.userId, message]);
        _messageController.clear();
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

  void _showImageDialog(String imageContent) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              imageContent,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text("Erro ao carregar imagem");
              },
            ),
          ),
        );
      },
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
        title: Text(widget.userName),
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
                final String content = message['message'];

                final isImage = content.startsWith("http") ||
                    content.startsWith("data:image");

                return Align(
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: isMine
                        ? () async {
                            if (message['message'] != 'Mensagem excluída') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("Excluir Mensagem"),
                                    content: const Text(
                                        "Deseja realmente excluir esta mensagem?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancelar"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Excluir"),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirm == true) {
                                await _deleteMessage(message['id']);
                              }
                            }
                          }
                        : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
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
                          GestureDetector(
                            onTap: isImage
                                ? () {
                                    _showImageDialog(content);
                                  }
                                : null,
                            child: isImage
                                ? Image.network(
                                    content,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Text(
                                          "Erro ao carregar imagem");
                                    },
                                  )
                                : Text(
                                    content,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _takePhoto,
                ),
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Digite sua mensagem...",
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
