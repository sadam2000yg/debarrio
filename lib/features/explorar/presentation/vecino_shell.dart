import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/presentation/perfil_switch_screen.dart';
import 'explorar_screen.dart';
import 'explorar_provider.dart';
import '../../auth/presentation/auth_provider.dart';

class VecinoShell extends StatefulWidget {
  const VecinoShell({super.key});

  @override
  State<VecinoShell> createState() => _VecinoShellState();
}

class _VecinoShellState extends State<VecinoShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ExplorarScreen(),
    const _CarritoPlaceholderScreen(),
    const _MisComprasPlaceholderScreen(),
    const PerfilSwitchScreen(esPestana: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ExplorarProvider>().inicializarUbicacionYBuscar(auth.userProfile);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        height: 65,
        backgroundColor: AppTheme.white,
        indicatorColor: AppTheme.containers,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore, color: AppTheme.primaryButton),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart, color: AppTheme.primaryButton),
            label: 'Carrito',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt, color: AppTheme.primaryButton),
            label: 'Mis Compras',
          ),
          NavigationDestination(
            icon: Icon(Icons.person, color: AppTheme.primaryButton),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _CarritoPlaceholderScreen extends StatelessWidget {
  const _CarritoPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Carrito mononegocio — Próximo Sprint 3',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppTheme.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _MisComprasPlaceholderScreen extends StatelessWidget {
  const _MisComprasPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Compras', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Seguimiento de pedidos en vivo — Próximo Sprint 3/4',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppTheme.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
