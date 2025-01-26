import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class EditUserPage extends StatefulWidget {
  const EditUserPage({super.key});

  @override
  _EditUserPageState createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _userId;
  String? _userImageUrl;
  bool _isLoading = true;
  File? _pickedFile;
  final String _defaultImagePath = 'assets/images/user_anonymous.png';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedFile = File(pickedFile.path);
        _userImageUrl = null;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await ApiService.getUserInfo();
    if (userInfo != null) {
      setState(() {
        _nameController.text = userInfo['name'];
        _emailController.text = userInfo['email'];
        _userId = userInfo['id'];
        _userImageUrl = userInfo['imageUrl'];
        _isLoading = false;
      });
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');
    }
  }

  Future<void> _saveChanges() async {
    if (_userId == null) return;

    String? base64Image;
    if (_pickedFile != null) {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _pickedFile!.absolute.path,
        quality: 50,
      );

      if (compressedImage != null) {
        base64Image = base64Encode(compressedImage);
      }
    }

    final result = await ApiService.editUser(
      _userId!,
      _nameController.text,
      _emailController.text,
      _passwordController.text.isEmpty ? null : _passwordController.text,
      base64Image,
    );

    if (result == null) {
      showSnackbar(context, 'Usuário atualizado com sucesso',
          color: Colors.green);
      Navigator.of(context).pop();
    } else {
      showSnackbar(context, result);
    }
  }

  void _deleteImage() {
    setState(() {
      _pickedFile = File(_defaultImagePath);
      _userImageUrl = null;
    });
  }

  Future<void> _deleteAccount() async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
              'Tem certeza de que deseja excluir sua conta? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final result = await ApiService.deleteUser(_userId!);

      if (result == null) {
        showSnackbar(context, 'Usuário deletado com sucesso');
        Navigator.pop(context);
      } else {
        showSnackbar(context, result);
      }
    }
  }

  Widget _buildUserImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
        image: _userImageUrl != null
            ? DecorationImage(
                image: NetworkImage(_userImageUrl!),
                fit: BoxFit.cover,
              )
            : _pickedFile != null
                ? DecorationImage(
                    image: FileImage(_pickedFile!),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage('assets/images/user_anonymous.png'),
                    fit: BoxFit.cover,
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuário'),
        actions: [
          ThemeToggle(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildUserImage(),
                    const SizedBox(height: 10),
                    if (_pickedFile != null || _userImageUrl != null)
                      TextButton.icon(
                        onPressed: _deleteImage,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Remover Foto',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Senha (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(
                        Icons.photo_camera,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Upload Foto',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(
                        Icons.save,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Salvar Alterações',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Deletar Conta',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
