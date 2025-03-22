import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';

import 'package:snarf/components/call_overlay.dart';
import 'package:snarf/providers/call_manager.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/auth_checker.dart';
import 'package:snarf/services/signalr_manager.dart';

import 'utils/api_constants.dart';
import 'utils/app_themes.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebase();
  _setupErrorHandling();
  await _checkForInAppUpdate();
  await _setupFirebaseMessaging();
  _configureApiConstants();
  await _initializeSignalR();
  final configProvider = ConfigProvider();
  _initializeSubscription(configProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigProvider>(
          create: (_) => configProvider,
        ),

        ChangeNotifierProxyProvider<ConfigProvider, CallManager>(
          create: (context) => CallManager(context.read<ConfigProvider>()),
          update: (context, config, previous) => CallManager(config),
        ),
      ],
      child: const SnarfApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp();
}

void _setupErrorHandling() {
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
  };

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
    return true;
  };
}

Future<void> _checkForInAppUpdate() async {
  try {
    final updateInfo = await InAppUpdate.checkForUpdate();
    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      if (updateInfo.immediateUpdateAllowed) {
        final appUpdateResult = await InAppUpdate.performImmediateUpdate();
        if (appUpdateResult == AppUpdateResult.success) {}
      } else if (updateInfo.flexibleUpdateAllowed) {
        final appUpdateResult = await InAppUpdate.startFlexibleUpdate();
        if (appUpdateResult == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    }
  } catch (e) {}
}

Future<void> _setupFirebaseMessaging() async {
  await FirebaseMessaging.instance.requestPermission(provisional: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

void _configureApiConstants() {
  const isRelease = bool.fromEnvironment('dart.vm.product');
  ApiConstants.baseUrl =
      isRelease ? "https://snarf.inovitech.inf.br/api" : ApiConstants.baseUrl;
}

Future<void> _initializeSignalR() async {
  await SignalRManager().initializeConnection();
}

void _initializeSubscription(ConfigProvider configProvider) {
  final InAppPurchase inAppPurchase = InAppPurchase.instance;

  final purchaseUpdates = inAppPurchase.purchaseStream;
  purchaseUpdates.listen((purchases) {
    _processPurchaseUpdates(purchases, configProvider);
  });

  inAppPurchase.restorePurchases();
}

void _processPurchaseUpdates(
  List<PurchaseDetails> purchases,
  ConfigProvider configProvider,
) {
  for (var purchase in purchases) {
    if (purchase.productID == ApiConstants.subscriptionId) {
      if (purchase.status == PurchaseStatus.restored ||
          purchase.status == PurchaseStatus.purchased) {
        configProvider.setIsSubscriber(true);
        return;
      } else {
        configProvider.setIsSubscriber(false);
        return;
      }
    }
  }

  configProvider.setIsSubscriber(false);
}

class SnarfApp extends StatelessWidget {
  const SnarfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ConfigProvider>(context);

    return MaterialApp(
      title: 'snarf',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            CallOverlay(),
          ],
        );
      },
      home: const AuthChecker(),
    );
  }
}
