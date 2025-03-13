import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/forgot_password_modal.dart';
import 'package:snarf/providers/config_provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;

    try {
      // final result = await ApiService.changePassword(
      //   oldPassword: oldPassword,
      //   newPassword: newPassword,
      // );

      // if (result.success) {
      //   showSnackbar(context, 'Senha alterada com sucesso!');
      //   Navigator.pop(context);
      // } else {
      //   showSnackbar(context, result.errorMessage ?? 'Erro ao alterar senha');
      // }

      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
      // showSnackbar(context, 'Senha alterada com sucesso!');
    } catch (e) {
      // showSnackbar(context, 'Erro: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mudar Senha'),
        backgroundColor: configProvider.primaryColor,
        iconTheme: IconThemeData(color: configProvider.iconColor),
        titleTextStyle: TextStyle(
          color: configProvider.textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: configProvider.primaryColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _oldPasswordController,
                decoration:
                const InputDecoration(labelText: 'Senha Antiga'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite a senha antiga';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration:
                const InputDecoration(labelText: 'Senha Nova'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite a nova senha';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: configProvider.secondaryColor,
                  foregroundColor: configProvider.textColor,
                ),
                onPressed: _changePassword,
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
