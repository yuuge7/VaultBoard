import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/storage.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // All data lives in a local "VaultBoard" folder inside the platform's
  // application-documents directory. No network access anywhere in the app.
  await Hive.initFlutter('VaultBoard');
  await VaultStorage.init();
  runApp(const ProviderScope(child: VaultBoardApp()));
}

class VaultBoardApp extends StatelessWidget {
  const VaultBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaultBoard',
      debugShowCheckedModeBanner: false,
      theme: buildVaultTheme(),
      scrollBehavior: const DesktopScrollBehavior(),
      home: const HomeScreen(),
    );
  }
}
