import 'package:flutter/material.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/pages/privateChat/favorites_page.dart';
import 'package:snarf/pages/privateChat/locations_page.dart';
import 'package:snarf/pages/privateChat/parties_page.dart';
import 'package:snarf/pages/privateChat/recent_page.dart';

class PrivateChatNavigationPage extends StatefulWidget {
  const PrivateChatNavigationPage({super.key});

  @override
  State<PrivateChatNavigationPage> createState() =>
      _PrivateChatNavigationPageState();
}

class _PrivateChatNavigationPageState extends State<PrivateChatNavigationPage> {
  int _currentIndex = 1;

  final List<Widget> _pages = [
    const RecentPage(),
    const FavoritesPage(),
    const LocationsPage(),
    const PartiesPage(),
  ];

  final List<String> _titles = [
    'Recentes',
    'Favoritos',
    'Localizações',
    'Festas',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          ThemeToggle(),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Recentes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Localizações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.celebration),
            label: 'Festas',
          ),
        ],
      ),
    );
  }
}
