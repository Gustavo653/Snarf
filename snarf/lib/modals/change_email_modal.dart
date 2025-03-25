import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/components/themed_text_field.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ChangeEmailModal extends StatefulWidget {
  const ChangeEmailModal({super.key});

  @override
  State<ChangeEmailModal> createState() => _ChangeEmailModalState();
}

class _ChangeEmailModalState extends State<ChangeEmailModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final newEmail = _newEmailController.text.trim();
    final currentPassword = _currentPasswordController.text.trim();

    try {
      final result = await ApiService.changeEmail(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );

      if (result == null) {
        showSuccessSnackbar(context, 'Email alterado com sucesso!');
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return CustomModal(
      title: 'Mudar Email',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemedTextField(
              controller: _newEmailController,
              labelText: 'Novo Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            ThemedTextField(
              controller: _currentPasswordController,
              labelText: 'Senha Atual',
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
      ),
      actions: [
        LoadingElevatedButton(
          text: 'Confirmar',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _changeEmail,
        ),
      ],
    );
  }
}
