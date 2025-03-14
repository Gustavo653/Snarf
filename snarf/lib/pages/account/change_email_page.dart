import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({Key? key}) : super(key: key);

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();

  bool _isLoading = false;

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final newEmail = _newEmailController.text.trim();
    final currentPassword = _currentPasswordController.text;

    try {
      final result = await ApiService.changeEmail(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );

      if (result == null) {
        showSuccessSnackbar(context, 'Email alterado com sucesso!');
        Navigator.pop(context);
      } else {
        showErrorSnackbar(context, result);
      }
    } catch (e) {
      showErrorSnackbar(context, 'Erro: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mudar Email'),
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
                      controller: _newEmailController,
                      decoration:
                          const InputDecoration(labelText: 'Novo Email'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite o novo email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration:
                          const InputDecoration(labelText: 'Senha Atual'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite sua senha atual';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: configProvider.secondaryColor,
                        foregroundColor: configProvider.textColor,
                      ),
                      onPressed: _changeEmail,
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
