import 'package:flutter/material.dart';

void showErrorSnackbar(BuildContext context, String message, {Color color = Colors.red}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 5),
    ),
  );
}

void showSuccessSnackbar(BuildContext context, String message, {Color color = Colors.green}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
    ),
  );
}