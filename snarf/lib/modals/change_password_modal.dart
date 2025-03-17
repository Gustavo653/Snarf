import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/components/themed_text_field.dart';
import 'package:snarf/modals/forgot_password_modal.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({super.key});

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    try {
      final result = await ApiService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (result == null) {
        showSuccessSnackbar(context, 'Senha alterada com sucesso!');
        Navigator.pop(context); // Fecha o modal
      } else {
        setState(() {
          _errorMessage = result;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ForgotPasswordModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return CustomModal(
      title: 'Mudar Senha',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemedTextField(
              controller: _oldPasswordController,
              labelText: 'Senha Antiga',
              icon: Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ThemedTextField(
              controller: _newPasswordController,
              labelText: 'Senha Nova',
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Esqueci minha senha',
                  style: TextStyle(color: configProvider.textColor),
                ),
              ),
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
      ),
      actions: [
        LoadingElevatedButton(
          text: 'Confirmar',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _changePassword,
        ),
      ],
    );
  }
}
