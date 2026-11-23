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
        if (categoria != null && categoria.toUpperCase() != 'TODOS') 'p_categoria': categoria,
        if (busqueda != null && busqueda.trim().isNotEmpty) 'p_busqueda': busqueda.trim(),
      };

      final response = await _supabase.rpc('buscar_negocios_cercanos', params: params);
      return (response as List).map((e) => Negocio.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      try {
        var query = _supabase.from('negocios').select();
        if (categoria != null && categoria.toUpperCase() != 'TODOS') {
          query = query.eq('categoria', categoria);
        }
        if (busqueda != null && busqueda.trim().isNotEmpty) {
          query = query.ilike('nombre', '%${busqueda.trim()}%');
        }
        final response = await query;
        return (response as List).map((e) => Negocio.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
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
          .order('nombre', ascending: true);

      return (response as List).map((e) => Producto.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Resena>> obtenerResenasDeNegocio(String negocioId) async {
    try {
      final response = await _supabase
          .from('resenas')
          .select('*, perfiles(nombre)')
          .eq('negocio_id', negocioId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Resena.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
