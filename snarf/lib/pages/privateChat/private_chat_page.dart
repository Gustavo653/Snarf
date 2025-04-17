import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
//import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
//import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/buy_subscription_page.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/providers/call_manager.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
import 'package:snarf/utils/distance_utils.dart';
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
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  List<PrivateChatMessageModel> _messages = [];
  final _record = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isFavorite = false;
  bool _isSendingMedia = false;
  String? _selectedMessageId;
  PrivateChatMessageModel? _replyingToMessage;
  DateTime? _lastActivity;
  double? _myLatitude;
  double? _myLongitude;
  double? _userLatitude;
  double? _userLongitude;

  bool _isLoading = false;

  bool get _isOnline {
    if (_lastActivity == null) return false;
    final difference = DateTime.now().difference(_lastActivity!);
    return difference.inMinutes < 1;
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    try {
      await _initLocation();
      await _loadUserInfo();

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
    } catch (e) {
      log("Erro ao inicializar chat: $e");
      showErrorSnackbar(context, "Erro ao inicializar chat: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initLocation() async {
    loc.Location location = loc.Location();
    var position = await location.getLocation();
    _myLatitude = position.latitude;
    _myLongitude = position.longitude;
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await ApiService.getUserInfoById(widget.userId);
    if (userInfo == null) {
      showErrorSnackbar(context, "Não foi possível carregar dados do usuário");
      return;
    }
    setState(() {
      if (userInfo['lastActivity'] != null) {
        _lastActivity = DateTime.parse(userInfo['lastActivity']).toLocal();
      }
      if (userInfo['lastLatitude'] != null &&
          userInfo['lastLongitude'] != null) {
        _userLatitude = (userInfo['lastLatitude'] as num).toDouble();
        _userLongitude = (userInfo['lastLongitude'] as num).toDouble();
      }
    });
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
        case SignalREventType.MapReceiveLocation:
          if (data is Map<String, dynamic>) {
            final userId = data['userId'] as String?;
            if (userId == widget.userId) {
              setState(() {
                _lastActivity = DateTime.now();
                if (data['Latitude'] != null && data['Longitude'] != null) {
                  _userLatitude = (data['Latitude'] as num).toDouble();
                  _userLongitude = (data['Longitude'] as num).toDouble();
                }
              });
            }
          }
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
      showErrorSnackbar(context, "Erro ao processar mensagens: $err");
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
      showErrorSnackbar(context, "Erro ao processar nova mensagem: $e");
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
      showErrorSnackbar(context, "Erro ao processar exclusão: $e");
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
      showErrorSnackbar(context, "Erro ao processar reação: $e");
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
      showErrorSnackbar(context, "Erro ao processar resposta: $e");
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatDeleteMessage,
        {'MessageId': messageId},
      );
    } catch (err) {
      showErrorSnackbar(context, "Erro ao excluir mensagem: $err");
    } finally {
      setState(() => _selectedMessageId = null);
    }
  }

  Future<void> _deleteEntireChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final configProvider = Provider.of<ConfigProvider>(ctx, listen: false);
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
            "Excluir conversa",
            style: TextStyle(
              color: configProvider.textColor,
            ),
          ),
          content: Text(
            "Deseja realmente excluir todo o chat?",
            style: TextStyle(
              color: configProvider.textColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                "Cancelar",
                style: TextStyle(
                  color: configProvider.textColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                "Excluir",
                style: TextStyle(
                  color: configProvider.textColor,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      try {
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatDeleteChat,
          {'ReceiverUserId': widget.userId},
        );
        if (mounted) Navigator.pop(context);
      } catch (err) {
        showErrorSnackbar(context, "Erro ao excluir o chat: $err");
      }
    }
  }

  Future<bool> _canSendMessage() async {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    DateTime? firstMessageDate = config.FirstMessageToday;
    DateTime now = DateTime.now().toUtc();

    if (firstMessageDate == null) {
      return true;
    }

    log("Data primeira mensagem: ${firstMessageDate.toUtc()} Data atual: $now");
    Duration difference = now.difference(firstMessageDate.toUtc());
    log("Diferença em minutos: ${difference.inMinutes}");

    return difference.inMinutes <= 30;
  }

  void _sendMessage() async {
    final config = Provider.of<ConfigProvider>(context, listen: false);

    if (await _canSendMessage() || config.isSubscriber) {
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
          showErrorSnackbar(context, "Erro ao enviar mensagem: $err");
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BuySubscriptionPage(),
        ),
      );
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
      showErrorSnackbar(context, "Erro ao enviar reação: $e");
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
      showErrorSnackbar(context, "Erro ao enviar resposta: $e");
    }
  }

  Future<void> _initAudioRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      showErrorSnackbar(context, "Permissão de microfone negada");
      return;
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final hasPermission = await _record.hasPermission();
    if (!hasPermission) {
      showErrorSnackbar(context, "Sem permissão para gravar áudio");
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
      showErrorSnackbar(context, "Erro ao enviar áudio: $e");
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
      showErrorSnackbar(context, "Erro ao editar/enviar imagem: $e");
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
      showErrorSnackbar(context, "Erro ao enviar imagem: $e");
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 15),
    );
    if (video == null) return;
    final durationOk = await _checkVideoDuration(File(video.path));
    if (!durationOk) {
      showErrorSnackbar(context, "O vídeo excede 15 segundos!");
      return;
    }
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
        showErrorSnackbar(context, "Falha ao comprimir vídeo");
        return;
      }
      final resizedFile = await _resizeVideo(compressedFile);
      final fileBytes = await resizedFile!.readAsBytes();
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
      showErrorSnackbar(context, "Erro ao enviar vídeo: $e");
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<File?> _resizeVideo(File inputFile) async {
    return inputFile;
    /*final String outputPath = '${inputFile.path}_square.mp4';

    final String inPath = "'${inputFile.path}'";
    final String outPath = "'$outputPath'";
    final String command =
        '-y -i $inPath -vf "crop=min(iw\\,ih):min(iw\\,ih),scale=720:720" -c:a copy $outPath';

    final session = await FFmpegKit.execute(command);

    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      final file = File(outputPath);
      if (file.existsSync()) {
        return file;
      }
    }
    return null;*/
  }

  Future<bool> _checkVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final duration = controller.value.duration;
    controller.dispose();
    return duration <= const Duration(seconds: 15);
  }

  Future<File?> _compressVideo(File file) async {
    final compressedVideo = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.HighestQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (compressedVideo != null && compressedVideo.file != null) {
      return compressedVideo.file;
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
      showErrorSnackbar(context, "Erro ao alterar favorito: $e");
    }
  }

  Future<void> _blockUser() async {
    final result = await ApiService.blockUser(widget.userId);
    if (result == null) {
      showSuccessSnackbar(context, 'Usuário bloqueado com sucesso.',
          color: Colors.green);
      Navigator.pop(context);
    } else {
      showErrorSnackbar(context, 'Erro ao bloquear usuário: $result');
    }
  }

  Future<void> _reportUser() async {
    final result = await ApiService.reportUser(widget.userId);
    if (result == null) {
      showSuccessSnackbar(context, 'Usuário denunciado com sucesso.',
          color: Colors.green);
      Navigator.pop(context);
    } else {
      showErrorSnackbar(context, 'Erro ao denunciar usuário: $result');
    }
  }

  Future<void> _initiateCall(String targetUserId) async {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    if (config.isSubscriber) {
      try {
        final callManager = Provider.of<CallManager>(context, listen: false);
        callManager.startCall(targetUserId);
        await _analytics.logEvent(
            name: 'view_user_initiate_call',
            parameters: {'targetUserId': targetUserId});
      } catch (e) {
        showErrorSnackbar(context, "Erro ao iniciar chamada: $e");
        await _analytics.logEvent(
            name: 'view_user_initiate_call_error',
            parameters: {'error': e.toString()});
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BuySubscriptionPage(),
        ),
      );
    }
  }

  void _openEmojiPicker(String messageId) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: configProvider.primaryColor,
      builder: (ctx) {
        return Container(
          color: configProvider.primaryColor,
          height: 300,
          child: EmojiPicker(
            onBackspacePressed: () {
              _sendReaction(messageId, '');
              Navigator.pop(ctx);
            },
            onEmojiSelected: (category, emoji) {
              final selectedEmoji = emoji.emoji;
              _sendReaction(messageId, selectedEmoji);
              Navigator.pop(ctx);
            },
            config: Config(
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: configProvider.primaryColor,
                iconColor: configProvider.iconColor,
                iconColorSelected: configProvider.secondaryColor,
              ),
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: configProvider.primaryColor,
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: configProvider.primaryColor,
                buttonIconColor: configProvider.iconColor,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: configProvider.primaryColor,
                buttonIconColor: configProvider.iconColor,
                buttonColor: configProvider.secondaryColor,
              ),
            ),
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

  Widget _buildOnlineStatusBar(ConfigProvider configProvider) {
    String distanceInfo = '';
    if (_myLatitude != null &&
        _myLongitude != null &&
        _userLatitude != null &&
        _userLongitude != null) {
      final distance = DistanceUtils.calculateDistance(
        _myLatitude!,
        _myLongitude!,
        _userLatitude!,
        _userLongitude!,
      );
      distanceInfo = '${distance.toStringAsFixed(2)} km';
    }
    return Container(
      width: double.infinity,
      color: configProvider.primaryColor.withOpacity(0.7),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PopupMenuButton<int>(
            color: configProvider.primaryColor,
            icon: Icon(Icons.more_horiz, color: configProvider.iconColor),
            onSelected: (value) {
              if (value == 0) {
                _deleteEntireChat();
              } else if (value == 1) {
                _reportUser();
              } else if (value == 2) {
                _blockUser();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Text(
                  'Excluir todo o chat',
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Text(
                  'Denunciar',
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  'Bloquear',
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _isOnline
                ? 'Conectado'
                : (_lastActivity != null
                    ? DateJSONUtils.formatRelativeTime(
                        _lastActivity!.toString())
                    : 'Offline'),
            style: TextStyle(color: configProvider.textColor),
          ),
          InkWell(
            onTap: distanceInfo.isNotEmpty
                ? () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          initialLatitude: _userLatitude,
                          initialLongitude: _userLongitude,
                        ),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.my_location,
                  size: 14,
                  color: Colors.blue,
                ),
                const SizedBox(width: 3),
                Text(
                  distanceInfo,
                  style: TextStyle(
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
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
                backgroundImage: InterceptedImageProvider(
                  originalProvider: NetworkImage(widget.userImage),
                  hideImages: configProvider.hideImages,
                ),
                radius: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.userName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: configProvider.textColor),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: configProvider.iconColor,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            onPressed: () => _initiateCall(widget.userId),
            icon: Icon(
              Icons.videocam,
              color: configProvider.iconColor,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: configProvider.iconColor),
            )
          : Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: InterceptedImageProvider(
                        originalProvider: NetworkImage(widget.userImage),
                        hideImages: configProvider.hideImages,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        Colors.transparent,
                        configProvider.primaryColor.withOpacity(0.8),
                      ],
                      stops: const [0.5, 1.0],
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
                              message.createdAt.toString(),
                            );
                            return _buildMessageRow(
                              context,
                              message: message,
                              isMine: isMine,
                              time: time,
                              configProvider: configProvider,
                            );
                          },
                        ),
                      ),
                    ),
                    _buildReplyBanner(configProvider),
                    _buildBottomBar(configProvider),
                    _buildOnlineStatusBar(configProvider),
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

  Widget _buildReplyBanner(ConfigProvider configProvider) {
    if (_replyingToMessage == null) return const SizedBox();
    final originalText = _replyingToMessage!.message;
    final isMedia = originalText.startsWith('https://');
    return Container(
      color: configProvider.primaryColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.reply, size: 20, color: configProvider.iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMedia
                    ? 'Respondendo a um arquivo (imagem/vídeo/áudio)'
                    : 'Respondendo: $originalText',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _replyingToMessage = null);
              },
              icon: Icon(Icons.close, color: configProvider.iconColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ConfigProvider configProvider) {
    return Container(
      color: configProvider.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          PopupMenuButton<String>(
            color: configProvider.primaryColor,
            icon: Icon(
              Icons.add_circle,
              size: 28,
              color: configProvider.iconColor,
            ),
            onSelected: (value) {
              if (value == 'gallery') _pickImage();
              if (value == 'camera') _takePhoto();
              if (value == 'video_gallery') _pickVideo();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'gallery',
                child: Text(
                  'Foto da Galeria',
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'camera',
                child: Text(
                  'Tirar Foto',
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'video_gallery',
                child: Text(
                  'Vídeo da Galeria',
                  style: TextStyle(
                    color: configProvider.textColor,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: configProvider.textColor),
              decoration: InputDecoration(
                hintText: "Digite sua mensagem...",
                hintStyle:
                    TextStyle(color: configProvider.textColor.withOpacity(0.7)),
                fillColor: configProvider.secondaryColor.withOpacity(0.15),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: configProvider.secondaryColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: configProvider.secondaryColor),
                ),
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: configProvider.iconColor),
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
            icon: Icon(Icons.camera_alt, color: configProvider.iconColor),
            onPressed: () => _recordVideo(),
          ),
          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: _isRecording ? Colors.red : configProvider.iconColor,
            ),
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context, {
    required PrivateChatMessageModel message,
    required bool isMine,
    required String time,
    required ConfigProvider configProvider,
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
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: configProvider.textColor.withOpacity(0.8),
            ),
          ),
          _buildMessageBubble(message, isMine, configProvider),
          if (_selectedMessageId == message.id)
            _buildActionsBar(message, isMine, configProvider),
        ],
      ),
    );
  }

  Widget _buildActionsBar(PrivateChatMessageModel message, bool isMine,
      ConfigProvider configProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          IconButton(
            icon: Icon(Icons.mood, color: configProvider.iconColor),
            onPressed: () => _openEmojiPicker(message.id),
          ),
          IconButton(
            icon: Icon(Icons.reply, color: configProvider.iconColor),
            onPressed: () {
              setState(() {
                _replyingToMessage = message;
                _selectedMessageId = null;
              });
            },
          ),
          if (isMine && message.message != 'Mensagem excluída')
            IconButton(
              icon: Icon(Icons.delete, color: configProvider.iconColor),
              onPressed: () => _deleteMessage(message.id),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(PrivateChatMessageModel message, bool isMine,
      ConfigProvider configProvider) {
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

    final bubbleColor = isMine
        ? configProvider.secondaryColor.withOpacity(0.8)
        : configProvider.secondaryColor.withOpacity(0.6);

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
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyToMsg != null && replyToMsg.id.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: configProvider.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Em resposta: ${replyToMsg.message.startsWith('https://') ? '(Mídia)' : replyToMsg.message}",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: configProvider.textColor,
                      ),
                    ),
                  ),
                if (isDeleted)
                  Text(
                    "Mensagem excluída",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: configProvider.textColor,
                    ),
                  )
                else if (isImage || isVideo || isAudio)
                  _InlineMediaWidget(
                    mediaUrl: content,
                    isImage: isImage,
                    isVideo: isVideo,
                    isAudio: isAudio,
                    textColor: configProvider.textColor,
                  )
                else
                  Text(
                    content,
                    style: TextStyle(
                        fontSize: 16, color: configProvider.textColor),
                  ),
                if (message.reactions.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: message.reactions.values.map((emoji) {
                      return Text(emoji, style: const TextStyle(fontSize: 18));
                    }).toList(),
                  ),
              ],
            ),
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

class _InlineMediaWidget extends StatefulWidget {
  final String mediaUrl;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;

  final Color textColor;

  const _InlineMediaWidget({
    required this.mediaUrl,
    required this.isImage,
    required this.isVideo,
    required this.isAudio,
    required this.textColor,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }

  Widget _buildAudio() {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Container(
      width: 200,
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
                color: configProvider.iconColor,
              ),
              Expanded(
                child: Slider(
                  activeColor: configProvider.iconColor,
                  inactiveColor: configProvider.iconColor,
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
                  color: configProvider.iconColor,
                ),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: TextStyle(
                  color: configProvider.iconColor,
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
