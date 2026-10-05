import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Added for AdMob

import 'providers/game_provider.dart';
import 'providers/multiplayer_game_provider.dart'; // Added Multiplayer provider
import 'providers/store_provider.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob SDK
  await MobileAds.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => MultiplayerGameProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
      ],
      child: const BatakApp(),
    ),
  );
}

class BatakApp extends StatelessWidget {
  const BatakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Likya Batak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      // Uygulama Likya Studios açılış ekranıyla başlar
      home: const SplashScreen(),
    );
  }
}
