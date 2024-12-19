import 'package:flutter/material.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/pages/login_page.dart';
import 'package:snarf/components/custom_elevated_button.dart';

class InitialPage extends StatelessWidget {
  const InitialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'snarf',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 48),
              CustomElevatedButton(
                text: 'Espiar Anonimamente',
                isLoading: false,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
              ),
              const SizedBox(height: 24),
              CustomElevatedButton(
                text: 'Login',
                isLoading: false,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
