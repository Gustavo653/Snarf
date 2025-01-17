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

class _PrivateChatNavigationPageState extends State<PrivateChatNavigationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: _pages.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabController.index]),
        actions: [
          ThemeToggle(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.chat), text: 'Recentes'),
            Tab(icon: Icon(Icons.star), text: 'Favoritos'),
            Tab(icon: Icon(Icons.location_on), text: 'Localizações'),
            Tab(icon: Icon(Icons.celebration), text: 'Festas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _pages,
      ),
    );
  }
}
