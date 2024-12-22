import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:snarf/utils/api_constants.dart';
import 'private_chat_page.dart';

class PrivateChatListPage extends StatefulWidget {
  const PrivateChatListPage({super.key});

  @override
  _PrivateChatListPageState createState() => _PrivateChatListPageState();
}

class _PrivateChatListPageState extends State<PrivateChatListPage> {
  late HubConnection _hubConnection;
  List<Map<String, dynamic>> _recentChats = [];
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSignalRConnection();
  }

  Future<String> getAccessToken() async {
    return await _storage.read(key: 'token') ?? '';
  }

  Future<void> _initializeSignalRConnection() async {
    // Configura o HubConnection
    _hubConnection = HubConnectionBuilder()
        .withUrl(
            '${ApiConstants.baseUrl.replaceAll('/api', '')}/PrivateChatHub',
            options: HttpConnectionOptions(
                accessTokenFactory: () async => await getAccessToken()))
        .withAutomaticReconnect()
        .build();

    // Registrar o callback para "ReceiveRecentChats"
    _hubConnection.on("ReceiveRecentChats", _handleRecentChats);
    _hubConnection.on("ReceivePrivateMessage", _receiveNewMessages);

    // Iniciar conexão com o SignalR
    await _hubConnection.start();

    // Solicitar conversas recentes

    _hubConnection.invoke("GetRecentChats");

    setState(() {
      _isLoading = false;
    });
  }

  void _receiveNewMessages(List<Object?>? data) {
    log('chamando sincronização');
    _hubConnection.invoke("GetRecentChats");
  }

  void _handleRecentChats(List<Object?>? data) {
    if (data != null && data.isNotEmpty) {
      // Decodificar o JSON recebido (como string) para uma lista de mapas
      final jsonString = data.first as String;
      try {
        final parsedData = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          _recentChats = parsedData.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item); // Converte se necessário
            } else {
              throw Exception("Item inesperado no JSON: $item");
            }
          }).toList();
        });
      } catch (e) {
        debugPrint('Erro ao processar JSON recebido: $e');
      }
    }
  }

  @override
  void dispose() {
    _hubConnection.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats Privados'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentChats.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma conversa encontrada.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _recentChats.length,
                  itemBuilder: (context, index) {
                    final chat = _recentChats[index];
                    return ListTile(
                      title: Text(chat['UserName']),
                      subtitle: Text(chat['LastMessage']),
                      trailing: Text(
                        _formatDate(chat['LastMessageDate']),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PrivateChatPage(userId: chat['UserId']),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
