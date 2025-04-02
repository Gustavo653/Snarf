import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:snarf/pages/account/initial_page.dart';
import 'package:snarf/pages/home_page.dart';
import 'package:snarf/services/api_service.dart';

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
      FirebaseCrashlytics.instance
          .log("AuthChecker: Iniciando verificação do token...");

      final result = await ApiService.getToken();

      if (result != null && !JwtDecoder.isExpired(result)) {
        FirebaseCrashlytics.instance.log("AuthChecker: Token válido.");

        setState(() {
          token = result;
        });
      } else {
        FirebaseCrashlytics.instance
            .log("AuthChecker: Token ausente ou expirado.");

        setState(() {
          token = null;
        });
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    } finally {
      setState(() {
        isLoading = false;
      });

      FirebaseCrashlytics.instance.log("AuthChecker: Finalizado.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return token != null ? const HomePage() : const InitialPage();
  }
}
