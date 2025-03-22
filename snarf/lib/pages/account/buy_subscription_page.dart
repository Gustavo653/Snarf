import 'dart:async';
import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/consumable_purchase_component.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/subscription_base_plan_details.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class BuySubscriptionPage extends StatefulWidget {
  const BuySubscriptionPage({Key? key}) : super(key: key);

  @override
  State<BuySubscriptionPage> createState() => _BuySubscriptionPageState();
}

class _BuySubscriptionPageState extends State<BuySubscriptionPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _isStoreAvailable = false;
  bool _isLoading = true;
  List<ProductDetails> _products = [];
  List<SubscriptionBasePlanDetails> _subscriptionBasePlans = [];
  int _extraVideoCallMinutes = 0;

  final List<Map<String, dynamic>> benefits = [
    {"icon": FontAwesomeIcons.ban, "text": "Desbloquear Usuários Individuais"},
    {
      "icon": FontAwesomeIcons.solidMessage,
      "text": "Ver quem excluiu uma conversa"
    },
    {"icon": FontAwesomeIcons.googlePlay, "text": "Sem anúncios"},
    {"icon": FontAwesomeIcons.filter, "text": "Perfis de Cruisers Ilimitados"},
    {"icon": FontAwesomeIcons.bullhorn, "text": "Publique uma Atualização"},
    {"icon": FontAwesomeIcons.images, "text": "Várias fotos de perfil"},
    {
      "icon": FontAwesomeIcons.thumbtack,
      "text": "Fixar conversas e fixar para mais tarde"
    },
    {"icon": FontAwesomeIcons.eye, "text": "Recibos de Leitura"},
    {"icon": FontAwesomeIcons.userGroup, "text": "Criar Grupals"},
    {"icon": FontAwesomeIcons.image, "text": "Ocultar Fotos do Chat"},
    {"icon": FontAwesomeIcons.plane, "text": "Modo Viagem"},
    {"icon": FontAwesomeIcons.eyeSlash, "text": "Modo Discreto"},
    {"icon": FontAwesomeIcons.mapMarkerAlt, "text": "Adicionar Locais"},
    {"icon": FontAwesomeIcons.mask, "text": "Check-ins anônimos"},
    {"icon": FontAwesomeIcons.video, "text": "Chamada de vídeo"},
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    _analytics.logEvent(name: 'initialize_store');
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(_onPurchaseUpdate,
        onDone: () => _subscription.cancel(), onError: (error) {});
    final isAvailable = await _inAppPurchase.isAvailable();
    setState(() {
      _isStoreAvailable = isAvailable;
    });
    if (!isAvailable) {
      _analytics.logEvent(name: 'store_unavailable');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final idsParaConsultar = <String>{
      ApiConstants.subscriptionId,
      ApiConstants.productId,
    };
    final response = await _inAppPurchase.queryProductDetails(idsParaConsultar);
    if (response.error != null) {
      FirebaseCrashlytics.instance.recordError(response.error, null);
    }
    if (response.notFoundIDs.isNotEmpty) {
      _analytics.logEvent(name: 'product_not_found', parameters: {
        'ids': response.notFoundIDs.join(', '),
      });
    }
    final subscriptionProducts = response.productDetails
        .where((p) => p.id == ApiConstants.subscriptionId)
        .toList();
    final subscriptionBasePlans = subscriptionProducts
        .map((p) => SubscriptionBasePlanDetails(p))
        .toList();
    setState(() {
      _products = response.productDetails;
      _subscriptionBasePlans = subscriptionBasePlans;
    });
    await _retrieveUserInfo();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _retrieveUserInfo() async {
    final userId = await ApiService.getUserIdFromToken();
    if (userId != null) {
      final userInfo = await ApiService.getUserInfoById(userId);
      if (userInfo != null && userInfo.containsKey('extraVideoCallMinutes')) {
        setState(() {
          _extraVideoCallMinutes = userInfo['extraVideoCallMinutes'] ?? 0;
        });
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      _analytics.logEvent(name: 'purchase_updated', parameters: {
        'product_id': purchase.productID,
        'status': purchase.status.toString(),
      });
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        log('Compra/assinatura aprovada: ${purchase.productID}');
        if (purchase.productID == ApiConstants.productId) {
          _handleExtraMinutesPurchase(purchase);
        }
      }
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _handleExtraMinutesPurchase(PurchaseDetails purchase) async {
    try {
      final purchasedMinutes = 5;
      final result = await ApiService.addExtraMinutes(
        minutes: purchasedMinutes,
        subscriptionId: purchase.productID,
        tokenFromPurchase: purchase.verificationData.serverVerificationData,
      );
      if (result == null) {
        _analytics.logEvent(name: 'extra_minutes_added', parameters: {
          'product_id': purchase.productID,
          'minutes': purchasedMinutes,
        });
        setState(() {
          _extraVideoCallMinutes += purchasedMinutes;
        });
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }
  }

  void _buySubscription(SubscriptionBasePlanDetails plan) {
    _analytics.logEvent(name: 'purchase_attempt', parameters: {
      'product_id': plan.productDetails.id,
    });
    final purchaseParam = PurchaseParam(productDetails: plan.productDetails);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _buyConsumable(ProductDetails productDetails) {
    _analytics.logEvent(name: 'purchase_attempt', parameters: {
      'product_id': productDetails.id,
    });
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);

    if (!_isStoreAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assinaturas e Compras')),
        body: const Center(
          child: Text(
              'A loja não está disponível. Verifique conexão ou configuração.'),
        ),
      );
    }
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assinaturas e Compras')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final consumableProducts =
        _products.where((p) => p.id == ApiConstants.productId).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snarf Plus e Video Chamada'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Assinaturas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_subscriptionBasePlans.isNotEmpty)
            ..._subscriptionBasePlans.map((plan) {
              return Card(
                color: configProvider.secondaryColor,
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                    'Duração: ${plan.getBasePlanLengthTranslated()}\nTeste grátis: ${plan.isFreeTrialAvailable == true ? 'Sim' : 'Não'}',
                    style: TextStyle(color: configProvider.textColor),
                  ),
                  trailing: Text(
                    plan.formattedPrice,
                    style: TextStyle(color: configProvider.textColor),
                  ),
                  onTap: () => _buySubscription(plan),
                ),
              );
            })
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhuma assinatura encontrada.',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Aqui está tudo o que você receberá...",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Column(
                children: benefits.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(item["icon"], size: 20, color: Colors.blueAccent),
                        SizedBox(width: 10),
                        Text(item["text"], style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Produtos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ConsumablePurchaseComponent(
            consumableProducts: consumableProducts,
            onBuyConsumable: _buyConsumable,
            purchasedMinutes: _extraVideoCallMinutes,
          ),
        ],
      ),
    );
  }
}
