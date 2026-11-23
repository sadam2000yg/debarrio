import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../pedidos/presentation/carrito_screen.dart';
import '../../pedidos/presentation/carrito_provider.dart';
import '../../pedidos/presentation/mis_compras_screen.dart';
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
  final GlobalKey<NavigatorState> _explorarNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final tab = auth.vecinoTabInicial;
    if (tab > 0 && tab < 4) {
      _currentIndex = tab;
      auth.consumirTabInicial();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExplorarProvider>().inicializarUbicacionYBuscar(auth.userProfile);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_currentIndex == 0 && (_explorarNavKey.currentState?.canPop() ?? false)) {
          _explorarNavKey.currentState!.pop();
        } else if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            Navigator(
              key: _explorarNavKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => const ExplorarScreen(),
                  settings: settings,
                );
              },
            ),
            const CarritoScreen(),
            const MisComprasScreen(),
            const PerfilSwitchScreen(esPestana: true),
          ],
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
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.explore, color: AppTheme.primaryButton),
              label: 'Explorar',
            ),
            NavigationDestination(
              icon: Consumer<CarritoProvider>(
                builder: (context, carrito, child) {
                  return Badge.count(
                    count: carrito.cantidadTotalItems,
                    isLabelVisible: carrito.cantidadTotalItems > 0,
                    child: const Icon(Icons.shopping_cart, color: AppTheme.primaryButton),
                  );
                },
              ),
              label: 'Carrito',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt, color: AppTheme.primaryButton),
              label: 'Mis Compras',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person, color: AppTheme.primaryButton),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
