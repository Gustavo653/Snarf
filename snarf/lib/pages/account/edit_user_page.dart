import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  String? _userImageUrl; // URL da imagem vinda do backend
  int favoritedByCount = 0;
  int blockedByCount = 0;
  bool _isLoading = true;

  File? _pickedFile; // Arquivo local escolhido pelo usuário
  final String _defaultImagePath = // Caminho do asset
      'assets/images/user_anonymous.png';

  List<dynamic> _blockedUsers = [];
  List<dynamic> _favoriteUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// Escolhe imagem da galeria
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedFile = File(pickedFile.path);
        _userImageUrl = null;
        // Anula a URL, pois agora temos uma nova imagem local
      });
    }
  }

  /// Carrega informações do usuário (nome, email, etc.) do backend
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
        _favoriteUsers = userInfo['favoriteChats'] ?? [];
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
                    image: NetworkImage(_userImageUrl!),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage('assets/images/user_anonymous.png'),
                    fit: BoxFit.cover,
                  ),
      ),
    );
  }

  Widget _buildUserList(String title, List<dynamic> users, bool isBlockedList) {
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
                    ? NetworkImage(user['imageUrl'])
                    : const AssetImage('assets/images/user_anonymous.png')
                        as ImageProvider,
              ),
              title: Text(user['name'] ?? 'Usuário'),
              trailing: isBlockedList
                  ? IconButton(
                      icon: const Icon(Icons.lock_open, color: Colors.green),
                      onPressed: () => _unblockUser(user['id']),
                    )
                  : null,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_camera, color: Colors.white),
          label: const Text(
            'Upload',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _saveChanges,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text(
            'Salvar',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _deleteAccount,
          icon: const Icon(Icons.delete_forever, color: Colors.white),
          label: const Text(
            'Excluir',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuário'),
        actions: const [
          ThemeToggle(),
        ],
      ),
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
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Remover Foto',
                          style: TextStyle(color: Colors.red),
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
                    _buildUserList('Usuários Bloqueados', _blockedUsers, true),
                    // _buildUserList('Usuários Favoritos', _favoriteUsers, false),
                  ],
                ),
              ),
            ),
    );
  }
}
