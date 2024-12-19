import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/initial_page.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/app_themes.dart';
import 'providers/theme_provider.dart';

void main() {
  const isRelease = bool.fromEnvironment('dart.vm.product');
  ApiConstants.baseUrl = isRelease ? "https://snarf.inovitech.inf.br" : ApiConstants.baseUrl;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: SnarfApp(),
    ),
  );
}

class SnarfApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'snarf',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      home: const InitialPage(),
    );
  }
}
