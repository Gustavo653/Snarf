import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/parties/create_edit_party_page.dart';
import 'package:snarf/pages/parties/party_details_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  bool _isLoading = false;
  List<dynamic> _parties = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    _fetchAllParties();
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

  Future<void> _inviteUserDialog(String partyId) async {
    final controller = TextEditingController();
    final userIdToInvite = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convidar usuário'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'ID do usuário'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Convidar'),
          ),
        ],
      ),
    );
    if (userIdToInvite == null || userIdToInvite.isEmpty) return;

    final success = await ApiService.requestPartyParticipation(
      partyId: partyId,
      userId: userIdToInvite,
    );
    if (success) {
      showSuccessSnackbar(context, 'Convite enviado');
    } else {
      showErrorSnackbar(context, 'Erro ao convidar usuário');
    }
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

  Future<void> _editParty(Map<String, dynamic> party) async {
    final partyId = party['id'].toString();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEditPartyPage(partyId: partyId),
      ),
    );
    if (result == true) {
      _fetchAllParties();
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
    final partyId = party["id"].toString();
    final title = party["title"] ?? '';
    final userRole = party["userRole"] ?? '';

    return Card(
      child: ListTile(
          leading: (party["imageUrl"] != null &&
                  party["imageUrl"].toString().isNotEmpty)
              ? Image.network(party["imageUrl"],
                  width: 50, height: 50, fit: BoxFit.cover)
              : const Icon(Icons.event),
          title: Text(title),
          subtitle: Text(userRole),
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
          }),
    );
  }

  Widget _buildTrailingActions(dynamic party) {
    final partyId = party["id"].toString();
    final userRole = party["userRole"] ?? '';

    switch (userRole) {
      case 'Hospedando':
        return PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'invite') {
              _inviteUserDialog(partyId);
            } else if (value == 'delete') {
              _deleteParty(partyId);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'invite', child: Text('Convidar Usuário')),
            const PopupMenuItem(value: 'delete', child: Text('Excluir Festa')),
          ],
        );

      case 'Convidado':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Aceitar',
              onPressed: () => _acceptInvite(partyId),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Recusar',
              onPressed: () => _declineInvite(partyId),
            ),
          ],
        );

      case 'Solicitante':
        return IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancelar solicitação',
          onPressed: () => _declineInvite(partyId),
        );

      case 'Confirmado':
        return IconButton(
          icon: const Icon(Icons.exit_to_app),
          tooltip: 'Sair da festa',
          onPressed: () => _declineInvite(partyId),
        );

      case 'Disponível para Participar':
      default:
        return TextButton(
          onPressed: () => _requestParticipation(partyId),
          child: const Text('Participar'),
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
                      builder: (_) => const CreateEditPartyPage()),
                );
                if (result == true) {
                  _fetchAllParties();
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
