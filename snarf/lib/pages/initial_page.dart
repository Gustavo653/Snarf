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
    int birthYear = DateTime.now().year - 18;
    final currentYear = DateTime.now().year;
    final minYear = currentYear - 100;

    return showDialog<int?>(
      context: context,
      builder: (context) {
        int selectedYear = birthYear;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: Color(0xFF392EA3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16.0),
                        topRight: Radius.circular(16.0),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.pink.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CONFIRMAR IDADE',
                          style: TextStyle(
                            color: Color(0xFF392EA3),
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Text(
                          'Snarf é um app exclusivo para maiores de idade.\nPrecisamos verificar a sua idade.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 14.0,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        const Text(
                          'QUANDO VOCÊ NASCEU?',
                          style: TextStyle(
                            color: Color(0xFF392EA3),
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.white,
                                Colors.pink.shade50,
                              ],
                            ),
                          ),
                          child: SizedBox(
                            height: 100.0,
                            child: ListWheelScrollView.useDelegate(
                              controller: FixedExtentScrollController(
                                initialItem: currentYear - birthYear,
                              ),
                              itemExtent: 25.0,
                              perspective: 0.003,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedYear = currentYear - index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final year = currentYear - index;
                                  final isSelected = year == selectedYear;
                                  return Text(
                                    year.toString(),
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Color(0xFF392EA3)
                                          : Colors.black,
                                    ),
                                  );
                                },
                                childCount: currentYear - minYear + 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16.0),
                                side: const BorderSide(
                                  color: Color(0xFF392EA3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'VOLTAR',
                                style: TextStyle(
                                  color: Color(0xFF392EA3),
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16.0),
                                backgroundColor: Color(0xFF392EA3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                              ),
                              onPressed: () {
                                if (currentYear - selectedYear >= 18) {
                                  Navigator.of(context).pop(selectedYear);
                                } else {
                                  _showErrorDialog(
                                    context,
                                    'Você precisa ser maior de idade para continuar.',
                                  );
                                }
                              },
                              child: const Text(
                                'AVANÇAR',
                                style: TextStyle(color: Colors.white),
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
          },
        );
      },
    );
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
                    widthFactor: 0.70,
                    child: CustomElevatedButton(
                      text: 'Espiar Anonimamente',
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
