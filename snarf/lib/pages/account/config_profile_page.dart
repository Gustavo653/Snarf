import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/account/change_email_page.dart';
import 'package:snarf/pages/account/change_password_page.dart';
import 'package:snarf/providers/config_provider.dart';

class ConfigProfilePage extends StatefulWidget {
  const ConfigProfilePage({super.key});

  @override
  State<ConfigProfilePage> createState() => _ConfigProfilePageState();
}

class _ConfigProfilePageState extends State<ConfigProfilePage> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações de Perfil'),
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
        child: Column(
          children: [
            SwitchListTile(
              title: Text(
                "Disponível para vídeo chamadas",
                style: TextStyle(
                  fontSize: 16,
                  color: configProvider.textColor,
                ),
              ),
              secondary: Icon(
                Icons.video_call,
                color: configProvider.iconColor,
              ),
              value: configProvider.hideVideoCall,
              onChanged: (bool value) async {
                setState(() {
                  configProvider.toggleVideoCall();
                });
                await _analytics.logEvent(
                  name: 'toggle_video_call',
                  parameters: {'value': configProvider.hideVideoCall},
                );
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: configProvider.secondaryColor,
                foregroundColor: configProvider.textColor,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChangeEmailPage()),
                );
              },
              child: const Text('Mudar Email'),
            ),
            const SizedBox(height: 16),

            // BOTÃO: Mudar Senha
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: configProvider.secondaryColor,
                foregroundColor: configProvider.textColor,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage()),
                );
              },
              child: const Text('Mudar Senha'),
            ),
          ],
        ),
      ),
    );
  }
}
