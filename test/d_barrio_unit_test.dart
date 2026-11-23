import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:d_barrio/core/utils/validadores.dart';
import 'package:d_barrio/features/negocio/domain/producto.dart';
import 'package:d_barrio/features/auth/domain/user_profile.dart';
import 'package:d_barrio/features/auth/domain/negocio.dart';
import 'package:d_barrio/features/auth/presentation/auth_provider.dart';
import 'package:d_barrio/features/negocio/presentation/catalogo_provider.dart';
import 'package:d_barrio/features/explorar/presentation/explorar_provider.dart';
import 'package:d_barrio/features/auth/presentation/login_screen.dart';
import 'package:d_barrio/features/profile/presentation/perfil_switch_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test-key',
      );
    }
  });

  group('Validadores Tests', () {
    test('Validar Email correcto e incorrecto', () {
      expect(Validadores.validarEmail('test@correo.com'), isNull);
      expect(Validadores.validarEmail('  TEST@CORREO.COM  '), isNull);
      expect(Validadores.validarEmail('correo-invalido'), isNotNull);
      expect(Validadores.validarEmail(''), isNotNull);
      expect(Validadores.validarEmail(null), isNotNull);
    });

    test('Validar Password (mínimo 8 caracteres)', () {
      expect(Validadores.validarPassword('12345678'), isNull);
      expect(Validadores.validarPassword('passwordseguro'), isNull);
      expect(Validadores.validarPassword('1234567'), isNotNull);
      expect(Validadores.validarPassword(''), isNotNull);
    });

    test('Validar C.I. y Teléfono', () {
      expect(Validadores.validarCi('1234567'), isNull);
      expect(Validadores.validarCi('123'), isNotNull);
      expect(Validadores.validarTelefono('70000000'), isNull);
      expect(Validadores.validarTelefono('123'), isNotNull);
    });

    test('Parsear Decimal (admite coma y punto)', () {
      expect(Validadores.parsearDecimal('3.50'), 3.5);
      expect(Validadores.parsearDecimal('3,50'), 3.5);
      expect(Validadores.parsearDecimal('10'), 10.0);
      expect(Validadores.parsearDecimal('abc'), isNull);
      expect(Validadores.parsearDecimal(''), isNull);
    });
  });

  group('UserProfile Domain Tests', () {
    test('UserProfile con 4 URLs KYC y rol por defecto VECINO', () {
      final profile = UserProfile(
        id: 'usr-1',
        email: 'vecino@correo.com',
        nombre: 'Juan Perez',
        ci: '1234567',
        telefono: '70000000',
        selfieUrl: 'selfie.jpg',
        facadeUrl: 'facade.jpg',
        ciAnversoUrl: 'anverso.jpg',
        ciReversoUrl: 'reverso.jpg',
        lat: -16.5,
        lng: -68.15,
        activeRole: 'VECINO',
      );

      expect(profile.activeRole, 'VECINO');
      expect(profile.selfieUrl, isNotEmpty);
      expect(profile.facadeUrl, isNotEmpty);
      expect(profile.ciAnversoUrl, isNotEmpty);
      expect(profile.ciReversoUrl, isNotEmpty);
    });
  });

  group('Producto Domain Tests (Galería y Baja Lógica)', () {
    test('Producto galería 1-5 fotos, eliminado, stock y 4 etiquetas de disponibilidad', () {
      final producto = Producto(
        id: 'prod-1',
        negocioId: 'neg-1',
        nombre: 'Empanada',
        descripcion: 'Rica',
        fotosUrls: ['foto1.jpg', 'foto2.jpg', 'foto3.jpg'],
        precio: 5.00,
        tipoInventario: 'UNICO',
        stockDisponible: 1,
        stockReservado: 0,
        stockBaseDiario: 1,
        activo: true,
        vendidoUnico: false,
        eliminado: false,
      );

      expect(producto.fotosUrls.length, 3);
      expect(producto.fotoUrl, 'foto1.jpg');
      expect(producto.estaDisponible, isTrue);
      expect(producto.etiquetaDisponibilidad, 'Disponible');

      // Agotado: RECURRENTE con stock 0
      final productoAgotado = producto.copyWith(
        tipoInventario: 'RECURRENTE',
        stockDisponible: 0,
      );
      expect(productoAgotado.etiquetaDisponibilidad, 'Agotado');

      // Vendido: UNICO con stock 0 y vendidoUnico: true
      final productoVendido = producto.copyWith(
        tipoInventario: 'UNICO',
        stockDisponible: 0,
        vendidoUnico: true,
      );
      expect(productoVendido.etiquetaDisponibilidad, 'Vendido');

      // Eliminado: eliminado: true
      final productoEliminado = producto.copyWith(eliminado: true);
      expect(productoEliminado.estaDisponible, isFalse);
      expect(productoEliminado.etiquetaDisponibilidad, 'Eliminado');
    });
  });

  group('Negocio Domain Tests (Autocompra y Delivery)', () {
    test('Validación de negocio y detección de autocompra', () {
      final negocio = Negocio(
        id: 'neg-1',
        ownerId: 'owner-123',
        nombre: 'Doña Carmen',
        descripcion: 'Salteñas',
        lat: -16.5,
        lng: -68.15,
        storePhotoUrl: 'store.jpg',
        qrPhotoUrl: 'qr.jpg',
        deliveryOptions: ['DELIVERY_PROPIO', 'RECOJO_LOCAL'],
        shippingCost: 500,
        abierto: true,
        categoria: 'Comida',
      );

      expect(negocio.deliveryOptions.contains('DELIVERY_PROPIO'), isTrue);
      expect(negocio.shippingCost, 500);

      final currentUserId = 'owner-123';
      final bool esMiPropioPuesto = negocio.ownerId == currentUserId;
      expect(esMiPropioPuesto, isTrue);
    });
  });

  group('Widget Tests', () {
    testWidgets('LoginScreen renderiza correctamente en viewport (360x640)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
                ChangeNotifierProvider(create: (_) => CatalogoProvider()),
                ChangeNotifierProvider(create: (_) => ExplorarProvider()),
              ],
              child: const LoginScreen(),
            ),
          ),
        ),
      );

      expect(find.text("¡Bienvenido a D'BARRIO!"), findsOneWidget);
    });

    testWidgets('PerfilSwitchScreen renderiza correctamente en viewport (360x640)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
                ChangeNotifierProvider(create: (_) => CatalogoProvider()),
                ChangeNotifierProvider(create: (_) => ExplorarProvider()),
              ],
              child: const PerfilSwitchScreen(esPestana: true),
            ),
          ),
        ),
      );

      expect(find.text('Modo Emprendedor'), findsOneWidget);
    });
  });
}
