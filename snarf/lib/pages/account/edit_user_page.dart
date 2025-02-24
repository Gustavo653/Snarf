import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/providers/intercepted_image_provider.dart';
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
  int favoritedByCount = 0;
  int blockedByCount = 0;
  bool _isLoading = true;

  File? _pickedFile;
  final String _defaultImagePath = 'assets/images/user_anonymous.png';

  List<dynamic> _blockedUsers = [];

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
    final userId = await ApiService.getUserIdFromToken();
    final userInfo = await ApiService.getUserInfoById(userId!);

    if (userInfo != null) {
      setState(() {
        _nameController.text = userInfo['name'];
        _emailController.text = userInfo['email'];
        _userId = userInfo['id'];
        _userImageUrl = userInfo['imageUrl'];
        _blockedUsers = userInfo['blockedUsers'] ?? [];
        blockedByCount = userInfo['blockedBy'] ?? 0;
        favoritedByCount = userInfo['favoritedBy'] ?? 0;
        _isLoading = false;
      });
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');
    }
  }

  Future<String?> _getBase64Image() async {
    if (_pickedFile != null) {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _pickedFile!.absolute.path,
        quality: 50,
      );
      if (compressedImage == null) return null;
      return base64Encode(compressedImage);
    } else {
      final byteData = await rootBundle.load(_defaultImagePath);
      final imageBytes = byteData.buffer.asUint8List();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: 50,
      );
      return base64Encode(compressedBytes);
    }
  }

  Future<void> _saveChanges() async {
    if (_userId == null) return;

    final base64Image = await _getBase64Image();
    if (base64Image == null) {
      showSnackbar(context, 'Não foi possível gerar a imagem em Base64');
      return;
    }

    final result = await ApiService.editUser(
      _userId!,
      _nameController.text,
      _emailController.text,
      _passwordController.text.isEmpty ? null : _passwordController.text,
      base64Image,
    );

    if (result == null) {
      showSnackbar(
        context,
        'Usuário atualizado com sucesso',
        color: Colors.green,
      );
      Navigator.of(context).pop();
    } else {
      showSnackbar(context, result);
    }
  }

  void _deleteImage() {
    setState(() {
      _pickedFile = null;
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

  Future<void> _unblockUser(String blockedUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Desbloqueio'),
          content:
              const Text('Tem certeza de que deseja desbloquear este usuário?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Desbloquear'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final result = await ApiService.unblockUser(blockedUserId);
      if (result == null) {
        showSnackbar(context, 'Usuário desbloqueado com sucesso',
            color: Colors.green);
        _loadUserInfo();
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
        image: (_pickedFile != null)
            ? DecorationImage(
                image: FileImage(_pickedFile!),
                fit: BoxFit.cover,
              )
            : (_userImageUrl != null)
                ? DecorationImage(
                    image: InterceptedImageProvider(
                      originalProvider: NetworkImage(_userImageUrl!),
                      hideImages: false,
                    ),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage('assets/images/user_anonymous.png'),
                    fit: BoxFit.cover,
                  ),
      ),
    );
  }

  Widget _buildUserList(String title, List<dynamic> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (user['imageUrl'] != null)
                    ? InterceptedImageProvider(
                        originalProvider: NetworkImage(user['imageUrl']),
                        hideImages: false,
                      )
                    : const AssetImage('assets/images/user_anonymous.png')
                        as ImageProvider,
              ),
              title: Text(user['name'] ?? 'Usuário'),
              trailing: IconButton(
                icon: const Icon(Icons.lock_open, color: Colors.green),
                onPressed: () => _unblockUser(user['id']),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCounters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            const Text('Favoritado por'),
            Text(
              '$favoritedByCount',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
        Column(
          children: [
            const Text('Bloqueado por'),
            Text(
              '$blockedByCount',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImage,
          style: ElevatedButton.styleFrom(
              backgroundColor: configProvider.secondaryColor),
          icon: Icon(Icons.photo_camera, color: configProvider.iconColor),
          label: Text(
            'Upload',
            style: TextStyle(color: configProvider.textColor),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
              backgroundColor: configProvider.secondaryColor),
          icon: Icon(Icons.save, color: configProvider.iconColor),
          label: Text(
            'Salvar',
            style: TextStyle(color: configProvider.textColor),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _deleteAccount,
          style: ElevatedButton.styleFrom(
              backgroundColor: configProvider.secondaryColor),
          icon: Icon(Icons.delete_forever, color: configProvider.iconColor),
          label: Text(
            'Excluir',
            style: TextStyle(color: configProvider.textColor),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuário'),
        backgroundColor: configProvider.primaryColor,
      ),
      backgroundColor: configProvider.primaryColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildUserImage(),
                    const SizedBox(height: 10),
                    if (_pickedFile != null || _userImageUrl != null)
                      TextButton.icon(
                        onPressed: _deleteImage,
                        icon:
                            Icon(Icons.delete, color: configProvider.iconColor),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: configProvider.secondaryColor),
                        label: Text(
                          'Remover Foto',
                          style: TextStyle(color: configProvider.textColor),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildCounters(),
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
                    _buildActionButtons(),
                    const SizedBox(height: 30),
                    _buildUserList('Usuários Bloqueados', _blockedUsers),
                  ],
                ),
              ),
            ),
    );
  }
}
