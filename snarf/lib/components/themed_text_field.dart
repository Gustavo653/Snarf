import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';

class ThemedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;

  const ThemedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: configProvider.textColor),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: configProvider.textColor),
        prefixIconColor: configProvider.iconColor,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}