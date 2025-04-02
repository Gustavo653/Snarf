import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart'; // <-- Import necessário
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/providers/config_provider.dart'; // <-- Import necessário
import 'package:snarf/services/api_service.dart';

class RegisterModal extends StatefulWidget {
  const RegisterModal({super.key});

  @override
  State<RegisterModal> createState() => _RegisterModalState();
}

class _RegisterModalState extends State<RegisterModal> {
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
      screenName: 'RegisterModal',
      screenClass: 'RegisterModal',
    );
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
        quality: 50,
      );
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
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Erro ao fazer login após cadastro.';
          });
          await _analytics.logEvent(
            name: 'register_login_error',
            parameters: {'message': _errorMessage!},
          );
        }
      } else {
        setState(() {
          _errorMessage = createResponse;
        });
        await _analytics.logEvent(
          name: 'register_failure',
          parameters: {'error': createResponse},
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocorreu um erro: $e';
      });
      await _analytics.logEvent(
        name: 'register_exception',
        parameters: {'error': e.toString()},
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenha seu configProvider para acessar cores e demais atributos de tema
    final configProvider = Provider.of<ConfigProvider>(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: CustomModal(
        title: 'Cadastro',
        content: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: TextStyle(color: configProvider.textColor),
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  labelStyle: TextStyle(color: configProvider.textColor),
                  prefixIconColor: configProvider.iconColor,
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: TextStyle(color: configProvider.textColor),
                decoration: InputDecoration(
                  labelText: 'Nome',
                  labelStyle: TextStyle(color: configProvider.textColor),
                  prefixIconColor: configProvider.iconColor,
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: configProvider.textColor),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  labelStyle: TextStyle(color: configProvider.textColor),
                  prefixIconColor: configProvider.iconColor,
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        actions: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            LoadingElevatedButton(
              text: 'Cadastrar',
              isLoading: false,
              onPressed: _register,
            ),
        ],
      ),
    );
  }
}
