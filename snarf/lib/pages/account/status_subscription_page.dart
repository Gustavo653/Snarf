import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snarf/components/consumable_purchase_component.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/pages/account/buy_subscription_page.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

class StatusSubscriptionPage extends StatefulWidget {
  const StatusSubscriptionPage({super.key});

  @override
  State<StatusSubscriptionPage> createState() => _StatusSubscriptionPageState();
}

class _StatusSubscriptionPageState extends State<StatusSubscriptionPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _isLoading = true;
  bool _hasActiveSubscription = false;
  int _extraVideoCallMinutes = 0;
  List<ProductDetails> _consumableProducts = [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _listenToPurchaseStream();
    _initPage();
  }

  Future<void> _initPage() async {
    await _retrieveUserInfo();
    await _queryConsumableProduct();
    await _restorePurchases();
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

  Future<void> _queryConsumableProduct() async {
    final available = await _inAppPurchase.isAvailable();
    if (!available) return;
    final response =
        await _inAppPurchase.queryProductDetails({ApiConstants.productId});
    if (response.productDetails.isNotEmpty) {
      setState(() {
        _consumableProducts = response.productDetails;
      });
    }
  }

  void _listenToPurchaseStream() {
    _purchaseSubscription =
        _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
      setState(() {
        _hasActiveSubscription = purchaseDetailsList.any(
          (purchase) =>
              purchase.productID == ApiConstants.subscriptionId &&
              (purchase.status == PurchaseStatus.purchased ||
                  purchase.status == PurchaseStatus.restored),
        );
      });
    }, onDone: () => _purchaseSubscription?.cancel(), onError: (_) {});
  }

  Future<void> _restorePurchases() async {
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      return;
    }
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _manageSubscription() async {
    String url = '';
    if (Platform.isAndroid) {
      const packageName = 'com.snarf.snarf';
      url =
          'https://play.google.com/store/account/subscriptions?sku=${ApiConstants.subscriptionId}&package=$packageName';
    } else if (Platform.isIOS) {
      url = 'itms-apps://apps.apple.com/account/subscriptions';
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _buyConsumable(ProductDetails productDetails) {
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Status da Assinatura'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status da Assinatura'),
      ),
      body: _hasActiveSubscription
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Você possui uma assinatura ativa do Snarf Plus!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LoadingElevatedButton(
                  onPressed: _manageSubscription,
                  isLoading: false,
                  text: 'Gerenciar Assinatura',
                ),
                const SizedBox(height: 24),
                ConsumablePurchaseComponent(
                  consumableProducts: _consumableProducts,
                  onBuyConsumable: _buyConsumable,
                  purchasedMinutes: _extraVideoCallMinutes,
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Você não possui assinatura ativa.',
                    style: TextStyle(fontSize: 16),
                  ),
                  LoadingElevatedButton(
                      text: 'Adquirir Assinatura',
                      isLoading: false,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BuySubscriptionPage(),
                          ),
                        );
                      })
                ],
              ),
            ),
    );
  }
}
