import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

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
  List<PrivateChatMessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);
    await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatGetPreviousMessages,
        {'ReceiverUserId': widget.userId});
    await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatMarkMessagesAsRead,
        {'SenderUserId': widget.userId});
  }

  void _handleSignalRMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);
      final typeString = message['Type'] as String;
      final dynamic data = message['Data'];

      final SignalREventType type = SignalREventType.values
          .firstWhere((e) => e.toString().split('.').last == typeString);

      switch (type) {
        case SignalREventType.PrivateChatReceivePreviousMessages:
          _handleReceivedMessages(data);
          break;
        case SignalREventType.PrivateChatReceiveMessage:
          _handleNewPrivateMessage(data);
          break;
        case SignalREventType.PrivateChatReceiveMessageDeleted:
          _handleMessageDeleted(data);
          break;
        // ...
        default:
          log("Evento desconhecido: $typeString");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes,
      {int quality = 70}) async {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage != null) {
      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: quality));
    }
    return imageBytes;
  }

  Future<void> _editAndSendImage(XFile image) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          File(image.path),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              final compressedBytes = await _compressImage(bytes);
              final base64Image = base64Encode(compressedBytes);
              await _sendImage(base64Image, image.name);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _editAndSendImage(image);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _editAndSendImage(image);
    }
  }

  Future<void> _sendImage(String base64Image, String fileName) async {
    try {
      await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatSendImage, {
        'ReceiverUserId': widget.userId,
        'Image': base64Image,
        'FileName': fileName
      });
    } catch (e) {
      showSnackbar(context, "Erro ao enviar imagem: $e");
    }
  }

  void _handleReceivedMessages(dynamic data) {
    if (data == null) return;
    try {
      final List<dynamic> rawList = data as List<dynamic>;
      final List<PrivateChatMessageModel> previousMessages =
          rawList.map((item) {
        final map = item as Map<String, dynamic>;
        return PrivateChatMessageModel.fromJson(map);
      }).toList();

      setState(() {
        _messages = previousMessages;
      });

      _scrollToBottom();
    } catch (err) {
      showSnackbar(context, "Erro ao processar mensagens: $err");
    }
  }

  void _handleNewPrivateMessage(dynamic data) {
    if (data == null) return;
    try {
      final map = data as Map<String, dynamic>;
      final newMessage = PrivateChatMessageModel.fromJson(map);

      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
    } catch (e) {
      showSnackbar(context, "Erro ao processar nova mensagem: $e");
    }
  }

  void _handleMessageDeleted(dynamic data) {
    if (data == null) return;
    try {
      final map = data as Map<String, dynamic>;
      final String messageId = map['MessageId'] as String;

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final old = _messages[idx];
          _messages[idx] = old.copyWith(message: "Mensagem excluída");
        }
      });
    } catch (e) {
      showSnackbar(context, "Erro ao processar exclusão: $e");
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await SignalRManager()
          .sendSignalRMessage(SignalREventType.PrivateChatDeleteMessage, {
        'MessageId': messageId,
      });
    } catch (err) {
      showSnackbar(context, "Erro ao excluir mensagem: $err");
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;

    if (message.isNotEmpty) {
      try {
        log('Enviando mensagem: $message');
        await SignalRManager()
            .sendSignalRMessage(SignalREventType.PrivateChatSendMessage, {
          'ReceiverUserId': widget.userId,
          'Message': message,
        });
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
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.userImage),
              radius: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.userName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                final isMine = message.senderId != widget.userId;
                final time = DateJSONUtils.formatMessageTime(message.createdAt);
                final String content = message.message;

                final isImage = content.startsWith("http") ||
                    content.startsWith("data:image");

                return Align(
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: isMine
                        ? () async {
                            if (message.message != 'Mensagem excluída') {
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
                                await _deleteMessage(message.id);
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

class PrivateChatMessageModel {
  final String id;
  final DateTime createdAt;
  final String senderId;
  final String message;

  PrivateChatMessageModel({
    required this.id,
    required this.createdAt,
    required this.senderId,
    required this.message,
  });

  factory PrivateChatMessageModel.fromJson(Map<String, dynamic> json) {
    return PrivateChatMessageModel(
      id: json['Id'] as String? ?? json['MessageId'] as String,
      // se vier "Id" ou "MessageId"
      createdAt: DateTime.parse(
              json['CreatedAt'] as String? ?? DateTime.now().toIso8601String())
          .toLocal(),
      senderId: json['SenderId'] as String? ?? json['UserId'] as String? ?? '',
      message: json['Message'] as String? ?? '',
    );
  }

  PrivateChatMessageModel copyWith({
    String? message,
  }) {
    return PrivateChatMessageModel(
      id: id,
      createdAt: createdAt,
      senderId: senderId,
      message: message ?? this.message,
    );
  }
}
