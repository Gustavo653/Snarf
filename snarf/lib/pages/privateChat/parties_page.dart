import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/parties/create_edit_party_page.dart';
import 'package:snarf/pages/parties/party_details_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/enums/signalr_event_type.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  bool _isLoading = false;
  List<dynamic> _parties = [];
  String? userId;

  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoadingRecentChats = false;

  @override
  void initState() {
    super.initState();
    _fetchAllParties();
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);
  }

  Future<void> _fetchAllParties() async {
    userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showErrorSnackbar(context, 'Usuário não logado');
      return;
    }

    setState(() => _isLoading = true);
    final data = await ApiService.getAllParties(userId!);
    setState(() => _isLoading = false);

    if (data == null) {
      showErrorSnackbar(context, 'Erro ao buscar festas');
      return;
    }

    _parties = data["data"] ?? [];
    setState(() {});
  }

  Future<void> _loadRecentChats() async {
    setState(() => _isLoadingRecentChats = true);
    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetRecentChats,
      {},
    );
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoadingRecentChats = false);
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
        case SignalREventType.PrivateChatReceiveMessage:
        case SignalREventType.MapReceiveLocation:
        case SignalREventType.UserDisconnected:
          break;
        default:
          log("Evento não reconhecido: ${message['Type']}");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  void _handleRecentChats(dynamic data) {
    try {
      final parsedData = data as List<dynamic>;
      setState(() {
        _recentChats = parsedData.map((item) {
          final mapItem = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item);

          return {
            'UserId': mapItem['UserId'],
            'UserName': mapItem['UserName'],
            'UserImage': mapItem['UserImage'],
            'LastMessage': mapItem['LastMessage'],
            'LastMessageDate': mapItem['LastMessageDate'],
            'UnreadCount': mapItem['UnreadCount'],
          };
        }).toList();
      });
    } catch (e) {
      showErrorSnackbar(context, "Erro ao processar chats recentes: $e");
    }
  }

  Future<void> _openInviteUsersDialog(String partyId) async {
    await _loadRecentChats();
    if (!mounted) return;
    if (_recentChats.isEmpty) {
      showErrorSnackbar(context, "Nenhum chat recente encontrado.");
      return;
    }
    final List<String> selectedUserIds = [];
    await showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (_isLoadingRecentChats) {
              return AlertDialog(
                title: const Text('Convidar Usuários'),
                content: const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            return AlertDialog(
              title: const Text('Convidar Usuários'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: _recentChats.length,
                  itemBuilder: (context, index) {
                    final chat = _recentChats[index];
                    final uid = chat['UserId'].toString();
                    final name = chat['UserName'] ?? 'Sem nome';
                    final isSelected = selectedUserIds.contains(uid);
                    return CheckboxListTile(
                      title: Text(name),
                      value: isSelected,
                      onChanged: (bool? checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            selectedUserIds.add(uid);
                          } else {
                            selectedUserIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedUserIds.isEmpty
                      ? null
                      : () async {
                          for (final uid in selectedUserIds) {
                            final success =
                                await ApiService.requestPartyParticipation(
                              partyId: partyId,
                              userId: uid,
                            );
                            if (success) {
                              showSuccessSnackbar(
                                  context, "Convite enviado para $uid");
                            } else {
                              showErrorSnackbar(
                                  context, "Erro ao convidar $uid");
                            }
                          }
                          if (!mounted) return;
                          Navigator.pop(dialogCtx);
                        },
                  child: const Text('Convidar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteParty(String partyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Festa'),
        content: const Text('Tem certeza que deseja excluir esta festa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await ApiService.deleteParty(partyId, userId!);
    if (result) {
      showSuccessSnackbar(context, 'Festa excluída com sucesso!');
      _fetchAllParties();
    } else {
      showErrorSnackbar(context, 'Erro ao excluir festa');
    }
  }

  Future<void> _acceptInvite(String partyId) async {
    final success = await ApiService.confirmUser(partyId, userId!);
    if (success) {
      showSuccessSnackbar(context, 'Convite aceito!');
      _fetchAllParties();
    } else {
      showErrorSnackbar(context, 'Erro ao aceitar convite');
    }
  }

  Future<void> _declineInvite(String partyId) async {
    final success = await ApiService.declineUser(partyId, userId!);
    if (success) {
      showSuccessSnackbar(context, 'Convite recusado!');
      _fetchAllParties();
    } else {
      showErrorSnackbar(context, 'Erro ao recusar');
    }
  }

  Future<void> _requestParticipation(String partyId) async {
    final success = await ApiService.requestPartyParticipation(
      partyId: partyId,
      userId: userId!,
    );
    if (success) {
      showSuccessSnackbar(context, 'Solicitação enviada!');
      _fetchAllParties();
    } else {
      showErrorSnackbar(context, 'Erro ao solicitar participação');
    }
  }

  Widget _buildPartyItem(dynamic party) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final partyId = party["id"].toString();
    final title = party["title"] ?? '';
    final userRole = party["userRole"] ?? '';
    final imageUrl = party["imageUrl"] as String? ?? '';
    return Card(
      color: configProvider.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        leading: (imageUrl.isNotEmpty)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(Icons.event, color: configProvider.iconColor),
        title: Text(
          title,
          style: TextStyle(
            color: configProvider.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          userRole,
          style: TextStyle(color: configProvider.textColor),
        ),
        trailing: _buildTrailingActions(party),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartyDetailsPage(
                partyId: partyId,
                userId: userId!,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailingActions(dynamic party) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final partyId = party["id"].toString();
    final userRole = party["userRole"] ?? '';
    switch (userRole) {
      case 'Hospedando':
        return PopupMenuButton<String>(
          color: configProvider.primaryColor,
          icon: Icon(Icons.more_vert, color: configProvider.iconColor),
          onSelected: (value) {
            if (value == 'invite') {
              _openInviteUsersDialog(partyId);
            } else if (value == 'delete') {
              _deleteParty(partyId);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'invite',
              child: Text(
                'Convidar Usuários',
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Excluir Festa',
                style: TextStyle(color: configProvider.textColor),
              ),
            ),
          ],
        );
      case 'Convidado':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check, color: configProvider.iconColor),
              tooltip: 'Aceitar',
              onPressed: () => _acceptInvite(partyId),
            ),
            IconButton(
              icon: Icon(Icons.close, color: configProvider.iconColor),
              tooltip: 'Recusar',
              onPressed: () => _declineInvite(partyId),
            ),
          ],
        );
      case 'Solicitante':
        return IconButton(
          icon: Icon(Icons.close, color: configProvider.iconColor),
          tooltip: 'Cancelar solicitação',
          onPressed: () => _declineInvite(partyId),
        );
      case 'Confirmado':
        return IconButton(
          icon: Icon(Icons.exit_to_app, color: configProvider.iconColor),
          tooltip: 'Sair da festa',
          onPressed: () => _declineInvite(partyId),
        );
      case 'Disponível para Participar':
      default:
        return TextButton(
          onPressed: () => _requestParticipation(partyId),
          child: Text(
            'Participar',
            style: TextStyle(color: configProvider.iconColor),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    return Container(
      color: configProvider.primaryColor,
      child: Stack(
        children: [
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: configProvider.iconColor,
              ),
            )
          else if (_parties.isEmpty)
            Center(
              child: Text(
                "Nenhuma festa encontrada",
                style: TextStyle(color: configProvider.textColor, fontSize: 16),
              ),
            )
          else
            ListView.builder(
              itemCount: _parties.length,
              itemBuilder: (ctx, index) {
                final party = _parties[index];
                return _buildPartyItem(party);
              },
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: configProvider.secondaryColor,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateEditPartyPage(),
                  ),
                );
                if (result == true) {
                  _fetchAllParties();
                }
              },
              child: Icon(Icons.add, color: configProvider.iconColor),
            ),
          ),
        ],
      ),
    );
  }
}