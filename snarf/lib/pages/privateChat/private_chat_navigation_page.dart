import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/privateChat/locations_page.dart';
import 'package:snarf/pages/privateChat/parties_page.dart';
import 'package:snarf/pages/privateChat/recent_page.dart';
import 'package:snarf/providers/config_provider.dart';

class PrivateChatNavigationPage extends StatefulWidget {
  final ScrollController scrollController;

  const PrivateChatNavigationPage({super.key, required this.scrollController});

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
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: configProvider.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: configProvider.secondaryColor,
              width: 2,
            ),
          ),
          title: Text(
            "Conscientização de Fraude",
            style: TextStyle(color: configProvider.textColor),
          ),
          content: SingleChildScrollView(
            child: Text(
              "Proteja-se contra extorsão, roubo de identidade e fraude de cartão de crédito.\n\n"
              "O Snarf possui várias ferramentas para deter golpistas, mas também precisamos da sua ajuda.\n\n"
              "Como regra geral:\n"
              "    • Nunca acesse um link que alguém te enviar em uma mensagem.\n"
              "    • Nunca forneça seu número de telefone ou outras informações confidenciais.\n\n"
              "Golpes comuns\n"
              "Existem vários truques comuns que os golpistas usam para enganar as pessoas. Um fraudador, spammer ou golpista é qualquer pessoa que tenta obter informações confidenciais suas, induzi-lo a dar dinheiro a eles ou enganá-lo para fazer algo em benefício deles.\n\n"
              "Sinais de que alguém está tentando te enganar:\n"
              "    • Tentam levar a conversa para outro lugar, por exemplo:\n"
              "        ◦ Pedem seu número de telefone, endereço de e-mail ou nome de usuário de mídia social.\n"
              "        ◦ Te dão o número de telefone deles e pedem para você enviar uma mensagem de texto.\n"
              "        ◦ Pedem para você acessar um link externo.\n"
              "    • Usam caracteres especiais e intencionalmente escrevem palavras erradas para evitar filtros de spam (por exemplo: 'm@ss@ge').\n"
              "    • Oferecem serviços como massagem ou outros e querem que você marque uma consulta em outro site.\n"
              "    • Pedem para você comprar cartões-presente e enviar o código do verso.\n"
              "    • Se apresentam como um administrador do Snarf e pedem para você realizar uma ação ou ameaçam denunciar sua conta para te assustar e te tirar da plataforma.\n"
              "    • Combinam um ou mais dos itens acima e ainda têm uma foto de perfil que parece boa demais para ser verdade.\n\n"
              "O que fazer se identificar um golpe?\n"
              "Se alguém te enviar mensagens usando qualquer uma dessas estratégias, é melhor não responder e bloquear ou denunciar o perfil imediatamente.\n\n"
              "O Snarf possui várias ferramentas para ajudar a combater spam e contas falsas, mas também precisamos da sua ajuda. Spammers só ficam por perto se conseguirem o que procuram.",
              style: TextStyle(color: configProvider.textColor),
              textAlign: TextAlign.justify,
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: configProvider.secondaryColor,
                  width: 1,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Fechar",
                style: TextStyle(color: configProvider.textColor),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);

    return PopScope(
      child: Scaffold(
        backgroundColor: configProvider.primaryColor,
        appBar: AppBar(
          backgroundColor: configProvider.primaryColor,
          iconTheme: IconThemeData(color: configProvider.iconColor),
          title: Text(
            _titles[_tabController.index],
            style: TextStyle(color: configProvider.textColor),
          ),
          automaticallyImplyLeading: false,
          bottom: TabBar(
            controller: _tabController,
            labelColor: configProvider.iconColor,
            unselectedLabelColor: configProvider.textColor.withOpacity(0.7),
            indicatorColor: configProvider.secondaryColor,
            tabs: [
              Tab(
                icon: Icon(
                  Icons.chat_bubble,
                  color: configProvider.iconColor,
                ),
              ),
              Tab(
                icon: Icon(
                  Icons.push_pin,
                  color: configProvider.iconColor,
                ),
              ),
              Tab(
                icon: Icon(
                  Icons.location_on,
                  color: configProvider.iconColor,
                ),
              ),
              Tab(
                icon: Icon(
                  Icons.people,
                  color: configProvider.iconColor,
                ),
              ),
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
            Divider(color: configProvider.secondaryColor),
            Container(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 25),
              child: GestureDetector(
                onTap: showPrivacyPolicyDialog,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: configProvider.iconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Proteja-se",
                      style: TextStyle(
                        color: configProvider.textColor,
                      ),
                    ),
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
      ),
    );
  }
}
