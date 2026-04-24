// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase init — uncomment in Phase 9
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PresensiApp());
}

class PresensiApp extends StatelessWidget {
  const PresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkAuth(),
      child : Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final router       = createRouter(authProvider);

          return MaterialApp.router(
            title                   : 'Presensi SKS',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A5F),
                primary  : const Color(0xFF1E3A5F),
              ),
              useMaterial3: true,
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}