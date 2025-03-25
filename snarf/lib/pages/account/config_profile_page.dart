import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/modals/change_email_modal.dart';
import 'package:snarf/modals/change_password_modal.dart';
import 'package:snarf/pages/account/buy_subscription_page.dart';
import 'package:snarf/pages/account/status_subscription_page.dart';
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
      body: ListView(
        children: [
          _buildSectionTitle("Conta"),
          _buildListTile(
            "Endereço de email",
            Icons.email,
            () {
              showDialog(
                context: context,
                builder: (_) => const ChangeEmailModal(),
              );
            },
          ),
          _buildListTile(
            "Senha",
            Icons.lock,
            () {
              showDialog(
                context: context,
                builder: (_) => const ChangePasswordModal(),
              );
            },
          ),
          _buildListTile("Snarf Plus", Icons.workspace_premium, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StatusSubscriptionPage(),
              ),
            );
          }),
          _buildSectionTitle("Configurações"),
          _buildSwitchTile(
            "Disponível para vídeo chamadas",
            Icons.video_call,
            configProvider.hideVideoCall,
            (bool value) async {
              setState(() {
                configProvider.toggleVideoCall();
              });
              await _analytics.logEvent(
                name: 'toggle_video_call',
                parameters: {'value': configProvider.hideVideoCall},
              );
            },
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: configProvider.secondaryColor,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildListTile(String title, IconData icon, VoidCallback onTap) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: configProvider.iconColor),
          title: Text(
            title,
            style: TextStyle(fontSize: 16, color: configProvider.iconColor),
          ),
          trailing: Icon(Icons.chevron_right, color: configProvider.iconColor),
          onTap: onTap,
        ),
        _buildDivider(),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16, color: configProvider.iconColor),
      ),
      secondary: Icon(icon, color: configProvider.iconColor),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider() {
    final configProvider = Provider.of<ConfigProvider>(context);
    return Divider(
      height: 1,
      thickness: 1,
      color: configProvider.secondaryColor,
    );
  }
}
