import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/location_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class CreateEditPlacePage extends StatefulWidget {
  final String? placeId;

  const CreateEditPlacePage({Key? key, this.placeId}) : super(key: key);

  @override
  State<CreateEditPlacePage> createState() => _CreateEditPlacePageState();
}

class _CreateEditPlacePageState extends State<CreateEditPlacePage> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  double? _latitude;
  double? _longitude;

  File? _imageFile;
  String? _base64Image;
  bool _isLoading = false;

  late Position _location;

  int _selectedType = 0;

  final List<Map<String, dynamic>> _placeTypes = [
    {'value': 0, 'label': 'Academia'},
    {'value': 1, 'label': 'Banheiro'},
    {'value': 2, 'label': 'Bar/Clube'},
    {'value': 3, 'label': 'Café/Restaurante'},
    {'value': 4, 'label': 'Duchas/Sauna'},
    {'value': 5, 'label': 'Evento Recorrente'},
    {'value': 6, 'label': 'Fliperama/Teatro'},
    {'value': 7, 'label': 'Hotel/Resort'},
    {'value': 8, 'label': 'Outro'},
    {'value': 9, 'label': 'Parada de Caminhões'},
    {'value': 10, 'label': 'Parque'},
    {'value': 11, 'label': 'Praia de Nudismo'},
    {'value': 12, 'label': 'Sauna'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();

    if (widget.placeId != null) {
      _loadPlace(widget.placeId!);
    }

    _obterLocalizacao();
  }

  Future<void> _loadPlace(String placeId) async {
    setState(() => _isLoading = true);
    final data = await ApiService.getPlaceDetails(placeId);
    setState(() => _isLoading = false);

    if (data == null) {
      showErrorSnackbar(context, 'Erro ao carregar informações do local');
      Navigator.pop(context);
      return;
    }
    setState(() {
      _titleController.text = data['title'] ?? '';
      _descController.text = data['description'] ?? '';
      _latitude = data['latitude']?.toDouble() ?? 0.0;
      _longitude = data['longitude']?.toDouble() ?? 0.0;
      _selectedType = data['type'] ?? 0;
    });
  }

  Future<void> _obterLocalizacao() async {
    final ok = await _locationService.initialize();
    if (ok) {
      final loc = await _locationService.getCurrentLocation();
      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
      });
      _locationService.onLocationChanged.listen((loc) {
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
        });
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    _imageFile = File(pickedFile.path);
    final bytes = await _imageFile!.readAsBytes();
    _base64Image = base64Encode(bytes);
    setState(() {});
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showErrorSnackbar(context, 'Usuário não logado');
      return;
    }

    setState(() => _isLoading = true);

    if (widget.placeId == null) {
      final created = await ApiService.createPlace(
        title: _titleController.text,
        description: _descController.text,
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        coverImageBase64: _base64Image ?? '',
        type: _selectedType,
      );
      setState(() => _isLoading = false);
      if (created) {
        Navigator.pop(context, true);
      } else {
        showErrorSnackbar(context, 'Erro ao criar local');
      }
      return;
    }

    final updated = await ApiService.updatePlace(
      placeId: widget.placeId!,
      title: _titleController.text,
      description: _descController.text,
      latitude: _latitude ?? 0.0,
      longitude: _longitude ?? 0.0,
      coverImageBase64: _base64Image,
      type: _selectedType,
    );
    setState(() => _isLoading = false);
    if (updated) {
      Navigator.pop(context, true);
    } else {
      showErrorSnackbar(context, 'Erro ao atualizar local');
    }
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
          widget.placeId == null ? 'Criar Local' : 'Editar Local',
          style: TextStyle(color: config.textColor),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: config.iconColor))
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Column(
                        children: [
                          _imageFile == null
                              ? Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color:
                                        config.secondaryColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.camera_alt,
                                      size: 40, color: config.iconColor),
                                )
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundImage: FileImage(_imageFile!),
                                ),
                          const SizedBox(height: 8),
                          Text(
                            _imageFile == null
                                ? 'Adicionar Imagem'
                                : 'Alterar Imagem',
                            style: TextStyle(color: config.textColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ex: Banheiro do Shopping X',
                        prefixIcon: Icon(Icons.title, color: config.iconColor),
                        labelStyle: TextStyle(color: config.textColor),
                        hintStyle: TextStyle(
                          color: config.textColor.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: config.secondaryColor.withOpacity(0.1),
                      ),
                      style: TextStyle(color: config.textColor),
                      textInputAction: TextInputAction.next,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Informe o título'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Descreva este lugar',
                        prefixIcon:
                            Icon(Icons.description, color: config.iconColor),
                        labelStyle: TextStyle(color: config.textColor),
                        hintStyle:
                            TextStyle(color: config.textColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: config.secondaryColor.withOpacity(0.1),
                      ),
                      maxLines: 3,
                      style: TextStyle(color: config.textColor),
                      textInputAction: TextInputAction.next,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Informe a descrição'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: config.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selecione o tipo de local:",
                            style: TextStyle(
                              color: config.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._placeTypes.map((pt) {
                            return RadioListTile<int>(
                              title: Text(
                                pt['label'] as String,
                                style: TextStyle(color: config.textColor),
                              ),
                              activeColor: config.iconColor,
                              value: pt['value'] as int,
                              groupValue: _selectedType,
                              onChanged: (val) {
                                setState(() {
                                  _selectedType = val ?? 0;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _onSave,
                      child: Text(
                        widget.placeId == null
                            ? 'Criar Local'
                            : 'Salvar Alterações',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
