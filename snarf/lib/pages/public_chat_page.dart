import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/utils/api_constants.dart';

class PublicChatPage extends StatefulWidget {
  const PublicChatPage({super.key});

  @override
  _PublicChatPageState createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late HubConnection _chatHubConnection;
  List<String> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupSignalRConnection();
  }

  Future<void> _setupSignalRConnection() async {
    _chatHubConnection = HubConnectionBuilder()
        .withUrl('${ApiConstants.baseUrl.replaceAll('/api', '')}/PublicChatHub')
        .build();

    _chatHubConnection.on("ReceiveMessage", (args) {
      final user = args?[0] as String;
      final message = args?[1] as String;
      setState(() {
        _messages.add('$user: $message');
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
        SnackBar(content: Text("Erro ao conectar ao chat público: $err")),
      );
    }
  }

  void _sendMessage() async {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      await _chatHubConnection.invoke("SendMessage", args: [message]);
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

  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Público'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => _toggleTheme(context),
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
