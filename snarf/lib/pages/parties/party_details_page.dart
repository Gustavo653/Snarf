import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/parties/create_edit_party_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class PartyDetailsPage extends StatefulWidget {
  final String partyId;
  final String userId;

  const PartyDetailsPage({
    super.key,
    required this.partyId,
    required this.userId,
  });

  @override
  State<PartyDetailsPage> createState() => _PartyDetailsPageState();
}

class _PartyDetailsPageState extends State<PartyDetailsPage> {
  Map<String, dynamic>? _partyData;
  bool _isLoading = true;

  bool _loadingRequest = false;
  bool _loadingConfirmation = false;
  bool _loadingDecline = false;

  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoadingRecentChats = false;

  @override
  void initState() {
    super.initState();
    _loadPartyDetails();
  }

  Future<void> _loadPartyDetails() async {
    final data = await ApiService.getPartyDetails(
      partyId: widget.partyId,
      userId: widget.userId,
    );
    if (!mounted) return;
    if (data == null) {
      showErrorSnackbar(context, 'Não foi possível carregar detalhes da festa');
      Navigator.pop(context);
      return;
    }

    setState(() {
      _partyData = data;
      _isLoading = false;
    });
  }

  Future<void> _editParty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEditPartyPage(partyId: widget.partyId),
      ),
    );
    if (result == true) {
      await _loadPartyDetails();
    }
  }

  Future<void> _deleteParty() async {
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

    final result = await ApiService.deleteParty(widget.partyId, widget.userId);
    if (!mounted) return;
    if (result == true) {
      showSuccessSnackbar(context, 'Festa excluída com sucesso!');
      Navigator.pop(context);
    } else {
      showErrorSnackbar(context, 'Erro ao excluir festa');
    }
  }

  Future<void> _requestParticipation() async {
    if (_loadingRequest) return;
    setState(() => _loadingRequest = true);

    final result = await ApiService.requestPartyParticipation(
      partyId: widget.partyId,
      userId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loadingRequest = false);

    if (result == true) {
      await _loadPartyDetails();
      showSuccessSnackbar(context, 'Solicitação enviada');
    } else {
      showErrorSnackbar(context, 'Erro ao solicitar participação');
    }
  }

  Future<void> _confirmParticipation(String targetUserId) async {
    if (_loadingConfirmation) return;
    setState(() => _loadingConfirmation = true);

    final result = await ApiService.confirmUser(widget.partyId, targetUserId);

    if (!mounted) return;
    setState(() => _loadingConfirmation = false);

    if (result == true) {
      await _loadPartyDetails();
      showSuccessSnackbar(context, 'Convite confirmado');
    } else {
      showErrorSnackbar(context, 'Erro ao confirmar');
    }
  }

  Future<void> _declineParticipation(String targetUserId) async {
    if (_loadingDecline) return;
    setState(() => _loadingDecline = true);

    final result = await ApiService.declineUser(widget.partyId, targetUserId);

    if (!mounted) return;
    setState(() => _loadingDecline = false);

    if (result == true) {
      await _loadPartyDetails();
      showSuccessSnackbar(context, 'Convite recusado');
    } else {
      showErrorSnackbar(context, 'Erro ao recusar');
    }
  }

  Future<void> _openInviteUsersDialog() async {
    await _loadRecentChats();

    if (!mounted) return;

    final List<String> selectedUserIds = [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            if (_isLoadingRecentChats) {
              return AlertDialog(
                title: const Text('Convidar usuários'),
                content: const SizedBox(
                  height: 80,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (_recentChats.isEmpty) {
              return AlertDialog(
                title: const Text('Convidar usuários'),
                content: const Text('Nenhum chat recente encontrado.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Convidar usuários'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: _recentChats.length,
                  itemBuilder: (context, index) {
                    final chat = _recentChats[index];
                    final userId = chat['UserId']?.toString() ?? '';
                    final userName = chat['UserName'] ?? '';

                    final isSelected = selectedUserIds.contains(userId);

                    return CheckboxListTile(
                      title: Text(userName),
                      value: isSelected,
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            selectedUserIds.add(userId);
                          } else {
                            selectedUserIds.remove(userId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedUserIds.isEmpty
                      ? null
                      : () async {
                          for (final id in selectedUserIds) {
                            final success =
                                await ApiService.requestPartyParticipation(
                              partyId: widget.partyId,
                              userId: id,
                            );
                            if (success) {
                              showSuccessSnackbar(
                                context,
                                'Convite enviado para $id',
                              );
                            } else {
                              showErrorSnackbar(
                                context,
                                'Erro ao convidar $id',
                              );
                            }
                          }

                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          _loadPartyDetails();
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

  Future<void> _loadRecentChats() async {
    setState(() => _isLoadingRecentChats = true);

    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);

    await SignalRManager().sendSignalRMessage(
      SignalREventType.PrivateChatGetRecentChats,
      {},
    );

    await Future.delayed(const Duration(milliseconds: 400));

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

  String _mapType(int type) {
    switch (type) {
      case 0:
        return "Orgia";
      case 1:
        return "Bomba e Despejo";
      case 2:
        return "Masturbação Coletiva";
      case 3:
        return "Grupo de Bukkake";
      case 4:
        return "Grupo Fetiche";
      case 5:
        return "Evento Especial";
      default:
        return "Desconhecido";
    }
  }

  Widget _buildUserList(String title, List<dynamic>? users,
      {bool isPending = false}) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    return users == null || users.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: configProvider.textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...users.map((u) {
                  final userName = u['name'] ?? 'Sem nome';
                  return ListTile(
                    title: Text(
                      userName,
                      style: TextStyle(color: configProvider.textColor),
                    ),
                    trailing: isPending &&
                            _partyData!['ownerId'] == widget.userId
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                onPressed: () => _confirmParticipation(u['id']),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _declineParticipation(u['id']),
                              ),
                            ],
                          )
                        : null,
                  );
                }).toList()
              ],
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        title: const Text('Detalhes da Festa'),
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
        actions: [
          if (!_isLoading &&
              _partyData != null &&
              _partyData!['ownerId'] == widget.userId)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: configProvider.iconColor),
              onSelected: (value) {
                if (value == 'edit') {
                  _editParty();
                } else if (value == 'invite') {
                  _openInviteUsersDialog();
                } else if (value == 'delete') {
                  _deleteParty();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar Festa'),
                ),
                const PopupMenuItem(
                  value: 'invite',
                  child: Text('Convidar Usuários'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir Festa'),
                ),
              ],
            )
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: configProvider.iconColor),
            )
          : _partyData == null
              ? Center(
                  child: Text('Festa não encontrada',
                      style: TextStyle(color: configProvider.textColor)),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_partyData!['coverImageUrl'] != null &&
                            _partyData!['coverImageUrl'].toString().isNotEmpty)
                          Image.network(_partyData!['coverImageUrl']),
                        const SizedBox(height: 16),
                        Text(
                          _partyData!['title'] ?? '',
                          style: TextStyle(
                            fontSize: 20,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _partyData!['description'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tipo: ${_mapType(_partyData!['type'])}',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Local: ${_partyData!['location']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Instruções: ${_partyData!['instructions']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Papel: ${_partyData!['userRole']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Convidados: ${_partyData!['invitedCount']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        Text(
                          'Confirmados: ${_partyData!['confirmedCount']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: configProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_partyData!['ownerId'] != widget.userId &&
                            _partyData!['userRole'] ==
                                'Disponível para Participar')
                          ElevatedButton(
                            onPressed: _requestParticipation,
                            child: _loadingRequest
                                ? const CircularProgressIndicator()
                                : const Text('Solicitar Participação'),
                          ),

                        FutureBuilder(
                          future: ApiService.getAllParticipants(
                              widget.partyId, widget.userId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            if (snapshot.data == null) {
                              return Text(
                                "Erro ao carregar participantes",
                                style:
                                    TextStyle(color: configProvider.textColor),
                              );
                            }
                            final data = snapshot.data!;
                            final confirmeds =
                                data['confirmeds'] as List<dynamic>?;
                            final inviteds = data['inviteds'] as List<dynamic>?;

                            return Column(
                              children: [
                                _buildUserList("Confirmados", confirmeds),
                                _buildUserList("Convidados", inviteds,
                                    isPending: true),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}