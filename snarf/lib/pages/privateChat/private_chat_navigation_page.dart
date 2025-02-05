import 'package:flutter/material.dart';
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
    const RecentPage(showFavorites: false),
    const RecentPage(showFavorites: true),
    const LocationsPage(),
    const PartiesPage(),
  ];

  final List<String> _titles = [
    'Recentes',
    'Fixados',
    'Locais',
    'Festas',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _pages.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Termo Fraude"),
          content: const SingleChildScrollView(
            child: Text(
              "Texto Fraude",
              textAlign: TextAlign.justify,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabController.index]),
        actions: [],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.chat)),
            Tab(icon: Icon(Icons.push_pin)),
            Tab(icon: Icon(Icons.location_on)),
            Tab(icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(),
          Container(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 25),
            child: GestureDetector(
              onTap: showPrivacyPolicyDialog,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined),
                  const SizedBox(width: 4),
                  const Text("Proteja-se"),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Segurança Online e Prevenção contra Fraude",
                      style: TextStyle(
                        color: Colors.blue,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
