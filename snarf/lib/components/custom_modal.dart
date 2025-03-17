import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';

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
    final config = Provider.of<ConfigProvider>(context);
    final bool isLightMode = useGradient ? true : !config.isDarkMode;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0),
          border: Border.symmetric(
            horizontal: BorderSide(
              color: config.primaryColor,
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
          color: useGradient
              ? null
              : (isLightMode ? Colors.white : config.darkPrimaryColor),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isLightMode ? config.darkPrimaryColor : config.textColor,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10.0),
            content,
            const SizedBox(height: 20.0),
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
