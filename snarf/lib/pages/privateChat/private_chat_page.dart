import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Pacotes externos
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/services/signalr_manager.dart';

// Para gravação de áudio (usando record)
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

// Para manipulação de imagem local (compressão)
import 'package:image/image.dart' as img;
import 'package:snarf/utils/signalr_event_type.dart';
import 'package:video_compress/video_compress.dart';

// Para vídeo
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

// Para reprodução de áudio
import 'package:audioplayers/audioplayers.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<PrivateChatMessageModel> _messages = [];

  final _record = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  /// Para controlar se o chat atual é favorito ou não
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  /// Inicializa chat: ouve eventos do SignalR, busca mensagens antigas
  /// e busca lista de favoritos para verificar se este chat é favorito.
  Future<void> _initializeChat() async {
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);

    // Pegar mensagens anteriores
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetPreviousMessages,
      {'ReceiverUserId': widget.userId},
    );

    // Marcar como lidas
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatMarkMessagesAsRead,
      {'SenderUserId': widget.userId},
    );

    // Solicitar lista de favoritos
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetFavorites,
      {},
    );

    await _initAudioRecorder();
  }

  /// Tratador de mensagens vindas do SignalR
  void _handleSignalRMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);

      // Nem todo retorno do servidor segue o mesmo padrão com "Type"/"Data".
      // Se não encontrar "Type" e "Data", pode ser a resposta de favoritos
      // que está sendo enviada de forma diferente no servidor.
      if (!message.containsKey('Type') && !message.containsKey('Data')) {
        // Tentar decodificar diretamente como List de favoritos?
        // Ex: [{"Id":"..."}] ou algo do gênero.
        // Ajuste conforme o retorno real do servidor.
        if (message.keys.isNotEmpty) {
          // Se cair aqui, provavelmente é a resposta de favoritos
          // que foi enviada como JSON simples.
          // Você pode ajustar a forma de parse de acordo com a resposta do server.
          return;
        }
      }

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
        case SignalREventType.PrivateChatReceiveFavorites:
          _handleFavoritesData(data);
          break;
        default:
          log("Evento desconhecido ou não tratado: $typeString");
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
      final List<PrivateChatMessageModel> previousMessages = rawList.map((item) {
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

  /// Recebendo dados dos favoritos (chats ou IDs)
  void _handleFavoritesData(dynamic data) {
    // Ajuste de acordo com o tipo de retorno real do servidor.
    // Se `data` for uma lista de objetos contendo "Id" do usuário:
    // Exemplo: [{"Id":"USER_123"}, {"Id":"USER_456"}]
    //
    // Precisamos comparar com `widget.userId`.
    try {
      final List<dynamic> rawList = data as List<dynamic>;
      // Se cada item for { "Id": "UserId" }, verifique se o userId está lá.
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

  /// Deleta chat inteiro
  Future<void> _deleteEntireChat() async {
    try {
      // Confirmação
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

      if (confirm != true) return;

      await SignalRManager().sendSignalRMessage(
        SignalREventType.PrivateChatDeleteChat,
        {
          'ReceiverUserId': widget.userId,
        },
      );

      // Após excluir, você pode fechar a tela
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (err) {
      showSnackbar(context, "Erro ao excluir o chat: $err");
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

  /// Rola a lista até o final
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  /// Abre visualização de mídia (imagem, vídeo ou áudio) em página separada
  void _openMediaPreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewPage(url: url),
      ),
    );
  }

  /// --------------- ENVIO DE IMAGEM ---------------
  Future<Uint8List> _compressImage(Uint8List imageBytes, {int quality = 50}) async {
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          File(image.path),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List editedBytes) async {
              final compressedBytes = await _compressImage(editedBytes, quality: 40);
              final base64Image = base64Encode(compressedBytes);
              await _sendImage(base64Image, image.name);
              Navigator.pop(context);
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

  /// --------------- GRAVAÇÃO DE ÁUDIO (record) ---------------
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

  /// Alterna o favorito do chat
  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        // Se já é favorito, vamos remover
        await SignalRManager().sendSignalRMessage(
          SignalREventType.PrivateChatRemoveFavorite,
          {
            'ChatUserId': widget.userId,
          },
        );
      } else {
        // Se não é favorito, vamos adicionar
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
            // Abrir página de visualização do usuário
            // Ajuste conforme seu routing real:
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
          // Ícone de favorito (pino/estrela) ao lado do nome
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
            ),
            onPressed: _toggleFavorite,
          ),
          // Exclusão do chat inteiro
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _deleteEntireChat,
          ),
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
                final time =
                DateJSONUtils.formatMessageTime(message.createdAt);
                final content = message.message;

                return _buildMessageBubble(
                  context: context,
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
    );
  }

  /// BOLHA DE MENSAGEM (texto/imagem/áudio/vídeo)
  Widget _buildMessageBubble({
    required BuildContext context,
    required PrivateChatMessageModel message,
    required bool isMine,
    required String time,
    required Color myMessageColor,
    required Color otherMessageColor,
  }) {
    final content = message.message;
    final lower = content.toLowerCase();
    final bool isImage = lower.contains('https://') && _isImageUrl(content);
    final bool isVideo = lower.contains('https://') && _isVideoUrl(content);
    final bool isAudio = lower.contains('https://') && _isAudioUrl(content);
    final bool isDeleted = content == 'Mensagem excluída';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
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
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                // Ícone de lixeira à direita
                // Exibe somente se a mensagem ainda não foi excluída
                // e se esta msg pertence ao user (sender/receiver)
                // Pelo back-end, se o user for ou sender ou receiver, pode apagar.
                if (!isDeleted)
                  InkWell(
                    onTap: () async {
                      await _deleteMessage(message.id);
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.delete, size: 18),
                    ),
                  ),
              ],
            ),
          ],
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