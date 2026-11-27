import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/negocio.dart';
import '../../negocio/domain/producto.dart';
import '../domain/resena.dart';

class ExplorarRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Negocio>> buscarNegociosCercanos({
    required double lat,
    required double lon,
    double radioMetros = 1000,
    String? categoria,
    String? busqueda,
  }) async {
    try {
      final params = {
        'p_lat': lat,
        'p_lon': lon,
        'p_radio_metros': radioMetros,
        if (categoria != null && categoria.toUpperCase() != 'TODOS')
          'p_categoria': categoria,
        if (busqueda != null && busqueda.trim().isNotEmpty)
          'p_busqueda': busqueda.trim(),
      };

      final response = await _supabase.rpc(
        'buscar_negocios_cercanos',
        params: params,
      );
      return (response as List)
          .map((e) => Negocio.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('Error en RPC buscar_negocios_cercanos: $e\n$st');
      try {
        var query = _supabase.from('negocios').select();
        query = query.eq('en_cuarentena', false);
        if (categoria != null && categoria.toUpperCase() != 'TODOS') {
          query = query.eq('categoria', categoria);
        }
        if (busqueda != null && busqueda.trim().isNotEmpty) {
          query = query.ilike('nombre', '%${busqueda.trim()}%');
        }
        final response = await query;
        return (response as List)
            .map((e) => Negocio.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (fallbackError, fallbackSt) {
        debugPrint(
          'Error en fallback buscarNegociosCercanos: $fallbackError\n$fallbackSt',
        );
        rethrow;
      }
    }
  }

  Future<List<Producto>> listarProductosDeNegocio(String negocioId) async {
    try {
      final response = await _supabase
          .from('productos')
          .select()
          .eq('negocio_id', negocioId)
          .eq('activo', true)
          .eq('eliminado', false)
          .eq('en_cuarentena', false)
          .order('nombre', ascending: true);

      return (response as List)
          .map((e) => Producto.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('Error en listarProductosDeNegocio (ExplorarRepo): $e\n$st');
      rethrow;
    }
  }

  Future<List<Resena>> obtenerResenasDeNegocio(String negocioId) async {
    try {
      final response = await _supabase
          .from('resenas')
          .select('*, perfiles(nombre)')
          .eq('negocio_id', negocioId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => Resena.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('Error en obtenerResenasDeNegocio: $e\n$st');
      rethrow;
    }
  }

  Future<void> reportarNegocio({
    required String negocioId,
    required String motivo,
    String detalle = '',
  }) async {
    await _supabase.rpc(
      'reportar_contenido',
      params: {
        'p_objetivo_tipo': 'NEGOCIO',
        'p_objetivo_id': negocioId,
        'p_motivo': motivo,
        'p_detalle': detalle,
      },
    );
  }
}
