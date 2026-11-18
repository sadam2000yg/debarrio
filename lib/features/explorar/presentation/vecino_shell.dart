import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../carrito/presentation/carrito_screen.dart';
import '../../carrito/presentation/mis_compras_screen.dart';
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
    const CarritoScreen(),
    const MisComprasScreen(),
    const PerfilSwitchScreen(esPestana: true),
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final tab = auth.vecinoTabInicial;
    if (tab > 0 && tab < _screens.length) {
      _currentIndex = tab;
      auth.consumirTabInicial();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
