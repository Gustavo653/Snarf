import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/services/api_service.dart';
import '../home_page.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final String _defaultImagePath = 'assets/images/user_anonymous.png';
  bool _isLoading = false;
  String? _errorMessage;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _analytics.logScreenView(
        screenName: 'RegisterPage', screenClass: 'RegisterPage');
  }

  Future<File> getAssetFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/user_anonymous.png';
    final file = File(tempFilePath);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || name.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, preencha todos os campos.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _analytics.logEvent(name: 'register_attempt');
      final pickedFile = await getAssetFile(_defaultImagePath);
      String base64Image = '';
      final compressedImage = await FlutterImageCompress.compressWithFile(
          pickedFile.absolute.path,
          quality: 50);
      if (compressedImage != null) {
        base64Image = base64Encode(compressedImage);
      }
      final createResponse =
          await ApiService.register(email, name, password, base64Image);
      if (createResponse == null) {
        final loginResponse = await ApiService.login(email, password);
        if (loginResponse == null) {
          await _analytics.logEvent(name: 'register_success');
          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const HomePage()));
          }
        } else {
          setState(() {
            _errorMessage = 'Erro ao fazer login após cadastro.';
          });
          await _analytics.logEvent(
              name: 'register_login_error',
              parameters: {'message': _errorMessage!});
        }
      } else {
        setState(() {
          _errorMessage = createResponse;
        });
        await _analytics.logEvent(
            name: 'register_failure', parameters: {'error': createResponse});
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocorreu um erro: $e';
      });
      await _analytics.logEvent(
          name: 'register_exception', parameters: {'error': e.toString()});
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Crie sua conta',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                LoadingElevatedButton(
                  text: 'Cadastrar',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _register,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}