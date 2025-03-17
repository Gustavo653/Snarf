import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snarf/components/loading_elevated_button.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class StatusSubscriptionPage extends StatefulWidget {
  const StatusSubscriptionPage({super.key});

  @override
  State<StatusSubscriptionPage> createState() => _StatusSubscriptionPageState();
}

class _StatusSubscriptionPageState extends State<StatusSubscriptionPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  bool _isLoading = true;
  bool _hasActiveSubscription = false;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  int _extraVideoCallMinutes = 0;

  @override
  void initState() {
    super.initState();
    _listenToPurchaseStream();
    _initPage();
  }

  Future<void> _initPage() async {
    await _retrieveUserInfo();
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

  void _listenToPurchaseStream() {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (purchaseDetailsList) {
        setState(() {
          _hasActiveSubscription = purchaseDetailsList.any(
            (purchase) =>
                ApiConstants.subscriptionId == purchase.productID &&
                (purchase.status == PurchaseStatus.purchased ||
                    purchase.status == PurchaseStatus.restored),
          );
        });
      },
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) {
        debugPrint('Erro na stream de compras: $error');
      },
    );
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
    } else {
      debugPrint('Plataforma não suportada para gerenciamento de assinatura.');
      return;
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint(
          'Não foi possível abrir a URL de gerenciamento de assinaturas');
    }
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
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Você possui uma assinatura ativa do Snarf Plus!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                LoadingElevatedButton(
                  onPressed: _manageSubscription,
                  isLoading: false,
                  text: 'Gerenciar Assinatura',
                ),
                const SizedBox(height: 24),
                const Divider(),
                Text(
                  'Você comprou no total $_extraVideoCallMinutes minutos de video chamada.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : const Center(
              child: Text(
                'Você não possui assinatura ativa.',
                style: TextStyle(fontSize: 16),
              ),
            ),
    );
  }
}
