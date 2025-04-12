import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/view_user_page.dart'; // <--- import adicional
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class PartyChatPage extends StatefulWidget {
  final String partyId;
  final String userId;

  const PartyChatPage({
    Key? key,
    required this.partyId,
    required this.userId,
  }) : super(key: key);

  @override
  _PartyChatPageState createState() => _PartyChatPageState();
}

class _PartyChatPageState extends State<PartyChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
  }

  Future<void> _setupSignalRConnection() async {
    SignalRManager()
        .listenToEvent("ReceiveMessage", _onReceivePartyChatMessage);

    await SignalRManager().sendSignalRMessage(
      SignalREventType.PartyChatGetPreviousMessages,
      {"partyId": widget.partyId},
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _onReceivePartyChatMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);
      final String eventType = message["Type"];

      if (eventType == "PartyChatReceiveMessage") {
        final data = message["Data"];
        setState(() {
          _messages.add({
            'id': data['Id'],
            'createdAt': DateTime.parse(data['CreatedAt']).toLocal(),
            'userId': data['UserId'],
            'userName': data['UserName'],
            'userImage': data['UserImage'],
            'message': data['Message'],
            'isImage': data['Message'].toString().startsWith('https://'),
          });
        });
        _scrollToBottom();
      } else if (eventType == "PartyChatReceiveMessageDeleted") {
        final data = message["Data"];
        final messageId = data['MessageId'];
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['message'] = "Mensagem excluída";
          }
        });
      }
    } catch (e) {
      log("Erro ao processar mensagem do bate-papo da festa: $e");
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

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    await SignalRManager().sendSignalRMessage(
      SignalREventType.PartyChatSendMessage,
      {
        "partyId": widget.partyId,
        "Message": messageText,
      },
    );

    setState(() {
      _messageController.clear();
    });
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      await SignalRManager().sendSignalRMessage(
        SignalREventType.PartyChatSendImage,
        {
          "partyId": widget.partyId,
          "Image": base64Image,
          "FileName": pickedFile.name,
        },
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PartyChatDeleteMessage,
      {
        "partyId": widget.partyId,
        "MessageId": messageId,
      },
    );
  }

  Widget _buildMessageWidget(Map<String, dynamic> msg) {
    final bool isMine = msg['userId'] == widget.userId;
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    final String messageText = msg['message'] ?? '';
    final bool isImage = msg['isImage'] == true;

    // Se for minha mensagem, alinhe à direita
    if (isMine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: configProvider.secondaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: isImage
                  ? Image.network(
                messageText,
                errorBuilder: (_, __, ___) {
                  return Text(
                    'Erro ao carregar imagem',
                    style: TextStyle(color: configProvider.textColor),
                  );
                },
              )
                  : Text(
                messageText,
                style: TextStyle(
                  color: configProvider.textColor,
                ),
              ),
            ),
          ),
          if (messageText != "Mensagem excluída")
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 18,
                color: configProvider.iconColor,
              ),
              onPressed: () => _deleteMessage(msg['id']),
            ),
        ],
      );
    }

    // Se não for minha, alinhe à esquerda e inclua o clique para abrir a tela de viewuserpage
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Envolve o avatar em um GestureDetector para abrir o ViewUserPage
        GestureDetector(
          onTap: () {
            if (msg['userId'] == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewUserPage(
                  userId: msg['userId'],
                ),
              ),
            );
          },
          child: Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.only(left: 8, right: 8, top: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              image: (msg['userImage'] != null &&
                  msg['userImage'].toString().isNotEmpty)
                  ? DecorationImage(
                image: NetworkImage(msg['userImage']),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: (msg['userImage'] == null ||
                msg['userImage'].toString().isEmpty)
                ? Center(
              child: Icon(
                Icons.person,
                color: configProvider.iconColor,
              ),
            )
                : null,
          ),
        ),
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: configProvider.secondaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: isImage
                ? Image.network(
              messageText,
              errorBuilder: (_, __, ___) {
                return Text(
                  'Erro ao carregar imagem',
                  style: TextStyle(color: configProvider.textColor),
                );
              },
            )
                : Text(
              messageText,
              style: TextStyle(
                color: configProvider.textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
        title: Text(
          'Bate-papo da Festa',
          style: TextStyle(color: configProvider.textColor),
        ),
      ),
      backgroundColor: configProvider.primaryColor,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: configProvider.iconColor,
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageWidget(msg);
              },
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.photo, color: configProvider.iconColor),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: configProvider.textColor),
                    decoration: InputDecoration(
                      hintText: "Digite sua mensagem",
                      hintStyle: TextStyle(
                        color: configProvider.textColor.withOpacity(0.6),
                      ),
                      filled: true,
                      fillColor:
                      configProvider.secondaryColor.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: configProvider.secondaryColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: configProvider.secondaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: configProvider.iconColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}