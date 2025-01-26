import 'package:flutter/material.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ViewUserPage extends StatefulWidget {
  final String userId;

  const ViewUserPage({super.key, required this.userId});

  @override
  _ViewUserPageState createState() => _ViewUserPageState();
}

class _ViewUserPageState extends State<ViewUserPage> {
  String? _userName;
  String? _userEmail;
  String? _userImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await ApiService.getUserInfoById(widget.userId);

    if (userInfo != null) {
      setState(() {
        _userName = userInfo['name'];
        _userEmail = userInfo['email'];
        _userImageUrl = userInfo['imageUrl'];
        _isLoading = false;
      });
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');
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
        title: const Text('Perfil do Usuário'),
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
                    const SizedBox(height: 20),
                    Text(
                      _userName ?? 'Nome não disponível',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _userEmail ?? 'E-mail não disponível',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
