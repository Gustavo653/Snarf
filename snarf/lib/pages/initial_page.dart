import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/components/custom_elevated_button.dart';
import 'package:snarf/pages/login_page.dart';
import 'package:snarf/services/api_service.dart';
import 'package:uuid/uuid.dart';

class InitialPage extends StatefulWidget {
  const InitialPage({super.key});

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  bool _isLoading = false;
  final _imagePaths = <String>[
    'assets/images/snarf-bg000.jpg',
    'assets/images/snarf-bg001.jpg',
    'assets/images/snarf-bg002.jpg',
    'assets/images/snarf-bg003.jpg',
    'assets/images/snarf-bg004.jpg',
    'assets/images/snarf-bg005.jpg',
    'assets/images/snarf-bg006.jpg',
    'assets/images/snarf-bg007.jpg',
    'assets/images/snarf-bg008.jpg',
    'assets/images/snarf-bg009.jpg',
    'assets/images/snarf-bg010.jpg',
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

  Future<void> _createAnonymousAccount(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: double.infinity,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo-white.png',
                    height: 100,
                  ),
                  const SizedBox(height: 48),
                  CustomElevatedButton(
                    text: 'USAR ANONIMAMENTE',
                    isLoading: _isLoading,
                    onPressed: () => _createAnonymousAccount(context),
                  ),
                  const SizedBox(height: 24),
                  CustomElevatedButton(
                    text: 'ACESSAR MINHA CONTA',
                    isLoading: false,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
