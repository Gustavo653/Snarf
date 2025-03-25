import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/components/themed_text_field.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';

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
          SnackBar(
            content: const Text('Senha redefinida com sucesso!'),
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
    final configProvider = Provider.of<ConfigProvider>(context);

    return CustomModal(
      title: 'Redefinir Senha',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Insira o código recebido por e-mail e sua nova senha.',
            style: TextStyle(color: configProvider.textColor),
          ),
          const SizedBox(height: 16),
          ThemedTextField(
            controller: _codeController,
            labelText: 'Código',
            icon: Icons.dataset,
          ),
          const SizedBox(height: 16),
          ThemedTextField(
            controller: _passwordController,
            labelText: 'Nova Senha',
            icon: Icons.lock,
            obscureText: true,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: configProvider.customRed),
            ),
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
    );
  }
}
