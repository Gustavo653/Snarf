import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class CreateEditPartyPage extends StatefulWidget {
  final String? partyId;

  const CreateEditPartyPage({
    super.key,
    this.partyId,
  });

  @override
  State<CreateEditPartyPage> createState() => _CreateEditPartyPageState();
}

class _CreateEditPartyPageState extends State<CreateEditPartyPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _instructionsController;
  late DateTime _selectedDate;
  late int _duration;
  late int _type;

  String? _base64Image;
  File? _imageFile;

  final List<Map<String, dynamic>> _partyTypes = [
    {"value": 0, "label": "Orgia"},
    {"value": 1, "label": "Bomba e Despejo"},
    {"value": 2, "label": "Masturbação Coletiva"},
    {"value": 3, "label": "Grupo de Bukkake"},
    {"value": 4, "label": "Grupo Fetiche"},
    {"value": 5, "label": "Evento Especial"},
  ];

  late Location _location;
  double? _latitude;
  double? _longitude;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController();
    _descController = TextEditingController();
    _locationController = TextEditingController();
    _instructionsController = TextEditingController();
    _selectedDate = DateTime.now();
    _duration = 60;
    _type = 0;

    if (widget.partyId != null) {
      _fetchPartyData(widget.partyId!);
    }

    _obterLocalizacao();
  }

  Future<void> _fetchPartyData(String partyId) async {
    final userId = await ApiService.getUserIdFromToken();

    setState(() => _isLoading = true);

    final partyData =
        await ApiService.getPartyDetails(partyId: partyId, userId: userId!);
    setState(() => _isLoading = false);

    if (partyData == null) {
      showErrorSnackbar(context, "Erro ao carregar dados da festa.");
      return;
    }

    setState(() {
      _titleController.text = partyData["title"] ?? "";
      _descController.text = partyData["description"] ?? "";
      _locationController.text = partyData["location"] ?? "";
      _instructionsController.text = partyData["instructions"] ?? "";

      final startDateStr = partyData["startDate"];
      if (startDateStr != null) {
        _selectedDate = DateTime.tryParse(startDateStr) ?? DateTime.now();
      }

      _duration = partyData["duration"] ?? 60;
      _type = partyData["type"] ?? 0;
    });
  }

  Future<void> _obterLocalizacao() async {
    _location = Location();

    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        showErrorSnackbar(context, "Precisamos que seu GPS esteja ligado.");
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        showErrorSnackbar(context, "Precisamos da permissão de localização.");
        return;
      }
    }

    try {
      final locationData = await _location.getLocation();
      setState(() {
        _latitude = locationData.latitude;
        _longitude = locationData.longitude;
      });
    } catch (e) {
      showErrorSnackbar(context, "Erro ao obter localização: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _imageFile = File(pickedFile.path);
      final bytes = await _imageFile!.readAsBytes();
      _base64Image = base64Encode(bytes);
      setState(() {});
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showErrorSnackbar(context, 'Token inválido');
      return;
    }

    final email = await _getUserEmail(userId);
    if (email == null) {
      showErrorSnackbar(context, 'Email não encontrado');
      return;
    }

    if (widget.partyId == null) {
      final result = await ApiService.createParty(
        email: email,
        title: _titleController.text,
        description: _descController.text,
        startDate: _selectedDate,
        duration: _duration,
        type: _type,
        location: _locationController.text,
        instructions: _instructionsController.text,
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        coverImageBase64: _base64Image ?? '',
      );
      if (result != null) {
        Navigator.pop(context, true);
      } else {
        showErrorSnackbar(context, 'Erro ao criar festa');
      }
      return;
    }

    final result = await ApiService.updateParty(
      partyId: widget.partyId!,
      title: _titleController.text,
      description: _descController.text,
      location: _locationController.text,
      instructions: _instructionsController.text,
      startDate: _selectedDate,
      duration: _duration,
    );
    if (result != null) {
      Navigator.pop(context, true);
    } else {
      showErrorSnackbar(context, 'Erro ao atualizar festa');
    }
  }

  Future<String?> _getUserEmail(String userId) async {
    final userData = await ApiService.getUserInfoById(userId);
    if (userData == null) return null;
    return userData['email'];
  }

  Future<void> _selectDateTime() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: _selectedDate.hour, minute: _selectedDate.minute),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            selected.year,
            selected.month,
            selected.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: configProvider.primaryColor,
      appBar: AppBar(
        backgroundColor: configProvider.primaryColor,
        title: Text(
          widget.partyId == null ? 'Criar Festa' : 'Editar Festa',
          style: TextStyle(color: configProvider.textColor),
        ),
        iconTheme: IconThemeData(color: configProvider.iconColor),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: configProvider.iconColor,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
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
                                    height: 120,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: configProvider.secondaryColor
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: configProvider.iconColor,
                                    ),
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
                              style: TextStyle(color: configProvider.textColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Título',
                          hintText: 'Ex: Bomba e Despejo no Sítio do Juca',
                          prefixIcon: Icon(
                            Icons.title,
                            color: configProvider.iconColor,
                          ),
                          labelStyle:
                              TextStyle(color: configProvider.textColor),
                          hintStyle: TextStyle(
                              color: configProvider.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor:
                              configProvider.secondaryColor.withOpacity(0.1),
                        ),
                        style: TextStyle(color: configProvider.textColor),
                        textInputAction: TextInputAction.next,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Informe o título'
                            : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: 'Descrição',
                          hintText: 'Descreva o evento',
                          prefixIcon: Icon(
                            Icons.description,
                            color: configProvider.iconColor,
                          ),
                          labelStyle:
                              TextStyle(color: configProvider.textColor),
                          hintStyle: TextStyle(
                              color: configProvider.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor:
                              configProvider.secondaryColor.withOpacity(0.1),
                        ),
                        maxLines: 3,
                        style: TextStyle(color: configProvider.textColor),
                        textInputAction: TextInputAction.next,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Informe a descrição'
                            : null,
                      ),
                      const SizedBox(height: 10),

                      GestureDetector(
                        onTap: _selectDateTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color:
                                configProvider.secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: configProvider.iconColor),
                              const SizedBox(width: 10),
                              Text(
                                'Data e Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate)}',
                                style:
                                    TextStyle(color: configProvider.textColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Local',
                          hintText: 'Ex: Endereço ou nome do lugar',
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: configProvider.iconColor,
                          ),
                          labelStyle:
                              TextStyle(color: configProvider.textColor),
                          hintStyle: TextStyle(
                              color: configProvider.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor:
                              configProvider.secondaryColor.withOpacity(0.1),
                        ),
                        style: TextStyle(color: configProvider.textColor),
                        textInputAction: TextInputAction.next,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Informe o local'
                            : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _instructionsController,
                        decoration: InputDecoration(
                          labelText: 'Instruções',
                          hintText: 'Ex: Levar toalha, bebida, etc.',
                          prefixIcon: Icon(
                            Icons.list,
                            color: configProvider.iconColor,
                          ),
                          labelStyle:
                              TextStyle(color: configProvider.textColor),
                          hintStyle: TextStyle(
                              color: configProvider.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor:
                              configProvider.secondaryColor.withOpacity(0.1),
                        ),
                        maxLines: 3,
                        style: TextStyle(color: configProvider.textColor),
                        textInputAction: TextInputAction.next,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Informe as instruções'
                            : null,
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        initialValue: _duration.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duração (min)',
                          hintText: 'Ex: 120',
                          prefixIcon: Icon(
                            Icons.access_time,
                            color: configProvider.iconColor,
                          ),
                          labelStyle:
                              TextStyle(color: configProvider.textColor),
                          hintStyle: TextStyle(
                              color: configProvider.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor:
                              configProvider.secondaryColor.withOpacity(0.1),
                        ),
                        style: TextStyle(color: configProvider.textColor),
                        textInputAction: TextInputAction.next,
                        onChanged: (val) {
                          if (val.isNotEmpty) {
                            _duration = int.tryParse(val) ?? 60;
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<int>(
                        value: _type,
                        items: _partyTypes
                            .map(
                              (pt) => DropdownMenuItem<int>(
                                value: pt["value"],
                                child: Text(
                                  pt["label"],
                                  style: TextStyle(
                                      color: configProvider.textColor),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _type = val;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Tipo de Festa',
                          labelStyle:
                              TextStyle(color: configProvider.textColor),
                          filled: true,
                          fillColor:
                              configProvider.secondaryColor.withOpacity(0.1),
                        ),
                        style: TextStyle(color: configProvider.textColor),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _onSave,
                        child: Text(
                          widget.partyId == null
                              ? 'Criar Festa'
                              : 'Salvar Alterações',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}