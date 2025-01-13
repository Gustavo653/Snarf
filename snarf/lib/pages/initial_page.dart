import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:snarf/components/custom_elevated_button.dart';
import 'package:snarf/pages/forgot_password_page.dart';
import 'package:snarf/pages/register_page.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import 'home_page.dart';

class InitialPage extends StatefulWidget {
  const InitialPage({super.key});

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  bool _isLoading = false;
  final _imagePaths = <String>[
    'assets/images/snarf-bg001.jpg',
    'assets/images/snarf-bg002.jpg',
    'assets/images/snarf-bg003.jpg'
  ];

  @override
  void initState() {
    super.initState();
    _performLogout();
    _shuffleImages();
  }

  void _performLogout() async {
    await ApiService.logout();
  }

  void _shuffleImages() async {
    _imagePaths.shuffle();
  }

  Future<int?> _showAgeConfirmationDialog(BuildContext context) async {
    int? birthYear;
    final currentYear = DateTime.now().year;
    List<int> years = List.generate(100, (index) => currentYear - index);

    final TextEditingController controller = TextEditingController();

    return showDialog<int?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirmação de Idade'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Ano de nascimento',
                    hintText: 'Selecione seu ano de nascimento',
                  ),
                  onTap: () async {
                    final selectedYear = await showDialog<int>(
                      context: context,
                      builder: (context) {
                        return SimpleDialog(
                          title: const Text('Escolha seu ano de nascimento'),
                          children: years
                              .map((year) => SimpleDialogOption(
                                    onPressed: () {
                                      Navigator.pop(context, year);
                                    },
                                    child: Text(year.toString()),
                                  ))
                              .toList(),
                        );
                      },
                    );
                    if (selectedYear != null) {
                      controller.text = selectedYear.toString();
                      birthYear = selectedYear;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (birthYear != null && currentYear - birthYear! >= 18) {
                    Navigator.of(context).pop(birthYear);
                  } else {
                    _showErrorDialog(context,
                        'Você precisa ser maior de idade para continuar.');
                  }
                },
                child: const Text('Confirmar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        });
  }

  Future<void> _createAnonymousAccount(BuildContext context) async {
    final birthYear = await _showAgeConfirmationDialog(context);
    if (birthYear == null) return;

    String uniqueId = Uuid().v4();
    String email = '$uniqueId@anonimo.com';
    String name = 'anon_$uniqueId';

    setState(() {
      _isLoading = true;
    });

    try {
      final errorMessage = await ApiService.register(email, name, 'Senha@123');
      if (errorMessage == null) {
        final loginResponse = await ApiService.login(email, 'Senha@123');
        if (loginResponse == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          _showErrorDialog(context, 'Erro ao criar conta anônima');
        }
      } else {
        _showErrorDialog(context, 'Erro ao registrar conta: $errorMessage');
      }
    } catch (e) {
      _showErrorDialog(context, 'Erro: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showModal(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLoginModal(BuildContext context) {
    final TextEditingController emailController =
        TextEditingController(text: 'admin@admin.com');
    final TextEditingController passwordController =
        TextEditingController(text: 'Admin@123');
    final ValueNotifier<bool> isPasswordVisible = ValueNotifier(false);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
            builder: (context, setState) {
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

                  if (loginResponse == null) {
                    Navigator.pop(context); // Fecha o modal
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  } else {
                    setState(() {
                      errorMessage = loginResponse;
                    });
                  }
                } catch (e) {
                  setState(() {
                    errorMessage = 'Ocorreu um erro: $e';
                  });
                } finally {
                  setState(() {
                    isLoading = false;
                  });
                }
              }

              return AlertDialog(
                title: const Text('Login'),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder(
                        valueListenable: isPasswordVisible,
                        builder: (context, isVisible, child) {
                          return TextField(
                            controller: passwordController,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  isPasswordVisible.value = !isVisible;
                                },
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
                    const Center(child: CircularProgressIndicator()),
                  if (!isLoading) ...[
                    CustomElevatedButton(
                      text: 'Entrar',
                      isLoading: false,
                      onPressed: login,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Esqueci minha senha',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Criar conta',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IgnorePointer(
            child: CarouselSlider(
              options: CarouselOptions(
                height: double.infinity,
                autoPlay: true,
                autoPlayInterval: const Duration(minutes: 5),
                viewportFraction: 1.0,
                enlargeCenterPage: false,
              ),
              items: _imagePaths.map((path) {
                return Image.asset(
                  path,
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              }).toList(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo-black.png',
                    height: 100,
                  ),
                  const SizedBox(height: 48),
                  FractionallySizedBox(
                    widthFactor: 0.50,
                    child: CustomElevatedButton(
                      text: 'Espiar',
                      isLoading: _isLoading,
                      onPressed: () => _createAnonymousAccount(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ou',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: 0.50,
                    child: CustomElevatedButton(
                      text: 'Login',
                      isLoading: false,
                      onPressed: () => _showLoginModal(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 15,
            right: 15,
            child: Column(
              children: [
                const Text(
                  'Você deve ser maior de 18 anos para usar este aplicativo.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _showModal(
                        context,
                        'Termos de Serviço',
                        'Descrição Termos de Serviço',
                      ),
                      child: const Text(
                        'Termos de Serviço',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(
                      ' e ',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showModal(
                        context,
                        'Política de Privacidade',
                        'Descrição Política de Privacidade',
                      ),
                      child: const Text(
                        'Política de Privacidade',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
