import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:d_barrio/features/pedidos/domain/pedido.dart';
import 'package:d_barrio/features/pedidos/domain/resena.dart';
import 'package:d_barrio/features/pedidos/presentation/pedido_history_filters.dart';
import 'package:d_barrio/features/profile/presentation/perfil_switch_screen.dart';
import 'package:d_barrio/services/nominatim_service.dart';
import 'package:d_barrio/core/utils/moderacion.dart';

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

    test('mantiene separadas la foto pública y la selfie KYC', () {
      final profile = UserProfile.fromMap({
        'id': 'usr-1',
        'selfie_url': 'kyc_docs/usr-1/selfie.jpg',
        'avatar_path': 'usr-1/avatar.jpg',
      });

      expect(profile.selfieUrl, 'kyc_docs/usr-1/selfie.jpg');
      expect(profile.avatarPath, 'usr-1/avatar.jpg');
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

      // Agotado 2: activo: false y stockDisponible > 0
      final productoInactivoAgotado = producto.copyWith(
        activo: false,
        stockDisponible: 5,
      );
      expect(productoInactivoAgotado.etiquetaDisponibilidad, 'Agotado');

      // Vendido: UNICO con stock 0 y vendidoUnico: true
      final productoVendido = producto.copyWith(
        tipoInventario: 'UNICO',
        stockDisponible: 0,
        vendidoUnico: true,
      );
      expect(productoVendido.etiquetaDisponibilidad, 'Vendido');

      // Vendido 2: UNICO con stock 0 (sin vendidoUnico explicito)
      final productoVendidoStockZero = producto.copyWith(
        tipoInventario: 'UNICO',
        stockDisponible: 0,
      );
      expect(productoVendidoStockZero.etiquetaDisponibilidad, 'Vendido');

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

  group('Pedido Domain Tests', () {
    test('filtra pedidos por nombre, texto, fecha, modalidad y estado', () {
      final fechaFiltro = DateTime(2026, 11, 26);
      final pedidoCoincidente = Pedido.fromMap({
        'id': 'pedido-1',
        'comprador_id': 'vecino-1',
        'negocio_id': 'negocio-1',
        'comprador_nombre': 'María López',
        'modalidad_entrega': 'DELIVERY',
        'estado': 'PAGO_EN_REVISION',
        'created_at': DateTime(2026, 11, 26, 17).toIso8601String(),
        'detalle_pedidos': [
          {'nombre_producto': 'Salteña'},
        ],
      });
      final pedidoExcluido = Pedido.fromMap({
        'id': 'pedido-2',
        'comprador_id': 'vecino-2',
        'negocio_id': 'negocio-1',
        'comprador_nombre': 'María López',
        'modalidad_entrega': 'RETIRO',
        'estado': 'ENTREGADO',
        'created_at': DateTime(2026, 11, 25, 17).toIso8601String(),
        'detalle_pedidos': [
          {'nombre_producto': 'Salteña'},
        ],
      });
      final pedidos = [pedidoCoincidente, pedidoExcluido];

      expect(
        filtrarPedidos(
          pedidos: pedidos,
          busqueda: 'maria',
          rangoFecha: null,
          modalidad: todasLasModalidades,
          estado: todosLosEstados,
        ).map((pedido) => pedido.id),
        ['pedido-1', 'pedido-2'],
      );
      expect(
        filtrarPedidos(
          pedidos: pedidos,
          busqueda: 'saltena',
          rangoFecha: DateTimeRange(start: fechaFiltro, end: fechaFiltro),
          modalidad: 'DELIVERY',
          estado: 'PAGO_EN_REVISION',
        ).map((pedido) => pedido.id),
        ['pedido-1'],
      );
    });

    test(
      'Pedido histórico acepta importes y cantidades numéricas o String',
      () {
        final pedido = Pedido.fromMap({
          'id': 'pedido-historico',
          'comprador_id': 'vecino-1',
          'negocio_id': 'negocio-1',
          'subtotal': '12.50',
          'costo_envio': 2.5,
          'total': 15,
          'estado': 'ESTADO_ANTIGUO',
          'calificado': false,
          'detalle_pedidos': [
            {
              'pedido_id': 'pedido-historico',
              'nombre_producto': 'Producto',
              'cantidad': 2.0,
              'precio_unitario': '6.25',
              'subtotal': 12.5,
            },
          ],
        });

        expect(pedido.subtotal, 12.5);
        expect(pedido.costoEnvio, 2.5);
        expect(pedido.total, 15.0);
        expect(pedido.estado, 'ESTADO_ANTIGUO');
        expect(pedido.negocioNombre, isNull);
        expect(pedido.detalles.single.cantidad, 2);
        expect(pedido.detalles.single.precioUnitario, 6.25);
        expect(pedido.detalles.single.subtotal, 12.5);
      },
    );

    test('lee nombre y verificación del perfil anidado del comprador', () {
      final pedido = Pedido.fromMap({
        'id': 'pedido-perfil',
        'comprador_id': 'vecino-1',
        'negocio_id': 'negocio-1',
        'perfiles': [
          {'nombre': '  Ana Pérez  ', 'kyc_verificado': true},
        ],
      });

      expect(pedido.compradorNombre, 'Ana Pérez');
      expect(pedido.compradorVerificado, isTrue);
    });

    test('lee el avatar público devuelto por el RPC del comprador', () {
      final pedido = Pedido.fromMap({
        'id': 'pedido-avatar',
        'comprador_id': 'vecino-1',
        'negocio_id': 'negocio-1',
        'comprador_nombre': 'Ana Pérez',
        'comprador_avatar_url': 'https://example.supabase.co/storage/v1/object/public/profile_avatars/vecino-1/avatar.jpg',
      });

      expect(pedido.compradorNombre, 'Ana Pérez');
      expect(
        pedido.compradorAvatarUrl,
        contains('/profile_avatars/vecino-1/avatar.jpg'),
      );
    });

    test('lee nombre y avatar de una reseña devuelta por el RPC', () {
      final resena = Resena.fromMap({
        'id': 'resena-1',
        'pedido_id': 'pedido-1',
        'negocio_id': 'negocio-1',
        'comprador_id': 'vecino-1',
        'comprador_nombre': 'Ana Pérez',
        'comprador_avatar_url': 'https://example.supabase.co/storage/v1/object/public/profile_avatars/vecino-1/avatar.jpg',
        'calificacion': 5,
        'comentario': 'Excelente',
      });

      expect(resena.compradorNombre, 'Ana Pérez');
      expect(
        resena.compradorAvatarUrl,
        contains('/profile_avatars/vecino-1/avatar.jpg'),
      );
    });

    test(
      'no sustituye el nombre ausente por una afirmación de verificación',
      () {
        final pedido = Pedido.fromMap({
          'id': 'pedido-sin-perfil',
          'comprador_id': 'vecino-2',
          'negocio_id': 'negocio-1',
          'comprador_nombre': ' ',
          'comprador_verificado': false,
        });

        expect(pedido.compradorNombre, isNull);
        expect(pedido.compradorVerificado, isFalse);
      },
    );

    test(
      'La reserva local por defecto es de tres minutos y conserva el PIN',
      () {
        final creadoHaceDosMinutos = DateTime.now().subtract(
          const Duration(minutes: 2),
        );
        final pedido = Pedido(
          id: 'pedido-1',
          compradorId: 'vecino-1',
          negocioId: 'negocio-1',
          modalidadEntrega: 'RETIRO',
          subtotal: 10,
          costoEnvio: 0,
          total: 10,
          estado: 'LISTO',
          createdAt: creadoHaceDosMinutos,
          pinEntrega: '0421',
        );

        expect(pedido.tiempoRestante, greaterThan(Duration.zero));
        expect(pedido.pinEntrega, '0421');
      },
    );
  });

  group('Filtros de historial de pedidos', () {
    testWidgets('muestra búsqueda y filtros sin desbordarse en móvil', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controlador = TextEditingController();
      addTearDown(controlador.dispose);
      var busqueda = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FiltrosHistorialPedidos(
                controladorBusqueda: controlador,
                rangoFecha: null,
                modalidad: todasLasModalidades,
                estado: todosLosEstados,
                onBusquedaChanged: (value) => busqueda = value,
                onRangoFechaChanged: (_) {},
                onModalidadChanged: (_) {},
                onEstadoChanged: (_) {},
                onLimpiar: () {},
                hayFiltrosActivos: false,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Salteña');
      expect(busqueda, 'Salteña');
      expect(tester.takeException(), isNull);
    });
  });

  group('AuthProvider registration KYC', () {
    test('rechaza una foto de C.I. vacía antes de crear la cuenta', () async {
      final auth = AuthProvider();
      addTearDown(auth.dispose);
      final fotoValida = XFile.fromData(
        Uint8List.fromList([1]),
        name: 'foto.jpg',
      );

      final success = await auth.registrarUsuario(
        email: 'simone@example.com',
        password: 'password-seguro',
        nombre: 'Simone Caballero Muñoz',
        ci: '1234567',
        telefono: '70000000',
        selfie: fotoValida,
        facade: fotoValida,
        ciAnverso: XFile.fromData(Uint8List(0), name: 'vacia.jpg'),
        ciReverso: fotoValida,
        lat: -16.5,
        lng: -68.15,
        termsVersion: 'test',
      );

      expect(success, isFalse);
      expect(auth.errorMessage, contains('C.I. Anverso'));
    });
  });

  group('AuthProvider navigation intent', () {
    test('representa y consume la pestaña Explorar (índice cero)', () {
      final auth = AuthProvider();
      addTearDown(auth.dispose);

      expect(auth.vecinoTabInicial, isNull);
      auth.seleccionarTabVecino(0, pedidoId: 'pedido-1');
      expect(auth.vecinoTabInicial, 0);
      expect(auth.pedidoDestacadoId, 'pedido-1');

      auth.consumirTabInicial();
      expect(auth.vecinoTabInicial, isNull);
    });
  });

  group('Nominatim Tests', () {
    test(
      'convierte un resultado válido y evita consultas menores a 3 caracteres',
      () async {
        final lugar = NominatimPlace.fromMap({
          'display_name': 'Sopocachi, La Paz, Bolivia',
          'lat': '-16.5090',
          'lon': '-68.1280',
        });

        expect(lugar.location.latitude, -16.5090);
        expect(lugar.location.longitude, -68.1280);
        expect(await NominatimService().buscar('lp'), isEmpty);
      },
    );
  });

  group('HU-23 Moderación y enfriamiento', () {
    test('bloquea groserías incluso con mayúsculas y puntuación', () {
      expect(
        Moderacion.validarComentario('El lugar es una M.I.E.R.D.A.'),
        'Reseña cancelada. No se publicó por el uso de malas palabras.',
      );
      expect(
        Moderacion.validarComentario('Qué servicio tan cabrón'),
        'Reseña cancelada. No se publicó por el uso de malas palabras.',
      );
      expect(
        Moderacion.validarComentario('Eres un imbécil'),
        'Reseña cancelada. No se publicó por el uso de malas palabras.',
      );
      expect(Moderacion.validarComentario('Servicio excelente'), isNull);
      expect(Moderacion.validarComentario('El uso es putativo'), isNull);
    });

    test('valida un único reporte con motivo y detalle acotado', () {
      expect(
        Moderacion.validarReporte(
          motivo: 'Fraude',
          detalle: 'Comprobante inconsistente',
        ),
        isNull,
      );
      expect(Moderacion.validarReporte(motivo: 'x', detalle: ''), isNotNull);
      expect(
        Moderacion.validarReporte(motivo: 'Fraude', detalle: 'a' * 601),
        isNotNull,
      );
    });

    test('el enfriamiento bloquea solo antes de su vencimiento', () {
      final ahora = DateTime.utc(2026, 11, 26, 12);
      expect(
        Moderacion.enfriamientoActivo(
          ahora.add(const Duration(hours: 24)),
          ahora,
        ),
        isTrue,
      );
      expect(
        Moderacion.enfriamientoActivo(
          ahora.subtract(const Duration(seconds: 1)),
          ahora,
        ),
        isFalse,
      );
    });
  });

  group('HU-24 Horarios recurrentes', () {
    test('parsea y expone la franja de horario configurada', () {
      final negocio = Negocio(
        id: 'neg-horario',
        ownerId: 'dueno',
        nombre: 'Tienda',
        descripcion: 'Abierta',
        lat: 0,
        lng: 0,
        storePhotoUrl: '',
        qrPhotoUrl: '',
        deliveryOptions: const ['RECOJO_LOCAL'],
        shippingCost: 0,
        horaApertura: '08:00:00',
        horaCierre: '20:30:00',
      );
      expect(negocio.horarioLegible, '08:00 - 20:30');
      expect(negocio.copyWith().diasOperativos, contains(7));
    });
  });

  group('Widget Tests', () {
    testWidgets('LoginScreen renderiza correctamente en viewport (360x640)', (
      WidgetTester tester,
    ) async {
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

    testWidgets(
      'PerfilSwitchScreen renderiza correctamente en viewport (360x640)',
      (WidgetTester tester) async {
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
      },
    );
  });
}
