import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/date_utils.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';
import 'package:snarf/providers/config_provider.dart';

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
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
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

          var unread = mapItem['UnreadCount'];
          if(unread > 0){
            configProvider.SetNotificationMessage(true);
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
      showErrorSnackbar(context, "Erro ao processar chats recentes: $e");
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
      showErrorSnackbar(context, "Erro ao processar favoritos: $e");
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
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: configProvider.iconColor,
              ),
            )
          : _filteredChats.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma conversa encontrada.',
                    style: TextStyle(
                      fontSize: 16,
                      color: configProvider.textColor,
                    ),
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
                            backgroundColor: isOnline
                                ? configProvider.customGreen
                                : Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: ClipOval(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: CircleAvatar(
                                    backgroundImage: InterceptedImageProvider(
                                      originalProvider:
                                          NetworkImage(chat['UserImage']),
                                      hideImages: configProvider.hideImages,
                                    ),
                                    radius: 18,
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
                                  color: configProvider.customGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: configProvider.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        chat['UserName'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: configProvider.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        chat['LastMessage'].toString().startsWith('https://')
                            ? 'Arquivo'
                            : chat['LastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: configProvider.textColor),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateJSONUtils.formatRelativeTime(
                                chat['LastMessageDate'].toString()),
                            style: TextStyle(
                              fontSize: 12,
                              color: configProvider.textColor.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (chat['UnreadCount'] > 0)
                            const SizedBox(height: 4),
                          if (chat['UnreadCount'] > 0)
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: configProvider.customOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text(
                                      '${chat['UnreadCount']}',
                                      style: TextStyle(
                                        color: configProvider.textColor,
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
