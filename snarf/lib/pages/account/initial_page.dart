import 'dart:convert';
import 'dart:io';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/custom_modal.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/components/loading_outlined_button.dart';
import 'package:snarf/modals/forgot_password_modal.dart';
import 'package:snarf/modals/login_modal.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

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

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();

    _analytics.logScreenView(
      screenName: 'InitialPage',
      screenClass: 'InitialPage',
    );

    _performLogout();
    _shuffleImages();
  }

  void _performLogout() async {
    await _analytics.logEvent(name: 'perform_logout');

    await ApiService.logout();
    await SignalRManager().stopConnection();
    Provider.of<ConfigProvider>(context, listen: false).setDarkTheme();
  }

  void _shuffleImages() {
    _analytics.logEvent(name: 'shuffle_background_images');
    _imagePaths.shuffle();
  }

  Future<int?> _showAgeConfirmationDialog(BuildContext context) async {
    await _analytics.logEvent(name: 'show_age_confirmation_dialog');
    return showDialog(
      context: context,
      builder: (context) => const AgeConfirmationDialog(),
    );
  }

  Future<void> _createAnonymousAccount(BuildContext context) async {
    await _analytics.logEvent(name: 'attempt_anonymous_registration');

    final birthYear = await _showAgeConfirmationDialog(context);
    if (birthYear == null) return;

    final currentYear = DateTime.now().year;
    final isAdult = (currentYear - birthYear) >= 18;

    await _analytics.logEvent(
      name: 'age_confirmation_result',
      parameters: {'birth_year': birthYear, 'is_adult': isAdult.toString()},
    );

    if (!isAdult) {
      return;
    }

    String uniqueId = const Uuid().v4();
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
          await _analytics.logEvent(name: 'anonymous_registration_success');
          // Navega para HomePage
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          await _analytics.logEvent(
            name: 'anonymous_registration_login_error',
            parameters: {'error': loginResponse},
          );
          _showErrorDialog(context, 'Erro ao criar conta anônima');
        }
      } else {
        await _analytics.logEvent(
          name: 'anonymous_registration_error',
          parameters: {'error': errorMessage},
        );
        _showErrorDialog(context, 'Erro ao registrar conta: $errorMessage');
      }
    } catch (e) {
      await _analytics.logEvent(
        name: 'anonymous_registration_exception',
        parameters: {'exception': e.toString()},
      );
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

  void _showLoginModal(BuildContext context) async {
    await _analytics.logEvent(name: 'show_login_modal');

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

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: 'Erro',
        content: Text(
          message,
          style: const TextStyle(
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
                      fontWeight: FontWeight.bold,
                    ),
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
          const Positioned(
            bottom: 30,
            left: 15,
            right: 15,
            child: TermsFooter(),
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
  const TermsFooter({super.key});

  void _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Não foi possível abrir a URL: $url');
    }
  }

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
              onTap: () =>
                  _openUrl('https://snarf.inovitech.inf.br/service.html'),
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
              onTap: () =>
                  _openUrl('https://snarf.inovitech.inf.br/privacy.html'),
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
    final configProvider = Provider.of<ConfigProvider>(context);

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
              color: configProvider.textColor,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 20.0),
          Text(
            'Quando Você Nasceu?',
            style: TextStyle(
              color: configProvider.textColor,
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20.0),
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                color: configProvider.secondaryColor),
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
                                  color:
                                      configProvider.textColor.withOpacity(0.4),
                                  width: 1.0,
                                ),
                                bottom: BorderSide(
                                  color:
                                      configProvider.textColor.withOpacity(0.4),
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
                              ? configProvider.textColor
                              : configProvider.textColor.withOpacity(0.7),
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
        LoadingOutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            isLoading: false,
            text: 'Voltar'),
        LoadingElevatedButton(
            text: 'Avançar',
            isLoading: false,
            onPressed: () {
              if (currentYear - selectedYear >= 18) {
                Navigator.of(context).pop(selectedYear);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Você precisa ser maior de idade para continuar.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            })
      ],
    );
  }
}

void showForgotPasswordModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const ForgotPasswordModal(),
  );
}
