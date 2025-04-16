import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/parties/create_edit_party_page.dart';
import 'package:snarf/pages/parties/party_chat_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class PartyDetailsPage extends StatefulWidget {
  final String partyId;
  final String userId;

  const PartyDetailsPage({
    Key? key,
    required this.partyId,
    required this.userId,
  }) : super(key: key);

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
            final configProvider =
            Provider.of<ConfigProvider>(context, listen: false);

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
              backgroundColor: configProvider.primaryColor,
              title: Text(
                'Convidar usuários',
                style: TextStyle(color: configProvider.textColor),
              ),
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

                    return Card(
                      color: configProvider.secondaryColor,
                      child: CheckboxListTile(
                        title: Text(
                          userName,
                          style: TextStyle(color: configProvider.textColor),
                        ),
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
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: configProvider.textColor),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: configProvider.secondaryColor,
                  ),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required ConfigProvider config,
  }) {
    return Row(
      children: [
        Icon(icon, color: config.iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 16, color: config.textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList({
    required String title,
    required List<dynamic>? users,
    required bool isPending,
  }) {
    final config = Provider.of<ConfigProvider>(context, listen: false);

    if (users == null || users.isEmpty) return const SizedBox.shrink();

    return Card(
      color: config.secondaryColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: config.textColor,
                fontSize: 16,
              ),
            ),
            const Divider(),
            ...users.map((u) {
              final userName = u['name'] ?? 'Sem nome';
              final userId = u['id']?.toString() ?? '';
              final userImage = u['imageUrl'];

              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewUserPage(
                        userId: userId,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundImage: (userImage != null && userImage.isNotEmpty)
                      ? NetworkImage(userImage)
                      : null,
                  child: (userImage == null || userImage.isEmpty)
                      ? Icon(
                    Icons.person,
                    color: config.iconColor,
                  )
                      : null,
                ),
                title: Text(
                  userName,
                  style: TextStyle(color: config.textColor),
                ),
                trailing: isPending && _partyData!['ownerId'] == widget.userId
                    ? Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: config.customGreen),
                      onPressed: () => _confirmParticipation(userId),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: config.customRed),
                      onPressed: () => _declineParticipation(userId),
                    ),
                  ],
                )
                    : null,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    final userRole = _partyData?['userRole'] ?? '';

    final canViewSensitive = userRole == 'Hospedando' ||
        userRole == 'Confirmado' ||
        userRole == 'Convidado';

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
              color: configProvider.primaryColor,
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
                PopupMenuItem(
                  value: 'edit',
                  child: Text(
                    'Editar Festa',
                    style: TextStyle(color: configProvider.textColor),
                  ),
                ),
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
            )
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(color: configProvider.iconColor),
      )
          : _partyData == null
          ? Center(
        child: Text(
          'Festa não encontrada',
          style: TextStyle(color: configProvider.textColor),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_partyData!['coverImageUrl'] != null &&
                _partyData!['coverImageUrl'].toString().isNotEmpty &&
                !configProvider.hideImages)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_partyData!['coverImageUrl']),
              ),
            const SizedBox(height: 16),

            Card(
              color: configProvider.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _partyData!['title'] ?? '',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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

                    if (canViewSensitive) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        icon: Icons.category,
                        label: 'Tipo: ${_mapType(_partyData!['type'])}',
                        config: configProvider,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.location_pin,
                        label: 'Local: ${_partyData!['location']}',
                        config: configProvider,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.info_outline,
                        label:
                        'Instruções: ${_partyData!['instructions']}',
                        config: configProvider,
                      ),
                    ],

                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.group,
                      label:
                      'Convidados: ${_partyData!['invitedCount']}',
                      config: configProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.check_circle_outline,
                      label:
                      'Confirmados: ${_partyData!['confirmedCount']}',
                      config: configProvider,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (canViewSensitive)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: configProvider.secondaryColor,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PartyChatPage(
                        partyId: widget.partyId,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat, color: configProvider.iconColor),
                    const SizedBox(width: 8),
                    Text(
                      'Abrir Chat',
                      style: TextStyle(color: configProvider.iconColor),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            if (!canViewSensitive &&
                _partyData!['ownerId'] != widget.userId &&
                _partyData!['userRole'] == 'Disponível para Participar')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: configProvider.secondaryColor,
                ),
                onPressed: _requestParticipation,
                child: _loadingRequest
                    ? const CircularProgressIndicator()
                    : const Text('Solicitar Participação'),
              ),

            if (canViewSensitive)
              FutureBuilder(
                future: ApiService.getAllParticipants(
                  widget.partyId,
                  widget.userId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.data == null) {
                    return Text(
                      "Erro ao carregar participantes",
                      style: TextStyle(color: configProvider.textColor),
                    );
                  }
                  final data = snapshot.data!;
                  final confirmeds =
                  data['confirmeds'] as List<dynamic>?;
                  final inviteds = data['inviteds'] as List<dynamic>?;

                  return Column(
                    children: [
                      _buildUserList(
                        title: "Confirmados",
                        users: confirmeds,
                        isPending: false,
                      ),
                      if (_partyData!['ownerId'] == widget.userId)
                        _buildUserList(
                          title: "Convidados (Pendentes)",
                          users: inviteds,
                          isPending: true,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}