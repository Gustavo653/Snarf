import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/places/place_chat_page.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class PlaceDetailsPage extends StatefulWidget {
  final String placeId;

  const PlaceDetailsPage({super.key, required this.placeId});

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  Map<String, dynamic>? _placeData;
  bool _isLoading = true;

  Map<String, dynamic>? _visitorsData;
  bool _isLoadingVisitors = true;

  @override
  void initState() {
    super.initState();
    _loadPlaceDetails();
  }

  Future<void> _loadPlaceDetails() async {
    final data = await ApiService.getPlaceDetails(widget.placeId);
    if (!mounted) return;

    if (data == null) {
      showErrorSnackbar(context, 'Não foi possível carregar detalhes do lugar');
      Navigator.pop(context);
      return;
    }

    setState(() {
      _placeData = data;
      _isLoading = false;
    });

    _loadVisitorsAndStats();
  }

  Future<void> _loadVisitorsAndStats() async {
    setState(() => _isLoadingVisitors = true);

    final result = await ApiService.getPlaceVisitorsAndStats(widget.placeId);
    if (!mounted) return;

    setState(() {
      _visitorsData = result!['object'];
      _isLoadingVisitors = false;
    });
  }

  Future<void> _signalRemovePlace() async {
    final bool confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sinalizar para Remoção'),
            content: const Text(
                'Tem certeza que deseja sinalizar este lugar para remoção?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    final success = await ApiService.signalToRemovePlace(widget.placeId);
    if (!mounted) return;

    if (success) {
      showSuccessSnackbar(
          context, 'Lugar sinalizado para remoção com sucesso!');
    } else {
      showErrorSnackbar(context, 'Falha ao sinalizar para remoção.');
    }
  }

  String _mapPlaceType(int type) {
    switch (type) {
      case 0:
        return 'Academia';
      case 1:
        return 'Banheiro';
      case 2:
        return 'Bar/Clube';
      case 3:
        return 'Café/Restaurante';
      case 4:
        return 'Duchas/Sauna';
      case 5:
        return 'Evento Recorrente';
      case 6:
        return 'Fliperama/Teatro';
      case 7:
        return 'Hotel/Resort';
      case 8:
        return 'Outro';
      case 9:
        return 'Parada de Caminhões';
      case 10:
        return 'Parque';
      case 11:
        return 'Praia de Nudismo';
      case 12:
        return 'Sauna';
      default:
        return 'Desconhecido';
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

  Widget _buildVisitorsList({
    required List<dynamic> visitors,
    required ConfigProvider config,
  }) {
    if (visitors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: config.secondaryColor,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Usuários no Local",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: config.textColor,
                fontSize: 16,
              ),
            ),
            const Divider(),
            ...visitors.map((u) {
              final userId = u['id']?.toString() ?? '';
              final userName = u['name'] ?? 'Sem nome';
              final userImage = u['imageUrl'] ?? '';

              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewUserPage(userId: userId),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundImage:
                      (userImage.isNotEmpty) ? NetworkImage(userImage) : null,
                  child: (userImage.isEmpty)
                      ? Icon(Icons.person, color: config.iconColor)
                      : null,
                ),
                title: Text(
                  userName,
                  style: TextStyle(color: config.textColor),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceStats(ConfigProvider config) {
    if (_visitorsData == null) return const SizedBox.shrink();

    final avg = _visitorsData!['averageStayMinutes'] ?? 0.0;
    final last7 = _visitorsData!['visitsLast7Days'] ?? 0;

    return Card(
      color: config.secondaryColor,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Estatísticas do Local",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: config.textColor,
                fontSize: 16,
              ),
            ),
            const Divider(),
            _buildInfoRow(
              icon: Icons.timer,
              label: 'Média de Permanência: ${avg.toStringAsFixed(1)} min',
              config: config,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.bar_chart,
              label: 'Visitas (últimos 7 dias): $last7',
              config: config,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: config.primaryColor,
      appBar: AppBar(
        backgroundColor: config.primaryColor,
        iconTheme: IconThemeData(color: config.iconColor),
        title: Text(
          'Detalhes do Lugar',
          style: TextStyle(color: config.textColor),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: config.iconColor),
            )
          : _placeData == null
              ? Center(
                  child: Text(
                    'Lugar não encontrado',
                    style: TextStyle(color: config.textColor),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_placeData!['coverImageUrl'] != null &&
                          _placeData!['coverImageUrl'].toString().isNotEmpty &&
                          !config.hideImages)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(_placeData!['coverImageUrl']),
                        ),
                      const SizedBox(height: 16),
                      Card(
                        color: config.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _placeData!['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: config.textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _placeData!['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: config.textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              if (_placeData!.containsKey('type'))
                                _buildInfoRow(
                                  icon: Icons.info_outline,
                                  label:
                                      'Tipo: ${_mapPlaceType(_placeData!['type'])}',
                                  config: config,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.secondaryColor,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaceChatPage(placeId: widget.placeId),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: config.iconColor),
                            const SizedBox(width: 8),
                            Text(
                              'Abrir Chat',
                              style: TextStyle(color: config.iconColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.secondaryColor,
                        ),
                        onPressed: _signalRemovePlace,
                        icon:
                            Icon(Icons.delete_outline, color: config.iconColor),
                        label: Text(
                          'Sinalizar para Remoção',
                          style: TextStyle(color: config.iconColor),
                        ),
                      ),
                      if (_isLoadingVisitors)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: config.iconColor,
                          ),
                        )
                      else ...[
                        if (_visitorsData != null &&
                            _visitorsData!['currentVisitors'] != null)
                          _buildVisitorsList(
                            visitors: List<Map<String, dynamic>>.from(
                              _visitorsData!['currentVisitors'] as List,
                            ),
                            config: config,
                          ),
                        if (_visitorsData != null) _buildPlaceStats(config),
                      ],
                    ],
                  ),
                ),
    );
  }
}
