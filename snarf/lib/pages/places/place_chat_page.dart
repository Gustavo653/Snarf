import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class PlaceChatPage extends StatefulWidget {
  final String placeId;

  const PlaceChatPage({super.key, required this.placeId});

  @override
  State<PlaceChatPage> createState() => _PlaceChatPageState();
}

class _PlaceChatPageState extends State<PlaceChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    _userId = await ApiService.getUserIdFromToken();
    SignalRManager()
        .listenToEvent('ReceiveMessage', _onReceivePlaceChatMessage);
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PlaceChatGetPreviousMessages,
      {"PlaceId": widget.placeId},
    );
    setState(() => _isLoading = false);
  }

  void _onReceivePlaceChatMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    try {
      final Map<String, dynamic> msg = jsonDecode(args[0] as String);
      final String eventType = msg["Type"];
      if (eventType == "PlaceChatReceiveMessage") {
        final data = msg["Data"];
        setState(() {
          _messages.add({
            'id': data['Id'],
            'createdAt': DateTime.parse(data['CreatedAt']).toLocal(),
            'userId': data['UserId'],
            'userName': data['UserName'],
            'userImage': data['UserImage'],
            'message': data['Message'],
            'isImage': data['Message'].toString().startsWith('https://')
          });
        });
        _scrollToBottom();
      } else if (eventType == "PlaceChatReceiveMessageDeleted") {
        final data = msg["Data"];
        final messageId = data['MessageId'];
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          setState(() {
            _messages[index]['message'] = 'Mensagem excluída';
          });
        }
      }
    } catch (e) {
      log("Erro ao processar mensagem: $e");
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
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PlaceChatSendMessage,
      {"PlaceId": widget.placeId, "Message": text},
    );
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _deleteMessage(String messageId) async {
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PlaceChatDeleteMessage,
      {"PlaceId": widget.placeId, "MessageId": messageId},
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    final bool isMine = (msg['userId'] == _userId);
    final String text = msg['message'] ?? '';
    final bool isDeleted = (text == 'Mensagem excluída');
    if (isMine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: config.secondaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(color: config.textColor),
              ),
            ),
          ),
          if (!isDeleted)
            IconButton(
              icon: Icon(Icons.delete, size: 18, color: config.iconColor),
              onPressed: () => _deleteMessage(msg['id']),
            )
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: (msg['userImage'] != null &&
                    msg['userImage'].toString().isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(msg['userImage']), fit: BoxFit.cover)
                : null,
          ),
          child:
              (msg['userImage'] == null || msg['userImage'].toString().isEmpty)
                  ? Icon(Icons.person, color: config.iconColor)
                  : null,
        ),
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.secondaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text(text, style: TextStyle(color: config.textColor)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: config.primaryColor,
        iconTheme: IconThemeData(color: config.iconColor),
        title: Text('Chat do Lugar', style: TextStyle(color: config.textColor)),
      ),
      backgroundColor: config.primaryColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: config.iconColor))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMessageItem(_messages[i]),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: config.textColor),
                          decoration: InputDecoration(
                            hintText: "Digite sua mensagem",
                            hintStyle: TextStyle(
                                color: config.textColor.withOpacity(0.6)),
                            filled: true,
                            fillColor: config.secondaryColor.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  BorderSide(color: config.secondaryColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide:
                                  BorderSide(color: config.secondaryColor),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                          icon: Icon(Icons.send, color: config.iconColor),
                          onPressed: _sendMessage),
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
