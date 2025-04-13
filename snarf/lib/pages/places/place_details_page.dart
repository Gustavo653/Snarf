import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/places/place_chat_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class PlaceDetailsPage extends StatefulWidget {
  final String placeId;

  const PlaceDetailsPage({Key? key, required this.placeId}) : super(key: key);

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  Map<String, dynamic>? _placeData;
  bool _isLoading = true;

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
                              Divider(),
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
                    ],
                  ),
                ),
    );
  }
}
