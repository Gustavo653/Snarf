import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

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
    if (data != null) {
      setState(() {
        _partyData = data;
        _isLoading = false;
      });
    } else {
      showErrorSnackbar(context, 'Não foi possível carregar detalhes da festa');
      Navigator.pop(context);
    }
  }

  Future<void> _requestParticipation() async {
    if (_loadingRequest) return;
    setState(() {
      _loadingRequest = true;
    });
    final result = await ApiService.requestPartyParticipation(
      partyId: widget.partyId,
      userId: widget.userId,
    );
    setState(() {
      _loadingRequest = false;
    });
    if (result == true) {
      await _loadPartyDetails();
      showSuccessSnackbar(context, 'Solicitação enviada');
    } else {
      showErrorSnackbar(context, 'Erro ao solicitar participação');
    }
  }

  Future<void> _confirmParticipation(String userId) async {
    if (_loadingConfirmation) return;
    setState(() {
      _loadingConfirmation = true;
    });
    final result = await ApiService.confirmUser(widget.partyId, userId);
    setState(() {
      _loadingConfirmation = false;
    });
    if (result == true) {
      await _loadPartyDetails();
      showSuccessSnackbar(context, 'Convite confirmado');
    } else {
      showErrorSnackbar(context, 'Erro ao confirmar');
    }
  }

  Future<void> _declineParticipation(String userId) async {
    if (_loadingDecline) return;
    setState(() {
      _loadingDecline = true;
    });
    final result = await ApiService.declineUser(widget.partyId, userId);
    setState(() {
      _loadingDecline = false;
    });
    if (result == true) {
      await _loadPartyDetails();
      showSuccessSnackbar(context, 'Convite recusado');
    } else {
      showErrorSnackbar(context, 'Erro ao recusar');
    }
  }

  Future<void> _deleteParty() async {
    final result = await ApiService.deleteParty(widget.partyId, widget.userId);
    if (result == true) {
      Navigator.pop(context);
    } else {
      showErrorSnackbar(context, 'Erro ao excluir festa');
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
              _partyData!['OwnerId'] == widget.userId)
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: configProvider.iconColor),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteParty();
                }
              },
              itemBuilder: (context) => [
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
              child: CircularProgressIndicator(color: configProvider.iconColor))
          : _partyData == null
              ? Center(
                  child: Text('Festa não encontrada',
                      style: TextStyle(color: configProvider.textColor)))
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
                          'Tipo: ${_partyData!['type']}',
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
                        if (_partyData!['OwnerId'] == widget.userId)
                          Text(
                            'Gerenciar Convites',
                            style: TextStyle(
                              fontSize: 16,
                              color: configProvider.textColor,
                            ),
                          ),
                        if (_partyData!['OwnerId'] != widget.userId &&
                            _partyData!['userRole'] ==
                                'Disponível para Participar')
                          ElevatedButton(
                            onPressed: _requestParticipation,
                            child: _loadingRequest
                                ? const CircularProgressIndicator()
                                : const Text('Solicitar Participação'),
                          ),
                        if (_partyData!['OwnerId'] == widget.userId)
                          FutureBuilder(
                            future: ApiService.getAllParticipants(
                                widget.partyId, widget.userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              if (snapshot.data == null) {
                                return const SizedBox.shrink();
                              }
                              final data = snapshot.data!;
                              final inviteds = data['Inviteds'];
                              final confirmeds = data['Confirmeds'];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pendentes:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: configProvider.textColor,
                                    ),
                                  ),
                                  for (var i in inviteds)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          i['name'],
                                          style: TextStyle(
                                              color: configProvider.textColor),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                _confirmParticipation(i['id']);
                                              },
                                              icon: _loadingConfirmation
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(),
                                                    )
                                                  : const Icon(Icons.check),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                _declineParticipation(i['id']);
                                              },
                                              icon: _loadingDecline
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(),
                                                    )
                                                  : const Icon(Icons.close),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Confirmados:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: configProvider.textColor,
                                    ),
                                  ),
                                  for (var c in confirmeds)
                                    Row(
                                      children: [
                                        Text(
                                          c['name'],
                                          style: TextStyle(
                                              color: configProvider.textColor),
                                        ),
                                      ],
                                    ),
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