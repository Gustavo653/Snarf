import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/distance_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class PublicChatPage extends StatefulWidget {
  final ScrollController scrollController;

  const PublicChatPage({super.key, required this.scrollController});

  @override
  _PublicChatPageState createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

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
    await _loadUserId();
    await _initLocation();
    SignalRManager().listenToEvent("ReceiveMessage", _onReceiveMessage);
    await SignalRManager()
        .sendSignalRMessage(SignalREventType.PublicChatGetPreviousMessages, {});
    setState(() => _isLoading = false);
  }

  void _onReceiveMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);
      final SignalREventType type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == message['Type'],
      );

      final dynamic data = message['Data'];

      switch (type) {
        case SignalREventType.PublicChatReceiveMessage:
          _handleReceiveMessage(data);
          break;
        case SignalREventType.PublicChatReceiveMessageDeleted:
          _handleMessageDeleted(data);
          break;
        default:
          log("Evento não reconhecido: ${message['Type']}");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  void _handleReceiveMessage(Map<String, dynamic> data) {
    setState(() {
      _messages.add({
        'id': data['Id'],
        'createdAt': DateTime.parse(data['CreatedAt']).toLocal(),
        'userName': data['UserName'],
        'message': data['Message'],
        'userImage': data['UserImage'],
        'userId': data['UserId'],
        'isMine': data['UserId'] == _userId,
        'latitude': data['Latitude'],
        'longitude': data['Longitude'],
        'distance': DistanceUtils.calculateDistance(
          _myLatitude!,
          _myLongitude!,
          data['Latitude'],
          data['Longitude'],
        ),
      });
    });
    _scrollToBottom();
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == data['MessageId']);
      if (index != -1) {
        _messages[index]['message'] = data['Message'];
      }
    });
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PublicChatSendMessage,
        {"Message": messageText},
      );
      setState(() => _messageController.clear());
      _scrollToBottom();
    }
  }

  void _deleteMessage(String messageId) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PublicChatDeleteMessage,
        {"MessageId": messageId},
      );
    } catch (e) {
      showSnackbar(context, "Erro ao excluir a mensagem: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
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
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
        title: Text(
          'Feed',
          style: TextStyle(color: configProvider.textColor),
        ),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            color: configProvider.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: configProvider.secondaryColor,
                width: 2,
              ),
            ),
            icon: Icon(Icons.sort, color: configProvider.iconColor),
            onSelected: (value) {
              setState(() {
                _sortByDate = (value == 'date');
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Text(
                  'Ordenar por data',
                  style: TextStyle(color: configProvider.textColor),
                ),
              ),
              PopupMenuItem(
                value: 'distance',
                child: Text(
                  'Ordenar por distância',
                  style: TextStyle(color: configProvider.textColor),
                ),
              ),
            ],
          ),
        ],
      ),
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
                    controller: widget.scrollController,
                    itemCount: sortedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = sortedMessages[index];
                      final isMine = msg['isMine'] as bool;
                      final createdAt = msg['createdAt'] as DateTime;
                      final distance = msg['distance'] ?? 0.0;

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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Data
                                Text(
                                  DateJSONUtils.formatRelativeTime(
                                    createdAt.toString(),
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: configProvider.textColor,
                                  ),
                                ),
                                Text(
                                  !isMine
                                      ? '${distance?.toStringAsFixed(2)} km'
                                      : '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: configProvider.textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: _buildMessageWidget(
                              context,
                              message: msg,
                              isMine: isMine,
                              messageColor: configProvider.secondaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _buildMessageInput(context),
              ],
            ),
    );
  }

  Widget _buildMessageWidget(
    BuildContext context, {
    required Map<String, dynamic> message,
    required bool isMine,
    required Color messageColor,
  }) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    final msgText = message['message'] as String? ?? '';
    final msgId = message['id'] as String?;
    final userId = message['userId'] as String?;
    final userLatitude = message['latitude'] as double?;
    final userLongitude = message['longitude'] as double?;
    final senderImage = message['userImage'] as String? ?? '';

    if (isMine) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: messageColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.zero,
                ),
              ),
              child: Text(
                msgText,
                style: TextStyle(
                  fontSize: 14,
                  color: configProvider.textColor,
                ),
              ),
            ),
          ),
          if (msgText != "Mensagem excluída")
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 18,
                color: configProvider.iconColor,
              ),
              onPressed: () {
                if (msgId != null) {
                  _deleteMessage(msgId);
                }
              },
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              GestureDetector(
                onTap: () {
                  if (userId == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewUserPage(userId: userId),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    image: DecorationImage(
                      image: InterceptedImageProvider(
                        originalProvider: NetworkImage(senderImage),
                        hideImages: configProvider.hideImages,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: messageColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.zero,
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    msgText,
                    style: TextStyle(
                      fontSize: 14,
                      color: configProvider.textColor,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (userLatitude != null && userLongitude != null)
              IconButton(
                icon: Icon(Icons.my_location, color: configProvider.iconColor),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => HomePage(
                        initialLatitude: userLatitude,
                        initialLongitude: userLongitude,
                      ),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ChatMessageOptions(
              senderId: userId!,
              messageId: msgId!,
              mainContext: context,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Container(
      color: configProvider.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 25),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: configProvider.textColor),
              decoration: InputDecoration(
                hintText: "Digite uma atualização",
                hintStyle:
                    TextStyle(color: configProvider.textColor.withOpacity(0.6)),
                fillColor: configProvider.secondaryColor.withOpacity(0.1),
                filled: true,
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
            iconSize: 30,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class ChatMessageOptions extends StatelessWidget {
  final String senderId;
  final String messageId;
  final BuildContext mainContext;

  const ChatMessageOptions({
    required this.senderId,
    required this.messageId,
    required this.mainContext,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    return IconButton(
      icon: Icon(Icons.more_horiz, color: configProvider.iconColor),
      onPressed: () => _showBlockReportDialog(context),
    );
  }

  void _showBlockReportDialog(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: configProvider.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: configProvider.secondaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 5,
                        backgroundColor: configProvider.secondaryColor,
                        iconColor: configProvider.iconColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.block),
                      label: Text(
                        "Bloquear Usuário",
                        style: TextStyle(
                          color: configProvider.textColor,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _blockUser(mainContext);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 5,
                        backgroundColor: configProvider.secondaryColor,
                        iconColor: configProvider.iconColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.flag),
                      label: Text(
                        "Denunciar Publicação",
                        style: TextStyle(
                          color: configProvider.textColor,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _reportMessage(mainContext, messageId);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                child: Text(
                  "Cancelar",
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _blockUser(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final configProvider = Provider.of<ConfigProvider>(context);
        return AlertDialog(
          backgroundColor: configProvider.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: configProvider.secondaryColor,
              width: 2,
            ),
          ),
          title: Text(
            'Confirmar Bloqueio',
            style: TextStyle(color: configProvider.textColor),
          ),
          content: Text(
            'Tem certeza de que deseja bloquear este usuário?',
            style: TextStyle(color: configProvider.textColor),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Bloquear',
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final response = await ApiService.blockUser(senderId);
      if (response == null) {
        showSnackbar(
          context,
          'Usuário bloqueado com sucesso.',
          color: Colors.green,
        );
      } else {
        showSnackbar(context, 'Erro ao bloquear usuário: $response');
      }
    }
  }

  Future<void> _reportMessage(BuildContext context, String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final configProvider = Provider.of<ConfigProvider>(context);
        return AlertDialog(
          backgroundColor: configProvider.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: configProvider.secondaryColor,
              width: 2,
            ),
          ),
          title: Text(
            'Confirmar denúncia',
            style: TextStyle(color: configProvider.textColor),
          ),
          content: Text(
            'Tem certeza de que deseja denunciar esta mensagem?',
            style: TextStyle(color: configProvider.textColor),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Denunciar',
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final response = await ApiService.reportMessage(messageId);
      if (response == null) {
        showSnackbar(
          context,
          'Mensagem denunciada com sucesso.',
          color: Colors.green,
        );
      } else {
        showSnackbar(context, 'Erro ao denunciar mensagem: $response');
      }
    }
  }
}
