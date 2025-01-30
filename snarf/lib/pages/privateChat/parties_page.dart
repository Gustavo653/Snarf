import 'package:flutter/material.dart';

class PartiesPage extends StatelessWidget {
  const PartiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Festas',
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(height: 16),
          Text(
            'Este recurso estará disponível em breve.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
