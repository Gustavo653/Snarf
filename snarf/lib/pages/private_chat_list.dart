import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'private_chat_page.dart';

class PrivateChatListPage extends StatefulWidget {
  const PrivateChatListPage({super.key});

  @override
  _PrivateChatListPageState createState() => _PrivateChatListPageState();
}

class _PrivateChatListPageState extends State<PrivateChatListPage> {
  final SignalRService _signalRService = SignalRService();
  List<Map<String, dynamic>> _recentChats = [];
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSignalRConnection();
  }

  Future<String> getAccessToken() async {
    try {
      final token = await _storage.read(key: 'token') ?? '';
      log('Token recuperado: $token');
      return token;
    } catch (e) {
      log("Erro ao recuperar token: $e");
      return '';
    }
  }

  Future<void> _initializeSignalRConnection() async {
    try {
      log('Iniciando conexão com o chat privado...');
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PrivateChatHub',
        onMethods: ['ReceiveRecentChats', 'ReceivePrivateMessage'],
        eventHandlers: {
          'ReceiveRecentChats': _handleRecentChats,
          'ReceivePrivateMessage': _receiveNewMessages,
        },
      );

      log('Conexão estabelecida, buscando chats recentes...');
      await _signalRService.invokeMethod("GetRecentChats", []);

      setState(() {
        _isLoading = false;
      });
    } catch (err) {
      log("Erro ao conectar ao chat privado: $err");
      setState(() {
        _isLoading = false;
      });
      showSnackbar(context, "Erro ao conectar ao chat privado: $err");
    }
  }

  void _handleRecentChats(List<Object?>? data) {
    if (data != null && data.isNotEmpty) {
      final jsonString = data.first as String;
      try {
        log('Processando chats recentes...');
        final parsedData = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          _recentChats = parsedData.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              throw Exception("Item inesperado no JSON: $item");
            }
          }).toList();
        });
        log('Chats recentes carregados: ${_recentChats.length} encontrados');
      } catch (e) {
        log('Erro ao processar JSON recebido: $e');
        showSnackbar(context, "Erro ao processar chats recentes: $e");
      }
    } else {
      log("Nenhum chat recente encontrado");
    }
  }

  void _receiveNewMessages(List<Object?>? data) {
    log('Sincronizando novas mensagens...');
    _signalRService.invokeMethod("GetRecentChats", []);
  }

  @override
  void dispose() {
    log('Fechando conexão SignalR...');
    _signalRService.stopConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats Privados'),
        actions: [
          ThemeToggle(),
        ],
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
                        DateJSONUtils.formatDate(chat['LastMessageDate']),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        log('Abrindo chat com ${chat['UserName']}');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrivateChatPage(
                              userId: chat['UserId'],
                              userName: chat['UserName'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
