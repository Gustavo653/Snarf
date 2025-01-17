import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
import 'package:snarf/services/signalr_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/show_snackbar.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final SignalRService _signalRService = SignalRService();
  List<Map<String, dynamic>> _favoriteChats = [];
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
      log('Iniciando conexão para buscar favoritos...');
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/PrivateChatHub',
        onMethods: ['ReceiveFavorites', 'ReceiveRecentChats'],
        eventHandlers: {
          'ReceiveFavorites': _handleFavoriteIds,
          'ReceiveRecentChats': _handleChatDetails,
        },
      );

      log('Conexão estabelecida. Buscando favoritos...');
      await _signalRService.invokeMethod("GetFavorites", []);
    } catch (err) {
      log("Erro ao conectar aos favoritos: $err");
      setState(() {
        _isLoading = false;
      });
      showSnackbar(context, "Erro ao conectar aos favoritos: $err");
    }
  }

  void _handleFavoriteIds(List<Object?>? data) {
    if (data != null && data.isNotEmpty) {
      final jsonString = data.first as String;
      try {
        log('Processando IDs dos favoritos...');
        final favoriteIds = jsonDecode(jsonString) as List<dynamic>;
        log('IDs dos favoritos: $favoriteIds');
        if (favoriteIds.isNotEmpty) {
          _signalRService.invokeMethod("GetRecentChats", []);
        } else {
          setState(() {
            _favoriteChats = [];
            _isLoading = false;
          });
        }
      } catch (e) {
        log('Erro ao processar JSON de IDs dos favoritos: $e');
        showSnackbar(context, "Erro ao processar favoritos: $e");
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      log("Nenhum favorito encontrado.");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleChatDetails(List<Object?>? data) {
    if (data != null && data.isNotEmpty) {
      final jsonString = data.first as String;
      try {
        log('Processando detalhes dos chats favoritos...');
        final chatDetails = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          _favoriteChats = chatDetails.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              throw Exception("Item inesperado no JSON: $item");
            }
          }).toList();
          _isLoading = false;
        });
        log('Detalhes dos chats favoritos carregados: ${_favoriteChats.length}');
      } catch (e) {
        log('Erro ao processar detalhes dos favoritos: $e');
        showSnackbar(context, "Erro ao processar detalhes dos favoritos: $e");
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      log("Nenhum detalhe de chat recebido.");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromFavorites(String userId) async {
    try {
      log('Removendo chat $userId dos favoritos...');
      await _signalRService.invokeMethod("RemoveFavorite", [userId]);
      setState(() {
        _favoriteChats.removeWhere((chat) => chat['UserId'] == userId);
      });
      showSnackbar(context, "Chat removido dos favoritos.");
    } catch (e) {
      log('Erro ao remover favorito: $e');
      showSnackbar(context, "Erro ao remover favorito.");
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
          : _favoriteChats.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum favorito encontrado.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _favoriteChats.length,
                  itemBuilder: (context, index) {
                    final chat = _favoriteChats[index];
                    return ListTile(
                      title: Text(chat['UserName']),
                      subtitle: Text(
                        chat['LastMessage'].toString().startsWith('https://')
                            ? 'Arquivo'
                            : chat['LastMessage'],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.star, color: Colors.yellow),
                        onPressed: () => _removeFromFavorites(chat['UserId']),
                      ),
                      onTap: () async {
                        log('Abrindo chat com ${chat['UserName']}');
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrivateChatPage(
                              userId: chat['UserId'],
                              userName: chat['UserName'],
                            ),
                          ),
                        );
                        await _signalRService.invokeMethod("GetFavorites", []);
                      },
                    );
                  },
                ),
    );
  }
}
