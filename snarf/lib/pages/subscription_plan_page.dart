import 'dart:async';
import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/subscriptiob_base_plan_details.dart';

const List<String> _kSubscriptionIds = <String>[
  'snarf_plus',
];

const String _kConsumableId = '5_minutos_video_chamada';

class SubscriptionPlanPage extends StatefulWidget {
  const SubscriptionPlanPage({super.key});

  @override
  State<SubscriptionPlanPage> createState() => _SubscriptionPlanPageState();
}

class _SubscriptionPlanPageState extends State<SubscriptionPlanPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  bool _isStoreAvailable = false;
  bool _isLoading = true;

  List<ProductDetails> _products = [];
  List<SubscriptionBasePlanDetails> _subscriptionBasePlans = [];
  List<PurchaseDetails> _purchases = [];

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
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('Erro na stream de compras: $error');
      },
    );

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
      ..._kSubscriptionIds,
      _kConsumableId,
    };

    final response = await _inAppPurchase.queryProductDetails(idsParaConsultar);

    if (response.error != null) {
      debugPrint('Erro ao consultar produtos: ${response.error}');
      FirebaseCrashlytics.instance.recordError(response.error, null);
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IDs não encontrados: ${response.notFoundIDs}');
      _analytics.logEvent(name: 'product_not_found', parameters: {
        'ids': response.notFoundIDs.join(', '),
      });
    }

    final subscriptionProducts = response.productDetails
        .where((product) => _kSubscriptionIds.contains(product.id))
        .toList();

    final subscriptionBasePlans = subscriptionProducts
        .map((product) => SubscriptionBasePlanDetails(product))
        .toList();

    setState(() {
      _products = response.productDetails;
      _subscriptionBasePlans = subscriptionBasePlans;
      _isLoading = false;
    });
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

        if (purchase.productID == _kConsumableId) {
          _handleExtraMinutesPurchase(purchase);
        }
      }

      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }

    setState(() {
      _purchases = purchaseDetailsList;
    });
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
        log('Minutos adicionados com sucesso no servidor.');
        _analytics.logEvent(name: 'extra_minutes_added', parameters: {
          'product_id': purchase.productID,
          'minutes': purchasedMinutes,
        });
      } else {
        log('Falha ao adicionar minutos: $result');
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }
  }

  void _buySubscription(SubscriptionBasePlanDetails plan) {
    _analytics.logEvent(name: 'purchase_attempt', parameters: {
      'product_id': plan.productDetails.id,
    });
    final purchaseParam = PurchaseParam(
      productDetails: plan.productDetails,
    );
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
    if (!_isStoreAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assinaturas e Compras')),
        body: const Center(
          child: Text(
            'A loja não está disponível. Verifique conexão ou configuração.',
          ),
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
        _products.where((p) => p.id == _kConsumableId).toList();

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
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(plan.basePlanId ?? plan.subscriptionId),
                  subtitle: Text(
                    'Duração: ${plan.basePlanLength?.name ?? 'Indefinida'}\n'
                    'Trial: ${plan.isFreeTrialAvailable! ? 'Sim' : 'Não'}',
                  ),
                  trailing: Text(plan.formattedPrice),
                  onTap: () => _buySubscription(plan),
                ),
              );
            })
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Nenhuma assinatura encontrada.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Produtos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (consumableProducts.isNotEmpty)
            ...consumableProducts.map((product) {
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(product.title),
                  subtitle: Text(product.description),
                  trailing: Text(product.price),
                  onTap: () => _buyConsumable(product),
                ),
              );
            }).toList()
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Nenhum produto avulso encontrado.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
