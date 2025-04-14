import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/places/place_details_page.dart';
import 'package:snarf/pages/places/create_edit_place_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({Key? key}) : super(key: key);

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  bool _isLoading = false;
  List<dynamic> _places = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    _fetchAllPlaces();
    SignalRManager().listenToEvent('ReceiveMessage', _handleSignalRMessage);
  }

  Future<void> _fetchAllPlaces() async {
    userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showErrorSnackbar(context, 'Usuário não logado');
      return;
    }
    setState(() => _isLoading = true);
    final data = await ApiService.getAllPlaces();
    setState(() => _isLoading = false);
    if (data == null) {
      showErrorSnackbar(context, 'Erro ao buscar locais');
      return;
    }
    _places = data['data'] ?? [];
    setState(() {});
  }

  void _handleSignalRMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);
      final SignalREventType type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == message['Type'],
        orElse: () => SignalREventType.UserDisconnected,
      );
      if (type == SignalREventType.PlaceChatReceiveMessage ||
          type == SignalREventType.PlaceChatReceiveMessageDeleted) {}
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  Future<void> _deletePlace(String placeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Lugar'),
        content: const Text('Tem certeza que deseja excluir este lugar?'),
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
    final success = await ApiService.deletePlace(placeId);
    if (success) {
      showSuccessSnackbar(context, 'Lugar excluído com sucesso!');
      _fetchAllPlaces();
    } else {
      showErrorSnackbar(context, 'Erro ao excluir lugar');
    }
  }

  Future<void> _signalToRemovePlace(String placeId) async {
    final success = await ApiService.signalToRemovePlace(placeId);
    if (success) {
      showSuccessSnackbar(context, 'Lugar sinalizado para remoção');
    } else {
      showErrorSnackbar(context, 'Erro ao sinalizar remoção');
    }
  }

  Widget _buildPlaceItem(dynamic place) {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    final placeId = place['id'].toString();
    final title = place['title'] ?? '';
    final imageUrl = place['coverImageUrl'] as String? ?? '';
    final ownerId = place['ownerId'] ?? '';
    return Card(
      color: config.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        leading: (imageUrl.isNotEmpty)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl,
                    width: 50, height: 50, fit: BoxFit.cover),
              )
            : Icon(Icons.location_on, color: config.iconColor),
        title: Text(
          title,
          style:
              TextStyle(color: config.textColor, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaceDetailsPage(placeId: placeId),
            ),
          );
        },
        trailing: (ownerId == userId)
            ? PopupMenuButton<String>(
                color: config.primaryColor,
                icon: Icon(Icons.more_vert, color: config.iconColor),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateEditPlacePage(placeId: placeId),
                      ),
                    ).then((updated) {
                      if (updated == true) _fetchAllPlaces();
                    });
                  } else if (value == 'delete') {
                    _deletePlace(placeId);
                  } else if (value == 'signal') {
                    _signalToRemovePlace(placeId);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar',
                        style: TextStyle(color: config.textColor)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir',
                        style: TextStyle(color: config.textColor)),
                  ),
                  PopupMenuItem(
                    value: 'signal',
                    child: Text('Sinalizar Remoção',
                        style: TextStyle(color: config.textColor)),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    return Stack(
      children: [
        if (_isLoading)
          Center(child: CircularProgressIndicator(color: config.iconColor))
        else if (_places.isEmpty)
          Center(
            child: Text(
              "Nenhum local encontrado",
              style: TextStyle(color: config.textColor, fontSize: 16),
            ),
          )
        else
          ListView.builder(
            itemCount: _places.length,
            itemBuilder: (ctx, index) => _buildPlaceItem(_places[index]),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: config.secondaryColor,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateEditPlacePage()),
              );
              if (result == true) {
                _fetchAllPlaces();
              }
            },
            child: Icon(Icons.add, color: config.iconColor),
          ),
        )
      ],
    );
  }
}