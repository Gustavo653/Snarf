import 'package:flutter/material.dart';

class CustomModal extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool useGradient;

  const CustomModal({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0),
          border: const Border.symmetric(
            horizontal: BorderSide(
              color: Color(0xFF392ea3),
              width: 5,
            ),
          ),
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.pink.shade50,
                  ],
                )
              : null,
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0b0951),
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10.0),

            // CONTEÚDO
            content,

            const SizedBox(height: 20.0),

            // AÇÕES (botões, por exemplo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
