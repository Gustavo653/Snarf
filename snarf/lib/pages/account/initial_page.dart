import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/pages/account/register_page.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:uuid/uuid.dart';

class InitialPage extends StatefulWidget {
  const InitialPage({super.key});

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  static const _secureStorage = FlutterSecureStorage();
  bool _isLoading = false;

  final String _defaultImagePath = 'assets/images/user_anonymous.png';
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
    await SignalRManager().stopConnection();
    Provider.of<ThemeProvider>(context, listen: false).setDarkTheme();
  }

  void _shuffleImages() {
    _imagePaths.shuffle();
  }

  Future<int?> _showAgeConfirmationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AgeConfirmationDialog(),
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
      final pickedFile = await getAssetFile(_defaultImagePath);
      String base64Image = '';
      final compressedImage = await FlutterImageCompress.compressWithFile(
        pickedFile.absolute.path,
        quality: 50,
      );

      if (compressedImage != null) {
        base64Image = base64Encode(compressedImage);
      }

      final errorMessage =
          await ApiService.register(email, name, 'Senha@123', base64Image);
      if (errorMessage == null) {
        final loginResponse = await ApiService.login(email, 'Senha@123');
        await _secureStorage.write(key: 'email', value: email);
        await _secureStorage.write(key: 'password', value: 'Senha@123');
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

  Future<File> getAssetFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/user_anonymous.png';
    final file = File(tempFilePath);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  void _showLoginModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => LoginModal(onLoginSuccess: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }),
    );
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
      builder: (context) => CustomModal(
        title: 'Erro',
        content: Text(
          message,
          style: TextStyle(
            fontSize: 16.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Fechar',
              style: TextStyle(
                color: Color(0xFF0b0951),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        useGradient: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          BackgroundCarousel(imagePaths: _imagePaths),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo-black.png',
                    height: 50,
                  ),
                  const SizedBox(height: 48),
                  FractionallySizedBox(
                    widthFactor: 0.50,
                    child: LoadingElevatedButton(
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
                    widthFactor: 0.30,
                    child: LoadingElevatedButton(
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
            child: TermsFooter(
              onTermsTap: () => _showModal(
                  context, 'Termos de Serviço', 'Descrição Termos de Serviço'),
              onPrivacyTap: () => _showModal(context, 'Política de Privacidade',
                  'Descrição Política de Privacidade'),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundCarousel extends StatelessWidget {
  final List<String> imagePaths;

  const BackgroundCarousel({super.key, required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CarouselSlider(
        options: CarouselOptions(
          height: double.infinity,
          autoPlay: true,
          autoPlayInterval: const Duration(minutes: 5),
          viewportFraction: 1.0,
          enlargeCenterPage: false,
        ),
        items: imagePaths.map((path) {
          return Image.asset(
            path,
            fit: BoxFit.cover,
            width: double.infinity,
          );
        }).toList(),
      ),
    );
  }
}

class TermsFooter extends StatelessWidget {
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const TermsFooter({
    super.key,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
              onTap: onTermsTap,
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
              onTap: onPrivacyTap,
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
    );
  }
}

class AgeConfirmationDialog extends StatefulWidget {
  const AgeConfirmationDialog({super.key});

  @override
  State<AgeConfirmationDialog> createState() => _AgeConfirmationDialogState();
}

class _AgeConfirmationDialogState extends State<AgeConfirmationDialog> {
  late int selectedYear;
  final int currentYear = DateTime.now().year;
  final int minYear = DateTime.now().year - 100;
  final int birthYear = DateTime.now().year - 18;

  @override
  void initState() {
    super.initState();
    selectedYear = birthYear;
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Confirmar Idade',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Snarf é um app exclusivo para maiores de idade.\n'
            'Precisamos verificar a sua idade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 20.0),
          const Text(
            'Quando Você Nasceu?',
            style: TextStyle(
              color: Color(0xFF0b0951),
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
              borderRadius: BorderRadius.circular(30.0),
            ),
            child: SizedBox(
              height: 100.0,
              child: ListWheelScrollView.useDelegate(
                controller: FixedExtentScrollController(
                  initialItem: currentYear - selectedYear,
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
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border(
                                top: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.0,
                                ),
                                bottom: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.0,
                                ),
                              )
                            : null,
                      ),
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF0b0951)
                              : Colors.black,
                        ),
                      ),
                    );
                  },
                  childCount: currentYear - minYear + 1,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Voltar',
            style: TextStyle(
              color: Color(0xFF0b0951),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (currentYear - selectedYear >= 18) {
              Navigator.of(context).pop(selectedYear);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Você precisa ser maior de idade para continuar.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text(
            'Avançar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
      useGradient: true,
    );
  }
}

void showForgotPasswordModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => ForgotPasswordModal(),
  );
}

class ForgotPasswordModal extends StatefulWidget {
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
              labelStyle: TextStyle(color: Colors.black),
              prefixIconColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: Colors.black),
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

  const ResetPasswordModal({required this.email});

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
            style: TextStyle(color: Colors.black),
            controller: _codeController,
            decoration: InputDecoration(
              labelText: 'Código',
              labelStyle: TextStyle(color: Colors.black),
              prefixIconColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              prefixIcon: const Icon(Icons.dataset),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            style: TextStyle(color: Colors.black),
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Nova Senha',
              labelStyle: TextStyle(color: Colors.black),
              prefixIconColor: Colors.black,
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
      await _secureStorage.write(key: 'email', value: email);
      await _secureStorage.write(key: 'password', value: password);
      if (loginResponse == null) {
        widget.onLoginSuccess();
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

  @override
  Widget build(BuildContext context) {
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
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  labelStyle: TextStyle(color: Colors.black),
                  prefixIconColor: Colors.black,
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
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: TextStyle(color: Colors.black),
                      prefixIconColor: Colors.black,
                      suffixIconColor: Colors.black,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isVisible ? Icons.visibility : Icons.visibility_off,
                        ),
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
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        Text(
                          'Primeira vez no Snarf? ',
                          style: TextStyle(
                            color: Colors.black,
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
        useGradient: true,
      ),
    );
  }
}
