import 'package:flutter/material.dart';

class CustomElevatedButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const CustomElevatedButton({
    super.key,
    required this.text,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 32.0,
          vertical: 4.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        elevation: 4,
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Ink(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 32.0),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.0,
                  ),
                ),
              ),
            ),
    );
  }
}
