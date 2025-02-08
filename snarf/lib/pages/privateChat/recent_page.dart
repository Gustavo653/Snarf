import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class RecentPage extends StatefulWidget {
  final bool showFavorites;

  const RecentPage({super.key, this.showFavorites = false});

  @override
  _RecentChatPageState createState() => _RecentChatPageState();
}

class _RecentChatPageState extends State<RecentPage> {
  List<Map<String, dynamic>> _recentChats = [];
  List<String> _favoriteChatIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSignalRConnection();
  }

  Future<void> _initializeSignalRConnection() async {
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);

    await Future.wait([
      SignalRManager()
          .sendSignalRMessage(SignalREventType.PrivateChatGetRecentChats, {}),
      SignalRManager()
          .sendSignalRMessage(SignalREventType.PrivateChatGetFavorites, {}),
    ]);

    setState(() => _isLoading = false);
  }

  void _handleSignalRMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);
      final SignalREventType type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == message['Type'],
      );

      final dynamic data = message['Data'];

      switch (type) {
        case SignalREventType.PrivateChatReceiveRecentChats:
          _handleRecentChats(data);
          break;
        case SignalREventType.PrivateChatReceiveFavorites:
          _handleFavoriteChats(data);
          break;
        case SignalREventType.PrivateChatReceiveMessage:
          _receiveNewMessages(data);
          break;
        case SignalREventType.MapReceiveLocation:
          _handleMapReceiveLocation(data);
          break;
        case SignalREventType.UserDisconnected:
          _handleUserDisconnected(data);
          break;
        default:
          log("Evento não reconhecido: ${message['Type']}");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  void _handleRecentChats(List<Object?>? data) {
    try {
      final parsedData = data as List<dynamic>;
      setState(() {
        _recentChats = parsedData.map((item) {
          final mapItem = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item);

          DateTime? lastActivity;
          if (mapItem['LastActivity'] != null) {
            try {
              lastActivity =
                  DateTime.parse(mapItem['LastActivity'].toString()).toLocal();
            } catch (_) {
              lastActivity = null;
            }
          }

          return {
            'UserId': mapItem['UserId'],
            'UserName': mapItem['UserName'],
            'UserImage': mapItem['UserImage'],
            'LastMessage': mapItem['LastMessage'],
            'LastMessageDate': mapItem['LastMessageDate'],
            'UnreadCount': mapItem['UnreadCount'],
            'LastActivity': lastActivity,
          };
        }).toList();
      });
    } catch (e) {
      showSnackbar(context, "Erro ao processar chats recentes: $e");
    }
  }

  void _handleFavoriteChats(List<Object?>? data) {
    try {
      if (data == null) return;
      final parsedData = data as List<dynamic>;
      setState(() {
        _favoriteChatIds =
            parsedData.map((item) => item['Id'].toString()).toList();
      });
    } catch (e) {
      showSnackbar(context, "Erro ao processar favoritos: $e");
    }
  }

  Future<void> _receiveNewMessages(dynamic data) async {
    await SignalRManager()
        .sendSignalRMessage(SignalREventType.PrivateChatGetRecentChats, {});
  }

  void _handleMapReceiveLocation(dynamic data) {
    if (data is Map<String, dynamic>) {
      final String userId = data['userId'];
      final index = _recentChats.indexWhere((chat) => chat['UserId'] == userId);
      if (index != -1) {
        setState(() {
          _recentChats[index]['LastActivity'] = DateTime.now();
        });
      }
    }
  }

  void _handleUserDisconnected(dynamic data) {
    if (data is Map<String, dynamic>) {
      final String userId = data['userId'];
      final index = _recentChats.indexWhere((chat) => chat['UserId'] == userId);
      if (index != -1) {
        setState(() {
          _recentChats[index]['LastActivity'] =
              DateTime.now().subtract(const Duration(days: 1));
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredChats {
    if (widget.showFavorites) {
      return _recentChats
          .where((chat) => _favoriteChatIds.contains(chat['UserId']))
          .toList();
    }
    return _recentChats;
  }

  @override
  void dispose() {
    log('Fechando conexão SignalR...');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredChats.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma conversa encontrada.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = _filteredChats[index];

                    bool isOnline = false;
                    final lastActivity = chat['LastActivity'] as DateTime?;
                    if (lastActivity != null) {
                      final diff = DateTime.now().difference(lastActivity);
                      isOnline = diff.inMinutes < 1;
                    }

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                isOnline ? Colors.green : Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: ClipOval(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: Image.network(
                                    chat['UserImage'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, error, stack) {
                                      return Image.asset(
                                        'assets/images/user_anonymous.png',
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              left: 10,
                              top: 4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateJSONUtils.formatRelativeTime(
                                chat['LastMessageDate'].toString()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (chat['UnreadCount'] > 0)
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2A120),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text(
                                      '${chat['UnreadCount']}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      onTap: () async {
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
                      },
                    );
                  },
                ),
    );
  }
}
