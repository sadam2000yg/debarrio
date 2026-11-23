import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/domain/negocio.dart';
import '../domain/producto.dart';

class NegocioRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Negocio?> obtenerNegocioPorOwner(String ownerId) async {
    try {
      final response = await _supabase.from('negocios').select().eq('owner_id', ownerId).maybeSingle();
      if (response != null) {
        return Negocio.fromMap(response);
      }
    } catch (_) {}
    return null;
  }

  Future<void> actualizarEstadoOperativo(String negocioId, bool abierto) async {
    await _supabase.from('negocios').update({'abierto': abierto}).eq('id', negocioId);
    if (!abierto) {
      await _supabase
          .from('productos')
          .update({'activo': false})
          .eq('negocio_id', negocioId)
          .eq('tipo_inventario', 'DIARIO_PERECEDERO');
    }
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

    await _supabase.from('negocios').update({
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'delivery_options': deliveryOptions,
      'shipping_cost': shippingCost,
      'qr_photo_url': qrPhotoUrl,
      'store_photo_url': storePhotoUrl,
    }).eq('id', negocioId);
  }

  Future<List<Producto>> listarProductosDeNegocio(String negocioId) async {
    try {
      final response = await _supabase
          .from('productos')
          .select()
          .eq('negocio_id', negocioId)
          .eq('eliminado', false)
          .order('nombre', ascending: true);

      return (response as List).map((e) => Producto.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> crearProducto(Producto producto) async {
    await _supabase.from('productos').insert(producto.toMap());
  }

  Future<void> actualizarProducto(Producto producto) async {
    await _supabase.from('productos').update(producto.toMap()).eq('id', producto.id);
  }

  Future<void> alternarActivoProducto(String productoId, bool activo) async {
    await _supabase.from('productos').update({'activo': activo}).eq('id', productoId);
  }

  Future<void> eliminarProductoLogico(String productoId) async {
    await _supabase.from('productos').update({'eliminado': true}).eq('id', productoId);
  }

  Future<void> reiniciarStockDiario(String negocioId) async {
    final productosRes = await _supabase
        .from('productos')
        .select()
        .eq('negocio_id', negocioId)
        .eq('eliminado', false)
        .eq('tipo_inventario', 'DIARIO_PERECEDERO');

    for (final pMap in productosRes) {
      final prod = Producto.fromMap(pMap);
      await _supabase.from('productos').update({
        'stock_disponible': prod.stockBaseDiario,
        'activo': true,
      }).eq('id', prod.id);
    }
  }
}
