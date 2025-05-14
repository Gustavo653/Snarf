import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';

class ConfigProfilePreferencesPage extends StatefulWidget {
  const ConfigProfilePreferencesPage({super.key});

  @override
  State<ConfigProfilePreferencesPage> createState() => _ConfigProfilePreferencesPage();
}

class _ConfigProfilePreferencesPage extends State<ConfigProfilePreferencesPage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  double get _opacity {
    const double startFade = 0;
    const double endFade = 300;
    if (_scrollOffset <= startFade) return 1.0;
    if (_scrollOffset >= endFade) return 0.0;
    return 1.0 - ((_scrollOffset - startFade) / (endFade - startFade));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: _opacity,
              child: Image.asset(
                'assets/photo1.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Conteúdo com scroll
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                setState(() {
                  _scrollOffset = _scrollController.offset;
                });
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.81),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.straighten, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '18, 132cm, 40kg, hétero-curioso, passivo submisso',
                                style: TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.person_pin_circle_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Tenho um buraco de glória',
                                style: TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis, 
                                maxLines: 1,  
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _infoSection('Localização', ['Com local']),
                        const SizedBox(height: 12),
                        _infoSection('Interação', ['Anônimo', 'Gozar e ir', 'Edging']),
                        const SizedBox(height: 12),
                        _infoSection('Status do HIV', ['Negativo']),
                        const SizedBox(height: 12),
                        _infoSection('Testado para HIV', ['May 5, 2025']),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          Positioned(
            top: kToolbarHeight + 56,
            right: 16,
            child: Opacity(
              opacity: _opacity,
              child: Column(
                children: List.generate(4, (index) {
                  return ProfileAvatarWidget(
                    imagePath: 'assets/photo${index + 1}.png',
                    onRemove: () {
                      
                    },
                    onUpdate: () {
                      
                    },
                  );
                }),
              ),
            ),
          ),

          // TopBar fixa
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: kToolbarHeight + 24,
              padding: const EdgeInsets.only(top: 24, left: 8, right: 8),
              color: const Color(0xFF0A0F1C),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Cruiser Verificado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Flexible(
                          child: Text(
                            '18, 132cm, 40kg, hétero-curioso, passivo submisso',
                             style: TextStyle(color: Colors.white70, fontSize: 12),
                             overflow: TextOverflow.ellipsis,
                             maxLines: 1),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<String> values) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: values
              .map((v) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(v, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
        )
      ],
    );
  }
}

class ProfileAvatarWidget extends StatelessWidget {
  final String imagePath;
  final VoidCallback onRemove;
  final VoidCallback onUpdate;

  const ProfileAvatarWidget({
    super.key,
    required this.imagePath,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF111827),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            left: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8AE360),
              ),
              child: const Icon(Icons.check, size: 15, color: Colors.black),
            ),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0F1C),
                ),
                child: const Icon(Icons.remove, size: 15, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onUpdate,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0F1C),
                ),
                child: const Icon(Icons.refresh, size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}