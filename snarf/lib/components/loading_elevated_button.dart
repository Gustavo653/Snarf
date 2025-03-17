import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';

class LoadingElevatedButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const LoadingElevatedButton({
    super.key,
    required this.text,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    final bool isLightMode = !config.isDarkMode;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: config.secondaryColor,
        foregroundColor:
            isLightMode ? config.darkPrimaryColor : config.textColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      child: isLoading
          ? CircularProgressIndicator(
              color: isLightMode ? config.darkPrimaryColor : Colors.white,
            )
          : Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLightMode ? config.darkPrimaryColor : config.textColor,
              ),
            ),
    );
  }
}
