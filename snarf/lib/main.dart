import 'dart:developer';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/call_manager.dart';
import 'package:snarf/providers/config_provider.dart';
import 'package:snarf/services/signalr_manager.dart';

import 'pages/account/initial_page.dart';
import 'pages/home_page.dart';
import 'services/api_service.dart';
import 'utils/api_constants.dart';
import 'utils/app_themes.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('Mensagem recebida em background: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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

  InAppUpdate.checkForUpdate().then((updateInfo) {
    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      if (updateInfo.immediateUpdateAllowed) {
        InAppUpdate.performImmediateUpdate().then((appUpdateResult) {
          if (appUpdateResult == AppUpdateResult.success) {}
        });
      } else if (updateInfo.flexibleUpdateAllowed) {
        InAppUpdate.startFlexibleUpdate().then((appUpdateResult) {
          if (appUpdateResult == AppUpdateResult.success) {
            InAppUpdate.completeFlexibleUpdate();
          }
        });
      }
    }
  });

  await FirebaseMessaging.instance.requestPermission(provisional: true);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  configureApiConstants();
  await SignalRManager().initializeConnection();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CallManager>(
          create: (_) => CallManager(),
        ),
        ChangeNotifierProvider<ConfigProvider>(
          create: (_) => ConfigProvider(),
        ),
      ],
      child: const SnarfApp(),
    ),
  );
}

void configureApiConstants() {
  const isRelease = bool.fromEnvironment('dart.vm.product');
  ApiConstants.baseUrl =
      isRelease ? "https://snarf.inovitech.inf.br/api" : ApiConstants.baseUrl;
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
            _CallOverlay(),
          ],
        );
      },
      home: const AuthChecker(),
    );
  }
}

class _CallOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CallManager>(
      builder: (context, callManager, child) {
        if (callManager.isCallOverlayVisible && !callManager.isInCall) {
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: kToolbarHeight + 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Chamada recebida de ${callManager.incomingCallerName}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: callManager.acceptCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.call,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Atender",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: callManager.rejectCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Recusar",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  _AuthCheckerState createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  String? token;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final result = await ApiService.getToken();
      setState(() {
        token = result;
        isLoading = false;
      });
    } catch (error) {
      await FirebaseCrashlytics.instance.log("check_auth_error");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (token != null) {
      return const HomePage();
    } else {
      return const InitialPage();
    }
  }
}
