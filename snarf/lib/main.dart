import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/account/initial_page.dart';
import 'pages/home_page.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'utils/api_constants.dart';
import 'utils/app_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureApiConstants();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const SnarfApp(),
    ),
  );
}

void configureApiConstants() {
  const isRelease = bool.fromEnvironment('dart.vm.product');
  ApiConstants.baseUrl =
      isRelease ? "https://snarf.inovitech.inf.br/api" : ApiConstants.baseUrl;
}

class SnarfApp extends StatelessWidget {
  const SnarfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'snarf',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: ApiService.getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          debugPrint('Erro ao obter token: ${snapshot.error}');
          return const Scaffold(
            body: Center(
              child: Text('Ocorreu um erro. Tente novamente mais tarde.'),
            ),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        } else {
          return const InitialPage();
        }
      },
    );
  }
}
