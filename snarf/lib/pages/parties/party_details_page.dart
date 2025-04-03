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

  @override
  void initState() {
    super.initState();
    _loadPartyDetails();
  }

  Future<void> _loadPartyDetails() async {
    final data = await ApiService.getPartyDetails(
        partyId: widget.partyId, userId: widget.userId);
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

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        title: const Text('Detalhes da Festa'),
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
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
                              fontSize: 20, color: configProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _partyData!['description'] ?? '',
                          style: TextStyle(
                              fontSize: 16, color: configProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Local: ${_partyData!['location']}',
                          style: TextStyle(
                              fontSize: 16, color: configProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Instruções: ${_partyData!['instructions']}',
                          style: TextStyle(
                              fontSize: 16, color: configProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Papel: ${_partyData!['userRole']}',
                          style: TextStyle(
                              fontSize: 16, color: configProvider.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Convidados: ${_partyData!['invitedCount']}',
                          style: TextStyle(
                              fontSize: 16, color: configProvider.textColor),
                        ),
                        Text(
                          'Confirmados: ${_partyData!['confirmedCount']}',
                          style: TextStyle(
                              fontSize: 16, color: configProvider.textColor),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }
}
