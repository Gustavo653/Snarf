import 'package:flutter/material.dart';
import 'package:snarf/components/custom_elevated_button.dart';
import 'package:snarf/services/api_service.dart';
import 'package:flutter/services.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_codeFocusNode.hasFocus) {
      Future.delayed(Duration(milliseconds: 100), () {
        _pasteCodeFromClipboard();
      });
    }
  }

  Future<void> _pasteCodeFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _codeController.text = clipboardData.text!;
      });
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();

    if (code.isEmpty || password.isEmpty) {
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
      final response =
          await ApiService.resetPassword(widget.email, code, password);

      if (response == null) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        setState(() {
          _errorMessage = response;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao redefinir a senha: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codeFocusNode.removeListener(_onFocusChange);
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redefinir Senha'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Insira o código recebido por e-mail e sua nova senha.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  // Atribuir o FocusNode ao campo de código
                  decoration: InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.dataset),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                CustomElevatedButton(
                  text: 'Redefinir Senha',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _resetPassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
