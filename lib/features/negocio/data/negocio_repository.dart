import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/domain/negocio.dart';
import '../domain/producto.dart';
import '../../../core/utils/demo_data.dart';

class NegocioRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Negocio?> obtenerNegocioPorOwner(String ownerId) async {
    try {
      final response = await _supabase.from('negocios').select().eq('owner_id', ownerId).maybeSingle();
      if (response != null) {
        return Negocio.fromMap(response);
      }
    } catch (_) {}

    return Negocio(
      id: 'negocio-demo-1',
      ownerId: ownerId,
      nombre: "Doña Carmen - Salteñas y Empanadas (Demo)",
      descripcion: "Puesto de demostración para gestionar tu catálogo, precios, stock y apertura diaria.",
      lat: -16.5000,
      lng: -68.1500,
      storePhotoUrl: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5",
      qrPhotoUrl: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe",
      deliveryOptions: ['DELIVERY_PROPIO', 'RECOJO_LOCAL'],
      shippingCost: 500,
      abierto: true,
      categoria: "Comida",
    );
  }

  Future<void> actualizarEstadoOperativo(String negocioId, bool abierto) async {
    try {
      await _supabase.from('negocios').update({'abierto': abierto}).eq('id', negocioId);
      if (!abierto) {
        await _supabase
            .from('productos')
            .update({'activo': false})
            .eq('negocio_id', negocioId)
            .eq('tipo_inventario', 'DIARIO_PERECEDERO');
      }
    } catch (_) {}
  }

  Future<void> actualizarConfiguracionPuesto({
    required String negocioId,
    required String nombre,
    required String descripcion,
    required List<String> deliveryOptions,
    required int shippingCost,
    required String qrPhotoUrl,
    required String storePhotoUrl,
  }) async {
    if (deliveryOptions.isEmpty) {
      throw 'Debe seleccionar al menos una opción de entrega.';
    }

    try {
      await _supabase.from('negocios').update({
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'delivery_options': deliveryOptions,
        'shipping_cost': shippingCost,
        'qr_photo_url': qrPhotoUrl,
        'store_photo_url': storePhotoUrl,
      }).eq('id', negocioId);
    } catch (_) {}
  }

  Future<List<Producto>> listarProductosDeNegocio(String negocioId) async {
    try {
      final response = await _supabase
          .from('productos')
          .select()
          .eq('negocio_id', negocioId)
          .order('nombre', ascending: true);

      final list = (response as List).map((e) => Producto.fromMap(e)).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return DemoData.productosDemo[negocioId] ?? [
      Producto(
        id: 'prod-demo-new-1',
        negocioId: negocioId,
        nombre: 'Salteña de Carne Especial',
        descripcion: 'Deliciosa salteña con carne picada seleccionada, papa y aceituna.',
        fotoUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46',
        precio: 9.00,
        tipoInventario: 'DIARIO_PERECEDERO',
        stockDisponible: 20,
        stockReservado: 0,
        stockBaseDiario: 20,
        activo: true,
        vendidoUnico: false,
      ),
    ];
  }

  Future<void> crearProducto(Producto producto) async {
    try {
      await _supabase.from('productos').insert(producto.toMap());
    } catch (_) {
      // In demo mode fallback, we can also add to local DemoData if needed
    }
  }

  Future<void> actualizarProducto(Producto producto) async {
    try {
      await _supabase.from('productos').update(producto.toMap()).eq('id', producto.id);
    } catch (_) {}
  }

  Future<void> alternarActivoProducto(String productoId, bool activo) async {
    try {
      await _supabase.from('productos').update({'activo': activo}).eq('id', productoId);
    } catch (_) {}
  }

  Future<void> reiniciarStockDiario(String negocioId) async {
    try {
      final productosRes = await _supabase
          .from('productos')
          .select()
          .eq('negocio_id', negocioId)
          .eq('tipo_inventario', 'DIARIO_PERECEDERO');

      for (final pMap in productosRes) {
        final prod = Producto.fromMap(pMap);
        await _supabase.from('productos').update({
          'stock_disponible': prod.stockBaseDiario,
          'activo': true,
        }).eq('id', prod.id);
      }
    } catch (_) {}
  }
}
