import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  _RecentChatPageState createState() => _RecentChatPageState();
}

class _RecentChatPageState extends State<RecentPage> {
  final SignalRService _signalRService = SignalRService();
  List<Map<String, dynamic>> _recentChats = [];
  Set<String> _favoriteChatIds = {};
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
        onMethods: [
          'ReceiveRecentChats',
          'ReceivePrivateMessage',
          'ReceiveFavorites'
        ],
        eventHandlers: {
          'ReceiveRecentChats': _handleRecentChats,
          'ReceivePrivateMessage': _receiveNewMessages,
          'ReceiveFavorites': _handleFavorites,
        },
      );

      log('Conexão estabelecida, buscando dados...');
      await _signalRService.invokeMethod("GetRecentChats", []);
      await _signalRService.invokeMethod("GetFavorites", []);

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

  void _handleFavorites(List<Object?>? data) {
    if (data != null && data.isNotEmpty) {
      final jsonString = data.first as String;
      try {
        log('Processando favoritos...');
        final favoriteIds = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          _favoriteChatIds = favoriteIds.map((id) => id.toString()).toSet();
        });
        log('Favoritos carregados: ${_favoriteChatIds.length}');
      } catch (e) {
        log('Erro ao processar JSON de favoritos: $e');
        showSnackbar(context, "Erro ao carregar favoritos: $e");
      }
    } else {
      log("Nenhum favorito encontrado.");
    }
  }

  void _receiveNewMessages(List<Object?>? data) {
    log('Sincronizando novas mensagens...');
    _signalRService.invokeMethod("GetRecentChats", []);
  }

  Future<void> _deleteChat(String chatUserId) async {
    try {
      bool confirmDelete = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Confirmar Exclusão'),
                content: Text('Você tem certeza que deseja deletar este chat?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: Text('Excluir'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (confirmDelete) {
        log('Deletando chat $chatUserId...');
        await _signalRService.invokeMethod("DeleteChat", [chatUserId]);
        setState(() {
          _recentChats.removeWhere((chat) => chat['UserId'] == chatUserId);
        });
      } else {
        log('Exclusão de chat cancelada.');
      }
    } catch (e) {
      log('Erro ao deletar chat: $e');
      showSnackbar(context, "Erro ao deletar chat.");
    }
  }

  Future<void> _toggleFavorite(String chatUserId) async {
    try {
      if (_favoriteChatIds.contains(chatUserId)) {
        log('Removendo chat $chatUserId dos favoritos...');
        await _signalRService.invokeMethod("RemoveFavorite", [chatUserId]);
        setState(() {
          _favoriteChatIds.remove(chatUserId);
        });
        showSnackbar(context, "Chat removido dos favoritos.");
      } else {
        log('Adicionando chat $chatUserId aos favoritos...');
        await _signalRService.invokeMethod("AddFavorite", [chatUserId]);
        setState(() {
          _favoriteChatIds.add(chatUserId);
        });
        showSnackbar(context, "Chat adicionado aos favoritos.");
      }
    } catch (e) {
      log('Erro ao alterar favorito: $e');
      showSnackbar(context, "Erro ao alterar favorito.");
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentChats.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma conversa encontrada.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _recentChats.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                  itemBuilder: (context, index) {
                    final chat = _recentChats[index];
                    final isFavorite =
                        _favoriteChatIds.contains(chat['UserId']);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(chat['UserImage']),
                        radius: 24,
                      ),
                      title: Text(
                        chat['UserName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat['LastMessage']
                                    .toString()
                                    .startsWith('https://')
                                ? 'Arquivo'
                                : chat['LastMessage'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateJSONUtils.formatRelativeTime(
                                chat['LastMessageDate']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              color: isFavorite ? Colors.yellow : Colors.grey,
                            ),
                            onPressed: () => _toggleFavorite(chat['UserId']),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteChat(chat['UserId']),
                          ),
                          if (chat['UnreadCount'] > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${chat['UnreadCount']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () async {
                        log('Abrindo chat com ${chat['UserName']}');
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrivateChatPage(
                              userId: chat['UserId'],
                              userName: chat['UserName'],
                              userImage: chat['UserImage'],
                            ),
                          ),
                        );
                        await _signalRService
                            .invokeMethod("GetRecentChats", []);
                      },
                    );
                  },
                ),
    );
  }
}
