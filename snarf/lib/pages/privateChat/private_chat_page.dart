import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

  final _record = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  bool _isFavorite = false;
  bool _isSendingMedia = false;

  String? _selectedMessageId;
  PrivateChatMessageModel? _replyingToMessage;

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

      SignalREventType type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == typeString,
        orElse: () => SignalREventType.PrivateChatReceiveMessage,
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
      final reaction = map['Reaction'];
      final reactorUserId = map['ReactorUserId'] as String;

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final oldMsg = _messages[idx];
          final newReactions = Map<String, String>.from(oldMsg.reactions);

          if (reaction == null || reaction.isEmpty) {
            newReactions.remove(reactorUserId);
          } else {
            newReactions[reactorUserId] = reaction;
          }

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
    } finally {
      setState(() => _selectedMessageId = null);
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
    final message = _messageController.text.trim();
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
      final newReaction = emoji.isEmpty ? null : emoji;

      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatReactToMessage,
        {
          'MessageId': messageId,
          'Reaction': newReaction,
        },
      );

      setState(() => _selectedMessageId = null);
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

  void _openEmojiPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: EmojiPicker(
            config: Config(
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: Color(0xFF0b0951),
                iconColor: Colors.white,
              ),
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: Color(0xFF0b0951),
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: Color(0xFF0b0951),
                buttonIconColor: Colors.white,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: Color(0xFF0b0951),
                buttonIconColor: Colors.white,
                buttonColor: Color(0xFF0b0951),
              ),
            ),
            onBackspacePressed: () {
              _sendReaction(messageId, '');
              Navigator.pop(ctx);
            },
            onEmojiSelected: (category, emoji) {
              final selectedEmoji = emoji.emoji;
              _sendReaction(messageId, selectedEmoji);
              Navigator.pop(ctx);
            },
          ),
        );
      },
    );
  }

  void _onMessageLongPress(PrivateChatMessageModel message) {
    setState(() {
      if (_selectedMessageId == message.id) {
        _selectedMessageId = null;
      } else {
        _selectedMessageId = message.id;
      }
    });
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
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(widget.userImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: [Colors.transparent, Colors.black87],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedMessageId = null);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message.senderId != widget.userId;
                      final time = DateJSONUtils.formatRelativeTime(
                          message.createdAt.toString());

                      return _buildMessageRow(
                        message: message,
                        isMine: isMine,
                        time: time,
                      );
                    },
                  ),
                ),
              ),
              _buildReplyBanner(),
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

  Widget _buildReplyBanner() {
    if (_replyingToMessage == null) return const SizedBox();
    final originalText = _replyingToMessage!.message;
    final isMedia = originalText.startsWith('https://');
    return Container(
      color: Color(0xFF0b0951),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.reply, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMedia
                    ? 'Respondendo a um arquivo (imagem/vídeo/áudio)'
                    : 'Respondendo: $originalText',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _replyingToMessage = null);
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          PopupMenuButton<String>(
            color: Color(0xFF0b0951),
            icon: const Icon(Icons.add_circle, size: 28),
            onSelected: (value) {
              if (value == 'gallery') _pickImage();
              if (value == 'camera') _takePhoto();
              if (value == 'video_gallery') _pickVideo();
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
            ],
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Digite sua mensagem...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              final text = _messageController.text.trim();
              if (text.isEmpty) return;

              if (_replyingToMessage != null) {
                _replyToMessage(_replyingToMessage!.id, text);
                _replyingToMessage = null;
                _messageController.clear();
              } else {
                _sendMessage();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {
              _recordVideo();
            },
          ),
          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: _isRecording
                  ? Colors.red
                  : Provider.of<ThemeProvider>(context).isDarkMode
                      ? Colors.white
                      : Colors.black,
            ),
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow({
    required PrivateChatMessageModel message,
    required bool isMine,
    required String time,
  }) {
    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMine ? 40 : 8,
        right: isMine ? 8 : 40,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          _buildMessageBubble(message, isMine),
          if (_selectedMessageId == message.id)
            _buildActionsBar(message, isMine),
        ],
      ),
    );
  }

  Widget _buildActionsBar(PrivateChatMessageModel message, bool isMine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.mood),
            onPressed: () => _openEmojiPicker(message.id),
            tooltip: 'Reagir',
          ),
          IconButton(
            icon: const Icon(Icons.reply),
            onPressed: () {
              setState(() {
                _replyingToMessage = message;
                _selectedMessageId = null;
              });
            },
            tooltip: 'Responder',
          ),
          if (isMine && message.message != 'Mensagem excluída')
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteMessage(message.id),
              tooltip: 'Excluir',
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(PrivateChatMessageModel message, bool isMine) {
    final isDeleted = message.message == 'Mensagem excluída';
    final content = message.message;
    final lower = content.toLowerCase();
    final bool isImage = lower.startsWith('https://') && _isImageUrl(content);
    final bool isVideo = lower.startsWith('https://') && _isVideoUrl(content);
    final bool isAudio = lower.startsWith('https://') && _isAudioUrl(content);

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

    final bubbleColor = const Color(0xFFE8ECEF);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(0),
      bottomRight:
          isMine ? const Radius.circular(0) : const Radius.circular(16),
    );

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(message),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyToMsg != null && replyToMsg.id.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Em resposta: ${replyToMsg.message.startsWith('https://') ? '(Mídia)' : replyToMsg.message}",
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
                if (isDeleted)
                  const Text(
                    "Mensagem excluída",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.black,
                    ),
                  )
                else if (isImage || isVideo || isAudio)
                  _InlineMediaWidget(
                    mediaUrl: content,
                    isImage: isImage,
                    isVideo: isVideo,
                    isAudio: isAudio,
                  )
                else
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                  ),
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: message.reactions.values.map((emoji) {
                      return Text(emoji, style: const TextStyle(fontSize: 18));
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (_selectedMessageId == message.id)
            _buildActionsBar(message, isMine),
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

class _InlineMediaWidget extends StatefulWidget {
  final String mediaUrl;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;

  const _InlineMediaWidget({
    required this.mediaUrl,
    required this.isImage,
    required this.isVideo,
    required this.isAudio,
  });

  @override
  State<_InlineMediaWidget> createState() => _InlineMediaWidgetState();
}

class _InlineMediaWidgetState extends State<_InlineMediaWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoInitialized = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    } else if (widget.isAudio) {
      _initAudio();
    }
  }

  Future<void> _initVideo() async {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      optionsTranslation: OptionsTranslation(
        playbackSpeedButtonText: 'Velocidade de reprodução',
        cancelButtonText: 'Cancelar',
      ),
      allowFullScreen: true,
      aspectRatio: _videoController!.value.aspectRatio,
    );

    setState(() {
      _videoInitialized = true;
    });
  }

  Future<void> _initAudio() async {
    _audioPlayer.onDurationChanged.listen((dur) {
      setState(() => _totalDuration = dur);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      setState(() => _currentPosition = pos);
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    });

    await _audioPlayer.play(UrlSource(widget.mediaUrl));
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isImage) {
      return _buildImage();
    } else if (widget.isVideo) {
      return _buildVideo();
    } else if (widget.isAudio) {
      return _buildAudio();
    }
    return const SizedBox.shrink();
  }

  Widget _buildImage() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              child: Image.network(widget.mediaUrl),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.mediaUrl,
          width: 250,
          height: 250,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (!_videoInitialized || _chewieController == null) {
      return const SizedBox(
        width: 50,
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildAudio() {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlayPause,
                color: Colors.black,
              ),
              Expanded(
                child: Slider(
                  activeColor: Colors.black,
                  min: 0,
                  max: _totalDuration.inMilliseconds.toDouble(),
                  value: _currentPosition.inMilliseconds
                      .toDouble()
                      .clamp(0, _totalDuration.inMilliseconds.toDouble()),
                  onChanged: (value) {
                    final pos = Duration(milliseconds: value.floor());
                    _audioPlayer.seek(pos);
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(UrlSource(widget.mediaUrl));
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
