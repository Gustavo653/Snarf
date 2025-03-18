import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/components/themed_text_field.dart';
import 'package:snarf/modals/reset_password_modal.dart';
import 'package:snarf/providers/config_provider.dart';
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
    final configProvider = Provider.of<ConfigProvider>(context);

    return CustomModal(
      title: 'Esqueci Minha Senha',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Insira seu e-mail para receber um código de redefinição de senha.',
            style: TextStyle(
              color: configProvider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          ThemedTextField(
            controller: _emailController,
            labelText: 'E-mail',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
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
          text: 'Enviar Código',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _requestResetCode,
        ),
      ],
    );
  }
}

void showResetPasswordModal(BuildContext context, String email) {
  showDialog(
    context: context,
    builder: (context) => ResetPasswordModal(email: email),
  );
}
