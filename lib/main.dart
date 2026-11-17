import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/negocio/presentation/catalogo_provider.dart';
import 'features/negocio/presentation/emprendedor_shell.dart';
import 'features/explorar/presentation/explorar_provider.dart';
import 'features/explorar/presentation/vecino_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://your-supabase-url.supabase.co',
    ),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'your-anon-key',
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..restaurarSesion(),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogoProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExplorarProvider(),
        ),
      ],
      child: const DBarrioApp(),
    ),
  );
}

class DBarrioApp extends StatelessWidget {
  const DBarrioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "D'BARRIO",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RootRouter(),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryButton),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    if (authProvider.activeRole == 'EMPRENDEDOR') {
      return const EmprendedorShell();
    } else {
      return const VecinoShell();
    }
  }
}
