import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sksrc.dart';
import 'auth/auth_gate.dart';

// Theme system
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const CorvusAeternumApp());
}

class CorvusAeternumApp extends StatelessWidget {
  const CorvusAeternumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Corvus Aeternum',
          debugShowCheckedModeBanner: false,

          // ✅ Theme dinámico (arranca con default y cambia cuando AuthGate aplique la conspiración)
          theme: AppTheme.build(skin: themeController.skin),

          home: const AuthGate(),
        );
      },
    );
  }
}
