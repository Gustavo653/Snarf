import 'dart:ui';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/modals/register_modal.dart';
import 'package:snarf/pages/account/initial_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';

class LoginModal extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginModal({super.key, required this.onLoginSuccess});

  @override
  State<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<LoginModal> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> isPasswordVisible = ValueNotifier(false);
  static const _secureStorage = FlutterSecureStorage();
  bool isLoading = false;
  String? errorMessage;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Por favor, preencha todos os campos.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loginResponse = await ApiService.login(email, password);

      await _analytics.logEvent(
        name: 'login_attempt',
        parameters: {
          'email': email,
        },
      );

      await _secureStorage.write(key: 'email', value: email);
      await _secureStorage.write(key: 'password', value: password);

      if (loginResponse == null) {
        await _analytics.logEvent(
          name: 'login_success',
          parameters: {
            'email': email,
          },
        );
        widget.onLoginSuccess();
      } else {
        await _analytics.logEvent(
          name: 'login_failure',
          parameters: {
            'email': email,
            'error': loginResponse,
          },
        );
        setState(() {
          errorMessage = loginResponse;
        });
      }
    } catch (e) {
      await _analytics.logEvent(
        name: 'login_exception',
        parameters: {
          'error': e.toString(),
        },
      );
      setState(() {
        errorMessage = 'Ocorreu um erro: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    _analytics.logScreenView(
      screenName: 'LoginModal',
      screenClass: 'LoginModal',
    );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: CustomModal(
        title: 'Login',
        content: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                style: TextStyle(color: configProvider.textColor),
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  labelStyle: TextStyle(color: configProvider.textColor),
                  prefixIconColor: configProvider.iconColor,
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: isPasswordVisible,
                builder: (context, isVisible, child) {
                  return TextField(
                    controller: passwordController,
                    style: TextStyle(color: configProvider.textColor),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: TextStyle(color: configProvider.textColor),
                      prefixIconColor: configProvider.iconColor,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        color: configProvider.iconColor,
                        onPressed: () {
                          isPasswordVisible.value = !isVisible;
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    obscureText: !isVisible,
                  );
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            LoadingElevatedButton(
              text: 'Entrar',
              isLoading: false,
              onPressed: login,
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    showForgotPasswordModal(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Esqueci minha senha',
                      style: TextStyle(
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const RegisterModal(),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        Text(
                          'Primeira vez no Snarf? ',
                          style: TextStyle(
                            color: configProvider.textColor,
                          ),
                        ),
                        Text(
                          'Criar conta',
                          style: TextStyle(
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
