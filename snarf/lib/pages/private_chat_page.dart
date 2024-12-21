import 'package:flutter/material.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PrivateChatPage extends StatefulWidget {
  final String userName;

  const PrivateChatPage({super.key, required this.userName});

  @override
  _PrivateChatPageState createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late HubConnection _chatHubConnection;
  List<String> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
  }

  Future<String> getAccessToken() async {
    return await _storage.read(key: 'token') ?? '';
  }

  Future<void> _setupSignalRConnection() async {
    _chatHubConnection = HubConnectionBuilder()
        .withUrl(
            '${ApiConstants.baseUrl.replaceAll('/api', '')}/PrivateChatHub',
            options: HttpConnectionOptions(
                accessTokenFactory: () async => await getAccessToken()))
        .build();

    _chatHubConnection.on("ReceivePrivateMessage", (args) {
      final message = args?[1] as String;
      setState(() {
        _messages.add(message);
      });
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    try {
      await _chatHubConnection.start();
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao conectar ao chat privado: $err")),
      );
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      await _chatHubConnection
          .invoke("SendPrivateMessage", args: [widget.userName, message]);
      setState(() {
        _messages.add("Eu: $message");
        _messageController.clear();
      });
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _chatHubConnection.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat com ${widget.userName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Digite uma mensagem",
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blue,
                  iconSize: 30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
