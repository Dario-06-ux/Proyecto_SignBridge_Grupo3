import 'package:flutter/material.dart';
// Importamos Riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importamos nuestros archivos locales
import 'core/theme/app_theme.dart';
import 'core/theme/presentation/main_navigator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ProviderScope es OBLIGATORIO para que Riverpod funcione en la app
  runApp(
    const ProviderScope(
      child: SignBridgeApp(),
    ),
  );
}

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignBridge AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainNavigator(),
    );
  }
}