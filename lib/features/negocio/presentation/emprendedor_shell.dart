import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../pedidos/presentation/comanda_screen.dart';
import '../../profile/presentation/perfil_switch_screen.dart';
import 'catalogo_provider.dart';
import 'mi_catalogo_screen.dart';
import 'mi_puesto_screen.dart';

class EmprendedorShell extends StatefulWidget {
  const EmprendedorShell({super.key});

  @override
  State<EmprendedorShell> createState() => _EmprendedorShellState();
}

class _EmprendedorShellState extends State<EmprendedorShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MiPuestoScreen(),
    const MiCatalogoScreen(),
    const ComandaScreen(),
    const PerfilSwitchScreen(esPestana: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userProfile != null) {
        context.read<CatalogoProvider>().cargarNegocioYProductos(auth.userProfile!.id);
      }
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
            icon: Icon(Icons.storefront, color: AppTheme.primaryButton),
            label: 'Mi Puesto',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu, color: AppTheme.primaryButton),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long, color: AppTheme.primaryButton),
            label: 'Comanda',
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
