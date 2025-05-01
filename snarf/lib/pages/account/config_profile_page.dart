import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/modals/change_email_modal.dart';
import 'package:snarf/modals/change_password_modal.dart';
import 'package:snarf/pages/account/buy_subscription_page.dart';
import 'package:snarf/pages/account/status_subscription_page.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

String selectedOption = 'Opção 1';
List<String> options = ['Opção 1', 'Opção 2', 'Opção 3'];

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
          _buildSectionTitle("Estatísticas"),
          _buildOptionSelector(
            label: "Idade",
            isActive: configProvider.getStatistic(0),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleStatistic(0);
              });
              await _analytics.logEvent(
                name: 'toggle_statistic',
                parameters: {'value': configProvider.getStatistic(0)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Altura",
            isActive: configProvider.getStatistic(1),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleStatistic(1);
              });
              await _analytics.logEvent(
                name: 'toggle_statistic',
                parameters: {'value': configProvider.getStatistic(1)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Peso",
            isActive: configProvider.getStatistic(2),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleStatistic(2);
              });
              await _analytics.logEvent(
                name: 'toggle_statistic',
                parameters: {'value': configProvider.getStatistic(2)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Dotado",
            isActive: configProvider.getStatistic(3),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleStatistic(3);
              });
              await _analytics.logEvent(
                name: 'toggle_statistic',
                parameters: {'value': configProvider.getStatistic(3)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Tipo de Corpo",
            isActive: configProvider.getStatistic(4),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleStatistic(4);
              });
              await _analytics.logEvent(
                name: 'toggle_statistic',
                parameters: {'value': configProvider.getStatistic(4)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            })
          ),
          _buildSectionTitle("Sexualidade"),
          _buildOptionSelector(
            label: "Espectro",
            isActive: configProvider.getSexuality(0),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleSexuality(0);
              });
              await _analytics.logEvent(
                name: 'toggle_sexuality',
                parameters: {'value': configProvider.getSexuality(0)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Atitude",
            isActive: configProvider.getSexuality(1),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleSexuality(1);
              });
              await _analytics.logEvent(
                name: 'toggle_sexuality',
                parameters: {'value': configProvider.getSexuality(1)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Expressão",
            isActive: configProvider.getSexuality(2),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleSexuality(2);
              });
              await _analytics.logEvent(
                name: 'toggle_sexuality',
                parameters: {'value': configProvider.getSexuality(2)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildSectionTitle("Cena"),
          _buildOptionSelector(
            label: "Localização",
            isActive: configProvider.getScene(0),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleScene(0);
              });
              await _analytics.logEvent(
                name: 'toggle_scene',
                parameters: {'value': configProvider.getScene(0)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Em público",
            isActive: configProvider.getScene(1),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleScene(1);
              });
              await _analytics.logEvent(
                name: 'toggle_scene',
                parameters: {'value': configProvider.getScene(1)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Procurando",
            isActive: configProvider.getScene(2),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleScene(2);
              });
              await _analytics.logEvent(
                name: 'toggle_scene',
                parameters: {'value': configProvider.getScene(2)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Fetiches",
            isActive: configProvider.getScene(3),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleScene(3);
              });
              await _analytics.logEvent(
                name: 'toggle_scene',
                parameters: {'value': configProvider.getScene(3)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Que Gosta",
            isActive: configProvider.getScene(4),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleScene(4);
              });
              await _analytics.logEvent(
                name: 'toggle_scene',
                parameters: {'value': configProvider.getScene(4)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Interação",
            isActive: configProvider.getScene(5),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.toggleScene(5);
              });
              await _analytics.logEvent(
                name: 'toggle_scene',
                parameters: {'value': configProvider.getScene(5)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildSectionTitle("Práticas e Preferências de Saúde"),
          _buildOptionSelector(
            label: "Práticas",
            isActive: configProvider.getPreferences(0),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(0);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(0)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Status do HIV",
            isActive: configProvider.getPreferences(1),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(1);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(1)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Testado para HIV",
            isActive: configProvider.getPreferences(2),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(2);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(2)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Testado para ISTs",
            isActive: configProvider.getPreferences(3),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(3);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(3)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Salvaguardas",
            isActive: configProvider.getPreferences(4),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(4);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(4)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Meus Níveis de Conforto",
            isActive: configProvider.getPreferences(5),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(5);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(5)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
          _buildOptionSelector(
            label: "Eu levo...",
            isActive: configProvider.getPreferences(6),
            options: options,
            selectedOption: selectedOption,
            onToggle: (bool value) async {
              setState(() {
                configProvider.togglePreferences(6);
              });
              await _analytics.logEvent(
                name: 'toggle_preferences',
                parameters: {'value': configProvider.getPreferences(6)},
              );
            },
            onOptionChanged: (val) => setState(() {
              if(val != null) selectedOption = val;
            }) 
          ),
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

  Widget _buildOptionSelector({
  required String label,
  required List<String> options,
  required String selectedOption,
  required ValueChanged<String?> onOptionChanged,
  required bool isActive,
  required ValueChanged<bool> onToggle,
  Color? textColor,
  Color? dropdownColor,
}) {
  final configProvider = Provider.of<ConfigProvider>(context);
  final effectiveTextColor = textColor ?? configProvider.iconColor;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: effectiveTextColor, fontSize: 16)),
        Row(
          children: [
            SizedBox(
              width: 160,
              child: DropdownButton2<String>(
                isExpanded: true,
                value: selectedOption,
                onChanged: onOptionChanged,
                items: options.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                buttonStyleData: const ButtonStyleData(
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 200,
                  offset: const Offset(0, 0),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isOverButton: true,
                ),
                iconStyleData: const IconStyleData(
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
                ),
                style: const TextStyle(color: Colors.blue),
                underline: const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isActive,
              onChanged: onToggle,
            ),
          ],
        ),
      ],
    ),
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
