import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/providers/call_manager.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/services/signalr_manager.dart';

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:image/image.dart' as img;
import 'package:snarf/utils/signalr_event_type.dart';
import 'package:video_compress/video_compress.dart';

import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:snarf/services/api_service.dart';

/// MODELO DE MENSAGEM
class PrivateChatMessageModel {
  final String id;
  final DateTime createdAt;
  final String senderId;
  final String message;

  final Map<String, String> reactions;

  final String? replyToMessageId;

  PrivateChatMessageModel({
    required this.id,
    required this.createdAt,
    required this.senderId,
    required this.message,
    this.reactions = const {},
    this.replyToMessageId,
  });

  factory PrivateChatMessageModel.fromJson(Map<String, dynamic> json) {
    return PrivateChatMessageModel(
      id: json['Id'] as String? ?? json['MessageId'] as String,
      createdAt: DateTime.parse(
        json['CreatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      senderId: json['SenderId'] as String? ?? json['UserId'] as String? ?? '',
      message: json['Message'] as String? ?? '',
      reactions: (json['Reactions'] is Map)
          ? (json['Reactions'] as Map<dynamic, dynamic>).map<String, String>(
              (key, val) => MapEntry(key as String, val as String))
          : {},
      replyToMessageId: json['ReplyToMessageId'] as String? ??
          json['OriginalMessageId'] as String?,
    );
  }

  PrivateChatMessageModel copyWith({
    String? message,
    Map<String, String>? reactions,
    String? replyToMessageId,
  }) {
    return PrivateChatMessageModel(
      id: id,
      createdAt: createdAt,
      senderId: senderId,
      message: message ?? this.message,
      reactions: reactions ?? this.reactions,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    );
  }
}

class PrivateChatPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userImage;

  const PrivateChatPage({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userImage,
  }) : super(key: key);

  @override
  _PrivateChatPageState createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<PrivateChatMessageModel> _messages = [];

  final _record = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  bool _isFavorite = false;
  bool _isSendingMedia = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);

    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetPreviousMessages,
      {'ReceiverUserId': widget.userId},
    );

    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatMarkMessagesAsRead,
      {'SenderUserId': widget.userId},
    );

    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetFavorites,
      {},
    );

    await _initAudioRecorder();
  }

  void _handleSignalRMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);

      if (!message.containsKey('Type') || !message.containsKey('Data')) {
        return;
      }

      final typeString = message['Type'] as String;
      final dynamic data = message['Data'];

      SignalREventType type;
      type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == typeString,
      );

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

        case SignalREventType.PrivateChatReceiveFavorites:
          _handleFavoritesData(data);
          break;

        case SignalREventType.PrivateChatReceiveReaction:
          _handleReaction(data);
          break;

        case SignalREventType.PrivateChatReceiveReply:
          _handleReply(data);
          break;

        default:
          log("Evento não tratado: $typeString");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
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

  void _handleFavoritesData(dynamic data) {
    try {
      final List<dynamic> rawList = data as List<dynamic>;
      for (var item in rawList) {
        if (item is Map<String, dynamic>) {
          final chatUserId = item['Id'];
          if (chatUserId == widget.userId) {
            setState(() {
              _isFavorite = true;
            });
            break;
          }
        }
      }
    } catch (e) {
      log("Erro ao processar favoritos: $e");
    }
  }

  void _handleReaction(dynamic data) {
    if (data == null) return;
    try {
      final map = data as Map<String, dynamic>;
      final messageId = map['MessageId'] as String;
      final reaction = map['Reaction'] as String;
      final reactorUserId = map['ReactorUserId'] as String;

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final oldMsg = _messages[idx];
          final newReactions = Map<String, String>.from(oldMsg.reactions);
          newReactions[reactorUserId] = reaction;
          _messages[idx] = oldMsg.copyWith(reactions: newReactions);
        }
      });
    } catch (e) {
      showSnackbar(context, "Erro ao processar reação: $e");
    }
  }

  void _handleReply(dynamic data) {
    if (data == null) return;
    try {
      final map = data as Map<String, dynamic>;
      final newMessage = PrivateChatMessageModel.fromJson(map);

      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
    } catch (e) {
      showSnackbar(context, "Erro ao processar resposta: $e");
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatDeleteMessage,
        {
          'MessageId': messageId,
        },
      );
    } catch (err) {
      showSnackbar(context, "Erro ao excluir mensagem: $err");
    }
  }

  Future<void> _deleteEntireChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Excluir conversa"),
          content: const Text("Deseja realmente excluir todo o chat?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Excluir"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatDeleteChat,
          {
            'ReceiverUserId': widget.userId,
          },
        );
        if (mounted) Navigator.pop(context);
      } catch (err) {
        showSnackbar(context, "Erro ao excluir o chat: $err");
      }
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      try {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatSendMessage,
          {
            'ReceiverUserId': widget.userId,
            'Message': message,
          },
        );
        _messageController.clear();
        _scrollToBottom();
      } catch (err) {
        showSnackbar(context, "Erro ao enviar mensagem: $err");
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _sendReaction(String messageId, String emoji) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatReactToMessage,
        {
          'MessageId': messageId,
          'Reaction': emoji,
        },
      );
    } catch (e) {
      showSnackbar(context, "Erro ao enviar reação: $e");
    }
  }

  Future<void> _replyToMessage(
      String originalMessageId, String replyText) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatReplyToMessage,
        {
          'ReceiverUserId': widget.userId,
          'OriginalMessageId': originalMessageId,
          'Message': replyText,
        },
      );
    } catch (e) {
      showSnackbar(context, "Erro ao enviar resposta: $e");
    }
  }

  Future<void> _initAudioRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      showSnackbar(context, "Permissão de microfone negada");
      return;
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _record.hasPermission();
    if (!hasPermission) {
      showSnackbar(context, "Sem permissão para gravar áudio");
      return;
    }

    _isRecording = true;
    setState(() {});

    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _recordingSeconds++;
      if (_recordingSeconds >= 60) {
        await _stopRecording();
      }
      setState(() {});
    });

    final tempPath =
        '${Directory.systemTemp.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _record.start(
      const RecordConfig(),
      path: tempPath,
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final path = await _record.stop();
    _isRecording = false;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() {});

    if (path != null) {
      await _sendAudio(path);
    }
  }

  Future<void> _sendAudio(String filePath) async {
    setState(() => _isSendingMedia = true);
    try {
      final fileBytes = await File(filePath).readAsBytes();
      final base64Audio = base64Encode(fileBytes);

      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatSendAudio,
        {
          'ReceiverUserId': widget.userId,
          'Audio': base64Audio,
          'FileName': 'audio_${DateTime.now().millisecondsSinceEpoch}.aac',
        },
      );
    } catch (e) {
      showSnackbar(context, "Erro ao enviar áudio: $e");
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _editAndSendImage(image);
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _editAndSendImage(image);
    }
  }

  Future<void> _editAndSendImage(XFile image) async {
    setState(() => _isSendingMedia = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.file(
            File(image.path),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List editedBytes) async {
                final compressedBytes =
                    await _compressImage(editedBytes, quality: 40);
                final base64Image = base64Encode(compressedBytes);
                await _sendImage(base64Image, image.name);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      );
    } catch (e) {
      showSnackbar(context, "Erro ao editar/enviar imagem: $e");
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes,
      {int quality = 50}) async {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage != null) {
      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: quality));
    }
    return imageBytes;
  }

  Future<void> _sendImage(String base64Image, String fileName) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatSendImage,
        {
          'ReceiverUserId': widget.userId,
          'Image': base64Image,
          'FileName': fileName,
        },
      );
    } catch (e) {
      showSnackbar(context, "Erro ao enviar imagem: $e");
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 15),
    );
    if (video == null) return;

    await _sendVideo(video);
  }

  Future<void> _recordVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    if (video == null) return;

    await _sendVideo(video);
  }

  Future<void> _sendVideo(XFile video) async {
    setState(() => _isSendingMedia = true);
    try {
      final originalFile = File(video.path);
      final compressedFile = await _compressVideo(originalFile);
      if (compressedFile == null) {
        showSnackbar(context, "Falha ao comprimir vídeo");
        return;
      }

      final fileBytes = await compressedFile.readAsBytes();
      final base64Video = base64Encode(fileBytes);

      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatSendVideo,
        {
          'ReceiverUserId': widget.userId,
          'Video': base64Video,
          'FileName': video.name,
        },
      );
    } catch (e) {
      showSnackbar(context, "Erro ao enviar vídeo: $e");
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<File?> _compressVideo(File file) async {
    try {
      final compressedVideo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (compressedVideo != null && compressedVideo.file != null) {
        return compressedVideo.file;
      }
    } catch (e) {
      debugPrint("Erro ao comprimir vídeo: $e");
    }
    return null;
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatRemoveFavorite,
          {
            'ChatUserId': widget.userId,
          },
        );
      } else {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatAddFavorite,
          {
            'ChatUserId': widget.userId,
          },
        );
      }
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } catch (e) {
      showSnackbar(context, "Erro ao alterar favorito: $e");
    }
  }

  Future<void> _blockUser() async {
    final result = await ApiService.blockUser(widget.userId);
    if (result == null) {
      showSnackbar(context, 'Usuário bloqueado com sucesso.',
          color: Colors.green);
      Navigator.pop(context);
    } else {
      showSnackbar(context, 'Erro ao bloquear usuário: $result');
    }
  }

  Future<void> _reportUser() async {
    final result = await ApiService.reportUser(widget.userId);
    if (result == null) {
      showSnackbar(context, 'Usuário denunciado com sucesso.',
          color: Colors.green);
    } else {
      showSnackbar(context, 'Erro ao denunciar usuário: $result');
    }
  }

  Future<void> _initiateCall(String targetUserId) async {
    try {
      final callManager = Provider.of<CallManager>(context, listen: false);
      callManager.startCall(targetUserId);
    } catch (e) {
      showSnackbar(context, "Erro ao iniciar chamada: $e");
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _scrollController.dispose();

    if (_isRecording) {
      _record.stop();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final myMessageColor = isDarkMode ? Colors.blue[400] : Colors.blue[300];
    final otherMessageColor = isDarkMode ? Colors.grey[700] : Colors.grey[500];

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewUserPage(userId: widget.userId),
              ),
            );
          },
          child: Row(
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
        ),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _deleteEntireChat,
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _initiateCall(widget.userId),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _blockUser();
                  break;
                case 'report':
                  _reportUser();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'block',
                child: Text('Bloquear'),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Denunciar'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMine = message.senderId != widget.userId;
                    final time =
                        DateJSONUtils.formatMessageTime(message.createdAt);
                    return _buildMessageRow(
                      message: message,
                      isMine: isMine,
                      time: time,
                      myMessageColor: myMessageColor!,
                      otherMessageColor: otherMessageColor!,
                    );
                  },
                ),
              ),
              _buildBottomBar(),
            ],
          ),
          if (_isSendingMedia)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageRow({
    required PrivateChatMessageModel message,
    required bool isMine,
    required String time,
    required Color myMessageColor,
    required Color otherMessageColor,
  }) {
    final isDeleted = (message.message == 'Mensagem excluída');
    final showTrash = !isDeleted && isMine;

    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: _buildMessageBubble(
            message: message,
            isMine: isMine,
            time: time,
            myMessageColor: myMessageColor,
            otherMessageColor: otherMessageColor,
          ),
        ),
        if (showTrash) _buildTrashIcon(message.id),
      ],
    );
  }

  Widget _buildTrashIcon(String messageId) {
    return InkWell(
      onTap: () => _deleteMessage(messageId),
      child: const Padding(
        padding: EdgeInsets.only(right: 8.0, bottom: 4.0),
        child: Icon(Icons.delete),
      ),
    );
  }

  Widget _buildMessageBubble({
    required PrivateChatMessageModel message,
    required bool isMine,
    required String time,
    required Color myMessageColor,
    required Color otherMessageColor,
  }) {
    final content = message.message;
    final lower = content.toLowerCase();
    final bool isImage = lower.startsWith('https://') && _isImageUrl(content);
    final bool isVideo = lower.startsWith('https://') && _isVideoUrl(content);
    final bool isAudio = lower.startsWith('https://') && _isAudioUrl(content);
    final bool isDeleted = content == 'Mensagem excluída';

    final replyToMsg = (message.replyToMessageId != null)
        ? _messages.firstWhere(
            (m) => m.id == message.replyToMessageId,
            orElse: () => PrivateChatMessageModel(
              id: '',
              createdAt: DateTime.now(),
              senderId: '',
              message: '(Mensagem original não encontrada)',
            ),
          )
        : null;

    return InkWell(
      onLongPress: () => _showMessageActionsDialog(message),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? myMessageColor : otherMessageColor,
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
            if (replyToMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Em resposta a: ${replyToMsg.message.startsWith('https://') ? 'Arquivo' : replyToMsg.message}",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (isDeleted)
              const Text(
                "Mensagem excluída",
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              )
            else if (isImage)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.image, size: 40),
                  SizedBox(width: 8),
                  Text("Foto"),
                ],
              )
            else if (isVideo)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.video_file, size: 40),
                  SizedBox(width: 8),
                  Text("Vídeo"),
                ],
              )
            else if (isAudio)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.audiotrack, size: 40),
                  SizedBox(width: 8),
                  Text("Áudio"),
                ],
              )
            else
              Text(
                content,
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.reactions.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: message.reactions.values.map((emoji) {
                      return Text(emoji, style: const TextStyle(fontSize: 18));
                    }).toList(),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (!isDeleted && (isImage || isVideo || isAudio)) {
                      _openMediaPreview(content);
                    }
                  },
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaPreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewPage(url: url),
      ),
    );
  }

  void _showMessageActionsDialog(PrivateChatMessageModel message) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text("Ações"),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'reply'),
              child: const Text("Responder"),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'react'),
              child: const Text("Reagir"),
            ),
            if (message.senderId != widget.userId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text("Excluir mensagem"),
              ),
          ],
        );
      },
    );

    if (result == 'reply') {
      _promptReply(message.id);
    } else if (result == 'react') {
      _showReactionPicker(message.id);
    } else if (result == 'delete') {
      _deleteMessage(message.id);
    }
  }

  void _showReactionPicker(String messageId) async {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];
    final selectedEmoji = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text("Selecione uma reação"),
          children: emojis.map((emoji) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, emoji),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            );
          }).toList(),
        );
      },
    );
    if (selectedEmoji != null) {
      _sendReaction(messageId, selectedEmoji);
    }
  }

  void _promptReply(String originalMessageId) {
    final replyController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Responder"),
          content: TextField(
            controller: replyController,
            decoration: const InputDecoration(
              hintText: "Digite sua resposta...",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                final text = replyController.text;
                if (text.isNotEmpty) {
                  _replyToMessage(originalMessageId, text);
                }
                Navigator.pop(ctx);
              },
              child: const Text("Enviar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle, size: 28),
            onSelected: (value) {
              if (value == 'gallery') _pickImage();
              if (value == 'camera') _takePhoto();
              if (value == 'video_gallery') _pickVideo();
              if (value == 'video_camera') _recordVideo();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'gallery',
                child: Text('Foto da Galeria'),
              ),
              const PopupMenuItem(
                value: 'camera',
                child: Text('Tirar Foto'),
              ),
              const PopupMenuItem(
                value: 'video_gallery',
                child: Text('Vídeo da Galeria'),
              ),
              const PopupMenuItem(
                value: 'video_camera',
                child: Text('Gravar Vídeo'),
              ),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Digite sua mensagem...",
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                color: _isRecording
                    ? Colors.red
                    : Provider.of<ThemeProvider>(context).isDarkMode
                        ? Colors.white
                        : Colors.black),
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
        ],
      ),
    );
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.contains('image');
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.contains('video');
  }

  bool _isAudioUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.aac') ||
        lower.endsWith('.mp3') ||
        lower.contains('audio');
  }
}

class MediaPreviewPage extends StatefulWidget {
  final String url;

  const MediaPreviewPage({Key? key, required this.url}) : super(key: key);

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  AudioPlayer? _audioPlayer;

  bool get isImage => _isImageUrl(widget.url);

  bool get isVideo => _isVideoUrl(widget.url);

  bool get isAudio => _isAudioUrl(widget.url);

  @override
  void initState() {
    super.initState();
    if (isVideo) {
      _initializeVideo();
    } else if (isAudio) {
      _initializeAudio();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.network(widget.url);
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: true,
    );
    setState(() {});
  }

  Future<void> _initializeAudio() async {
    _audioPlayer = AudioPlayer();
    await _audioPlayer!.play(UrlSource(widget.url));
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();

    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isImage) {
      return Scaffold(
        appBar: AppBar(title: const Text("Visualizando Imagem")),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(widget.url),
          ),
        ),
      );
    } else if (isVideo) {
      return Scaffold(
        appBar: AppBar(title: const Text("Visualizando Vídeo")),
        body: _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const Center(child: CircularProgressIndicator()),
      );
    } else if (isAudio) {
      return Scaffold(
        appBar: AppBar(title: const Text("Reproduzindo Áudio")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.audiotrack, size: 100),
              SizedBox(height: 20),
              Text("Tocando áudio..."),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text("Mídia")),
        body: Center(
          child: Text("Tipo de mídia não reconhecido: ${widget.url}"),
        ),
      );
    }
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.contains('image');
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.contains('video');
  }

  bool _isAudioUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.aac') ||
        lower.endsWith('.mp3') ||
        lower.contains('audio');
  }
}
