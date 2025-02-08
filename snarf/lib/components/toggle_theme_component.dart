import 'package:flutter/material.dart';
import 'package:snarf/utils/show_snackbar.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.brightness_6),
      onPressed: () {
        showSnackbar(context, "Recurso desativado");
        //Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
      },
    );
  }
}
