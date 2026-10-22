import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/pos_main_screen.dart';
import 'ui/core/app_colors.dart';

import 'data/services/printer/printer_settings.dart';
import 'data/services/printer/printer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[POS-CRASH-HANDLER] FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[POS-CRASH-HANDLER] Uncaught error prevented from exiting app: $error\n$stack');
    return true; // Prevents process termination
  };

  // Lock orientation to Landscape for tablet deployment (Samsung Galaxy Tab A9)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final initialPrinterSettings = await PrinterSettings.load();

  runApp(
    ProviderScope(
      overrides: [
        printerServiceProvider.overrideWith((ref) => PrinterService(initialPrinterSettings)),
      ],
      child: const OdooJuicePosApp(),
    ),
  );
}

class OdooJuicePosApp extends StatelessWidget {
  const OdooJuicePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AraPOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.arawaliRed,
          primary: AppColors.deepSlate,
          secondary: AppColors.sunYellow,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: const PosMainScreen(),
    );
  }
}
