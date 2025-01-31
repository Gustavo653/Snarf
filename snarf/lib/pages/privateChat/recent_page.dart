import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  _RecentChatPageState createState() => _RecentChatPageState();
}

class _RecentChatPageState extends State<RecentPage> {
  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSignalRConnection();
  }

  Future<void> _initializeSignalRConnection() async {
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);

    await SignalRManager()
        .sendSignalRMessage(SignalREventType.PrivateChatGetRecentChats, {});

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

                    bool isOnline = false;
                    final lastActivity = chat['LastActivity'] as DateTime?;
                    if (lastActivity != null) {
                      final diff = DateTime.now().difference(lastActivity);
                      isOnline = diff.inMinutes < 1;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blueAccent.shade700,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipOval(
                            child: Image.network(
                              chat['UserImage'],
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
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            DateJSONUtils.formatRelativeTime(
                                chat['LastMessageDate']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (chat['UnreadCount'] > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'NOVO',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${chat['UnreadCount']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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
