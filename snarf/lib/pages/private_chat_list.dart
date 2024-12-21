import 'package:flutter/material.dart';
import 'package:snarf/pages/private_chat_page.dart';

class PrivateChatListPage extends StatelessWidget {
  const PrivateChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock para representar os chats privados
    final List<String> privateChats = [
      'Usuário 1',
      'Usuário 2',
      'Usuário 3',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats Privados'),
      ),
      body: ListView.builder(
        itemCount: privateChats.length,
        itemBuilder: (context, index) {
          final userId = privateChats[index];
          return ListTile(
            title: Text(userId),
            onTap: () {
              // Abrir a página de chat privado
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrivateChatPage(userId: userId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
