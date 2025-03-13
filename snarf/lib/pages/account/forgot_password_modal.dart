import 'package:flutter/material.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/services/api_service.dart';

class ForgotPasswordModal extends StatefulWidget {
  const ForgotPasswordModal({super.key});

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _requestResetCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira seu e-mail.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.requestResetPassword(email);

      if (response == null) {
        Navigator.pop(context);
        showResetPasswordModal(context, email);
      } else {
        setState(() {
          _errorMessage = response;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao solicitar código: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Esqueci Minha Senha',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Insira seu e-mail para receber um código de redefinição de senha.',
            style: TextStyle(
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'E-mail',
              fillColor: Colors.black,
              labelStyle: const TextStyle(color: Colors.black),
              prefixIconColor: const Color(0xFF0b0951),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        LoadingElevatedButton(
          text: 'Enviar Código',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _requestResetCode,
        ),
      ],
      useGradient: true,
    );
  }
}

void showResetPasswordModal(BuildContext context, String email) {
  showDialog(
    context: context,
    builder: (context) => ResetPasswordModal(email: email),
  );
}

class ResetPasswordModal extends StatefulWidget {
  final String email;

  const ResetPasswordModal({super.key, required this.email});

  @override
  State<ResetPasswordModal> createState() => _ResetPasswordModalState();
}

class _ResetPasswordModalState extends State<ResetPasswordModal> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
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
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Redefinir Senha',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Insira o código recebido por e-mail e sua nova senha.'),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.black),
            controller: _codeController,
            decoration: InputDecoration(
              labelText: 'Código',
              labelStyle: const TextStyle(color: Colors.black),
              prefixIconColor: const Color(0xFF0b0951),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              prefixIcon: const Icon(Icons.dataset),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.black),
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Nova Senha',
              labelStyle: const TextStyle(color: Colors.black),
              prefixIconColor: const Color(0xFF0b0951),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              prefixIcon: const Icon(Icons.lock),
            ),
            obscureText: true,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        LoadingElevatedButton(
          text: 'Redefinir Senha',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _resetPassword,
        ),
      ],
      useGradient: true,
    );
  }
}