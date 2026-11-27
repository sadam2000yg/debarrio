import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:d_barrio/core/utils/moderacion.dart';

import '../../../services/storage_service.dart';
import '../domain/pedido.dart';
import '../domain/resena.dart';

class PedidosRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StorageService _storageService = StorageService();

  Future<Pedido> crearPedidoAcid({
    required String negocioId,
    required String modalidadEntrega,
    String? referenciaEntrega,
    required double costoEnvio,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _supabase.rpc(
        'crear_pedido_acid',
        params: {
          'p_negocio_id': negocioId,
          'p_modalidad_entrega': modalidadEntrega,
          'p_referencia_entrega': referenciaEntrega,
          'p_costo_envio': costoEnvio,
          'p_items': items,
        },
      );

      final String pedidoId = response is Map
          ? (response['pedido_id']?.toString() ??
                response['id']?.toString() ??
                '')
          : response.toString();
      if (pedidoId.isEmpty) {
        throw 'No se pudo obtener el ID del pedido creado.';
      }

      return await obtenerPedidoPorId(pedidoId);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('stock') ||
          msg.contains('insuficiente') ||
          msg.contains('reservad') ||
          msg.contains('insufficient') ||
          msg.contains('bloquead')) {
        throw 'Este producto ha sido reservado temporalmente por otro vecino. Si no completa su pago en 3 minutos, volverá a estar disponible.';
      }
      throw e.message;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('stock') ||
          msg.contains('insuficiente') ||
          msg.contains('reservad') ||
          msg.contains('insufficient')) {
        throw 'Este producto ha sido reservado temporalmente por otro vecino. Si no completa su pago en 3 minutos, volverá a estar disponible.';
      }
      throw e.toString();
    }
  }

  Future<Pedido> obtenerPedidoPorId(String pedidoId) async {
    try {
      final response = await _supabase
          .from('pedidos')
          .select(
            '*, negocios(nombre, qr_photo_url, store_photo_url), detalle_pedidos(*)',
          )
          .eq('id', pedidoId)
          .single();

      return Pedido.fromMap(response);
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Pedido>> listarPedidosComprador(String compradorId) async {
    try {
      final response = await _supabase
          .from('pedidos')
          .select(
            '*, negocios(nombre, qr_photo_url, store_photo_url), detalle_pedidos(*)',
          )
          .eq('comprador_id', compradorId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => Pedido.fromMap(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Pedido>> listarPedidosNegocio(String negocioId) async {
    try {
      final response = await _supabase
          .from('pedidos')
          .select('*, detalle_pedidos(*)')
          .eq('negocio_id', negocioId)
          .order('created_at', ascending: true);

      final pedidos = (response as List)
          .map((row) => Pedido.fromMap(row as Map<String, dynamic>))
          .toList();
      if (pedidos.isEmpty) return pedidos;

      final compradores = await _supabase.rpc(
        'obtener_resumen_compradores_pedidos_con_avatar',
        params: {'p_negocio_id': negocioId},
      );
      final resumenesPorPedido = <String, Map<String, dynamic>>{};
      for (final row in compradores as List) {
        if (row is! Map) continue;
        final pedidoId = row['pedido_id']?.toString();
        if (pedidoId == null || pedidoId.isEmpty) continue;
        resumenesPorPedido[pedidoId] = Map<String, dynamic>.from(row);
      }

      return pedidos.map((pedido) {
        final resumen = resumenesPorPedido[pedido.id];
        if (resumen == null) return pedido;
        final avatarPath = resumen['comprador_avatar_path']?.toString();
        return pedido.copyWith(
          compradorNombre: resumen['comprador_nombre']?.toString(),
          compradorAvatarUrl: avatarPath == null || avatarPath.isEmpty
              ? null
              : _storageService.getProfileAvatarUrl(avatarPath),
          compradorVerificado: resumen['comprador_verificado'] == true,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> marcarComoPagado(String pedidoId) async {
    try {
      await _supabase.rpc(
        'marcar_pedido_pagado',
        params: {'p_pedido_id': pedidoId},
      );
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> responderPagoVendedor({
    required String pedidoId,
    required bool confirmado,
  }) async {
    try {
      await _supabase.rpc(
        'responder_pago_vendedor',
        params: {'p_pedido_id': pedidoId, 'p_confirmado': confirmado},
      );
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String> avanzarEstadoPedido(String pedidoId) async {
    try {
      final response = await _supabase.rpc(
        'avanzar_estado_pedido',
        params: {'p_pedido_id': pedidoId},
      );

      final map = response as Map<String, dynamic>;
      return map['estado'] as String;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> confirmarEntregaConPin({
    required String pedidoId,
    required String pin,
  }) async {
    final pinNormalizado = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pinNormalizado)) {
      throw 'El PIN debe tener exactamente 4 dígitos.';
    }

    try {
      await _supabase.rpc(
        'confirmar_entrega_con_pin',
        params: {'p_pedido_id': pedidoId, 'p_pin': pinNormalizado},
      );
    } on PostgrestException catch (e) {
      throw e.message;
    }
  }

  Future<void> abrirDisputa({
    required String pedidoId,
    required String motivo,
  }) async {
    try {
      await _supabase
          .from('pedidos')
          .update({
            'estado': 'EN_DISPUTA',
            'alerta_pago': 'Disputa/Devolución: $motivo',
          })
          .eq('id', pedidoId);
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> crearResenaVerificada({
    required String pedidoId,
    required int calificacion,
    required String comentario,
  }) async {
    final errorModeracion = Moderacion.validarComentario(comentario);
    if (errorModeracion != null) throw errorModeracion;

    try {
      await _supabase.rpc(
        'crear_resena_verificada',
        params: {
          'p_pedido_id': pedidoId,
          'p_calificacion': calificacion,
          'p_comentario': comentario.trim(),
        },
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('calificad') ||
          msg.contains('ya') ||
          msg.contains('entrega')) {
        throw 'Este pedido ya fue calificado o aún no ha sido entregado.';
      }
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Resena>> listarResenasNegocio(String negocioId) async {
    try {
      final response = await _supabase.rpc(
        'listar_resenas_negocio_con_perfil',
        params: {'p_negocio_id': negocioId},
      );

      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final avatarPath = map['comprador_avatar_path']?.toString();
        map['comprador_avatar_url'] = avatarPath == null || avatarPath.isEmpty
            ? null
            : _storageService.getProfileAvatarUrl(avatarPath);
        return Resena.fromMap(map);
      }).toList();
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> liberarPedidosExpirados() async {
    try {
      await _supabase.rpc('liberar_pedidos_expirados');
    } catch (_) {
      // Ignorar errores de red silenciosamente
    }
  }
}
