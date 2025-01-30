import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Pacotes externos
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/services/signalr_manager.dart';

// Para áudio
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

// Para manipulação de imagem local (compressão)
import 'package:image/image.dart' as img;
import 'package:snarf/utils/signalr_event_type.dart';

// Para vídeo
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// MODELO DE MENSAGEM
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

/// PÁGINA DO CHAT PRIVADO
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
  // Controladores
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Lista de mensagens
  List<PrivateChatMessageModel> _messages = [];

  // Instâncias para gravação de áudio
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  /// Inicializa chat, ouvindo eventos SignalR e pedindo mensagens antigas
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

    // Inicializar gravador de áudio
    await _initAudioRecorder();
  }

  /// Tratador de mensagens vindas do SignalR
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
        default:
          log("Evento desconhecido: $typeString");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  /// Recebe mensagens anteriores
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

  /// Quando chega uma mensagem nova
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

  /// Quando uma mensagem é deletada
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

  /// Deleta mensagem
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

  /// Envia mensagem de texto
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

  /// Para rolar a lista ao final
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  /// Mostra visualização de imagem, vídeo ou áudio em página separada
  void _openMediaPreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewPage(url: url),
      ),
    );
  }

  /// --------------- ENVIO DE IMAGEM ---------------
  Future<Uint8List> _compressImage(Uint8List imageBytes,
      {int quality = 70}) async {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage != null) {
      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: quality));
    }
    return imageBytes;
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
    // Abre o ProImageEditor
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
              Navigator.pop(context); // Fecha o editor
            },
          ),
        ),
      ),
    );
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

  /// --------------- ENVIO DE VÍDEO ---------------
  /// Pegar vídeo da galeria, limite de 15s
  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 15), // Limite de 15s
    );
    if (video == null) return;

    await _sendVideo(video);
  }

  /// Gravar vídeo pela câmera, limite de 15s
  Future<void> _recordVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15), // Limite de 15s
    );
    if (video == null) return;

    await _sendVideo(video);
  }

  Future<void> _sendVideo(XFile video) async {
    try {
      final fileBytes = await File(video.path).readAsBytes();
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
    }
  }

  /// --------------- ENVIO DE ÁUDIO ---------------

  /// Inicializa gravador (pede permissões de microfone)
  Future<void> _initAudioRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      showSnackbar(context, "Permissão de microfone negada");
      return;
    }
    await _audioRecorder.openRecorder();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    _isRecording = true;
    setState(() {});

    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _recordingSeconds++;
      if (_recordingSeconds >= 60) {
        // Força parada
        await _stopRecording();
      }
      setState(() {});
    });

    final tempPath = '${Directory.systemTemp.path}/temp_audio.aac';
    await _audioRecorder.startRecorder(
      toFile: tempPath,
      codec: Codec.aacADTS,
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final path = await _audioRecorder.stopRecorder();
    _isRecording = false;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() {});

    if (path != null) {
      // Envia o áudio
      await _sendAudio(path);
    }
  }

  Future<void> _sendAudio(String filePath) async {
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
    }
  }

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
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
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message.senderId != widget.userId;
                final time = DateJSONUtils.formatMessageTime(message.createdAt);
                final content = message.message;

                return _buildMessageBubble(
                  context: context,
                  content: content,
                  isMine: isMine,
                  time: time,
                  myMessageColor: myMessageColor!,
                  otherMessageColor: otherMessageColor!,
                  onDelete: () async {
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
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancelar"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
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
                  },
                );
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// BOLHA DE MENSAGEM (texto/imagem/áudio/vídeo)
  Widget _buildMessageBubble({
    required BuildContext context,
    required String content,
    required bool isMine,
    required String time,
    required Color myMessageColor,
    required Color otherMessageColor,
    required VoidCallback onDelete,
  }) {
    final lower = content.toLowerCase();
    final bool isImage = lower.contains('https://') && _isImageUrl(content);
    final bool isVideo = lower.contains('https://') && _isVideoUrl(content);
    final bool isAudio = lower.contains('https://') && _isAudioUrl(content);
    final bool isDeleted = content == 'Mensagem excluída';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMine && !isDeleted ? onDelete : null,
        onTap: (!isDeleted && (isImage || isVideo || isAudio))
            ? () => _openMediaPreview(content)
            : null,
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
              if (isDeleted)
                Text(
                  "Mensagem excluída",
                  style: const TextStyle(
                      fontSize: 16, fontStyle: FontStyle.italic),
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
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Colors.grey[200],
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
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _recordVideo,
          ),
          IconButton(
            icon: const Icon(Icons.video_collection),
            onPressed: _pickVideo,
          ),

          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: _isRecording ? Colors.red : Colors.black,
            ),
            onPressed: _isRecording ? _stopRecording : _startRecording,
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

/// PÁGINA DE VISUALIZAÇÃO DE MÍDIA (IMAGEM, VÍDEO OU ÁUDIO)
class MediaPreviewPage extends StatefulWidget {
  final String url;

  const MediaPreviewPage({Key? key, required this.url}) : super(key: key);

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  FlutterSoundPlayer? _audioPlayer;

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
    _videoController = VideoPlayerController.networkUrl(widget.url as Uri);
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: true,
    );
    setState(() {});
  }

  Future<void> _initializeAudio() async {
    _audioPlayer = FlutterSoundPlayer();
    await _audioPlayer!.openPlayer();
    _audioPlayer!.startPlayer(fromURI: widget.url);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();

    _audioPlayer?.stopPlayer();
    _audioPlayer?.closePlayer();

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
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 100),
            const SizedBox(height: 20),
            const Text("Tocando áudio..."),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text("Mídia")),
        body: Center(
          child: Text("Não reconhecido: ${widget.url}"),
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
