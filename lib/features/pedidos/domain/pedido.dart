import 'detalle_pedido.dart';

class Pedido {
  final String id;
  final String compradorId;
  final String negocioId;
  final String modalidadEntrega; // 'RETIRO' o 'DELIVERY'
  final String? referenciaEntrega;
  final double subtotal;
  final double costoEnvio;
  final double total;
  final String estado; // 'ESPERANDO_PAGO', 'PAGO_EN_REVISION', 'EN_PREPARACION', 'LISTO', 'ENTREGADO', 'CANCELADO_POR_TIEMPO', 'EN_DISPUTA'
  final DateTime? expiraEn;
  final String? alertaPago;
  final String? pinEntrega;
  final bool calificado;
  final DateTime? createdAt;
  final String? negocioNombre;
  final String? negocioQrUrl;
  final String? negocioStoreUrl;
  final String? compradorNombre;
  final String? compradorAvatarUrl;
  final bool compradorVerificado;
  final List<DetallePedido> detalles;

  const Pedido({
    required this.id,
    required this.compradorId,
    required this.negocioId,
    required this.modalidadEntrega,
    this.referenciaEntrega,
    required this.subtotal,
    required this.costoEnvio,
    required this.total,
    required this.estado,
    this.expiraEn,
    this.alertaPago,
    this.pinEntrega,
    this.calificado = false,
    this.createdAt,
    this.negocioNombre,
    this.negocioQrUrl,
    this.negocioStoreUrl,
    this.compradorNombre,
    this.compradorAvatarUrl,
    this.compradorVerificado = false,
    this.detalles = const [],
  });

  Duration get tiempoRestante {
    final DateTime? expiracion =
        expiraEn ?? createdAt?.add(const Duration(minutes: 3));
    if (expiracion == null) return Duration.zero;
    final now = DateTime.now();
    if (expiracion.isBefore(now)) return Duration.zero;
    return expiracion.difference(now);
  }

  Pedido copyWith({
    String? id,
    String? compradorId,
    String? negocioId,
    String? modalidadEntrega,
    String? referenciaEntrega,
    double? subtotal,
    double? costoEnvio,
    double? total,
    String? estado,
    DateTime? expiraEn,
    String? alertaPago,
    String? pinEntrega,
    bool? calificado,
    DateTime? createdAt,
    String? negocioNombre,
    String? negocioQrUrl,
    String? negocioStoreUrl,
    String? compradorNombre,
    String? compradorAvatarUrl,
    bool? compradorVerificado,
    List<DetallePedido>? detalles,
  }) {
    return Pedido(
      id: id ?? this.id,
      compradorId: compradorId ?? this.compradorId,
      negocioId: negocioId ?? this.negocioId,
      modalidadEntrega: modalidadEntrega ?? this.modalidadEntrega,
      referenciaEntrega: referenciaEntrega ?? this.referenciaEntrega,
      subtotal: subtotal ?? this.subtotal,
      costoEnvio: costoEnvio ?? this.costoEnvio,
      total: total ?? this.total,
      estado: estado ?? this.estado,
      expiraEn: expiraEn ?? this.expiraEn,
      alertaPago: alertaPago ?? this.alertaPago,
      pinEntrega: pinEntrega ?? this.pinEntrega,
      calificado: calificado ?? this.calificado,
      createdAt: createdAt ?? this.createdAt,
      negocioNombre: negocioNombre ?? this.negocioNombre,
      negocioQrUrl: negocioQrUrl ?? this.negocioQrUrl,
      negocioStoreUrl: negocioStoreUrl ?? this.negocioStoreUrl,
      compradorNombre: compradorNombre ?? this.compradorNombre,
      compradorAvatarUrl: compradorAvatarUrl ?? this.compradorAvatarUrl,
      compradorVerificado: compradorVerificado ?? this.compradorVerificado,
      detalles: detalles ?? this.detalles,
    );
  }

  factory Pedido.fromMap(Map<String, dynamic> map) {
    String? negNombre;
    String? negQr;
    String? negStore;
    if (map['negocios'] is Map) {
      final neg = map['negocios'] as Map<String, dynamic>;
      negNombre = neg['nombre']?.toString();
      negQr = neg['qr_photo_url']?.toString();
      negStore = neg['store_photo_url']?.toString();
    } else {
      negNombre = map['negocio_nombre']?.toString();
      negQr = map['negocio_qr_url']?.toString();
      negStore = map['negocio_store_url']?.toString();
    }

    Map<String, dynamic>? perfilComprador;
    final perfilAnidado = map['perfiles'];
    if (perfilAnidado is Map) {
      perfilComprador = Map<String, dynamic>.from(perfilAnidado);
    } else if (perfilAnidado is List &&
        perfilAnidado.isNotEmpty &&
        perfilAnidado.first is Map) {
      perfilComprador = Map<String, dynamic>.from(perfilAnidado.first as Map);
    }

    String? compNombre;
    String? compAvatar;
    var compVerificado = map['comprador_verificado'] == true;
    if (perfilComprador != null) {
      final nombre = perfilComprador['nombre']?.toString().trim();
      compNombre = nombre == null || nombre.isEmpty ? null : nombre;
      final avatar = perfilComprador['avatar_url']?.toString().trim();
      compAvatar = avatar == null || avatar.isEmpty ? null : avatar;
      compVerificado =
          compVerificado || perfilComprador['kyc_verificado'] == true;
    } else {
      final nombre = map['comprador_nombre']?.toString().trim();
      compNombre = nombre == null || nombre.isEmpty ? null : nombre;
      compAvatar = map['comprador_avatar_url']?.toString();
    }

    List<DetallePedido> detallesList = [];
    if (map['detalle_pedidos'] is List) {
      detallesList = (map['detalle_pedidos'] as List)
          .map((e) => DetallePedido.fromMap(e as Map<String, dynamic>))
          .toList();
    } else if (map['detalles'] is List) {
      detallesList = (map['detalles'] as List)
          .map((e) => DetallePedido.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return Pedido(
      id: map['id']?.toString() ?? '',
      compradorId: map['comprador_id']?.toString() ?? '',
      negocioId: map['negocio_id']?.toString() ?? '',
      modalidadEntrega:
          map['modalidad_entrega']?.toString() ??
          map['modalidad']?.toString() ??
          'RETIRO',
      referenciaEntrega: map['referencia_entrega']?.toString(),
      subtotal: _numeroSeguro(map['subtotal']),
      costoEnvio: _numeroSeguro(map['costo_envio']),
      total: _numeroSeguro(map['total']),
      estado: map['estado']?.toString() ?? 'ESPERANDO_PAGO',
      expiraEn: map['expira_en'] != null
          ? DateTime.tryParse(map['expira_en'].toString())
          : null,
      alertaPago: map['alerta_pago']?.toString(),
      pinEntrega: map['pin_entrega']?.toString(),
      calificado: map['calificado'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      negocioNombre: negNombre,
      negocioQrUrl: negQr,
      negocioStoreUrl: negStore,
      compradorNombre: compNombre,
      compradorAvatarUrl: compAvatar,
      compradorVerificado: compVerificado,
      detalles: detallesList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'comprador_id': compradorId,
      'negocio_id': negocioId,
      'modalidad_entrega': modalidadEntrega,
      'referencia_entrega': referenciaEntrega,
      'subtotal': subtotal,
      'costo_envio': costoEnvio,
      'total': total,
      'estado': estado,
      'expira_en': expiraEn?.toIso8601String(),
      'alerta_pago': alertaPago,
      'pin_entrega': pinEntrega,
      'calificado': calificado,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

double _numeroSeguro(dynamic valor) {
  final parsed = valor is num
      ? valor.toDouble()
      : double.tryParse(valor?.toString().trim() ?? '');
  return parsed != null && parsed.isFinite ? parsed : 0.0;
}
