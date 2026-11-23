class Resena {
  final String id;
  final String pedidoId;
  final String negocioId;
  final String compradorId;
  final int calificacion;
  final String comentario;
  final DateTime? createdAt;
  final String? compradorNombre;
  final String? compradorSelfieUrl;

  const Resena({
    required this.id,
    required this.pedidoId,
    required this.negocioId,
    required this.compradorId,
    required this.calificacion,
    required this.comentario,
    this.createdAt,
    this.compradorNombre,
    this.compradorSelfieUrl,
  });

  factory Resena.fromMap(Map<String, dynamic> map) {
    String? compNombre;
    String? compSelfie;
    if (map['perfiles'] is Map) {
      final per = map['perfiles'] as Map<String, dynamic>;
      compNombre = per['nombre']?.toString();
      compSelfie = per['selfie_url']?.toString();
    } else {
      compNombre = map['comprador_nombre']?.toString();
      compSelfie = map['comprador_selfie_url']?.toString();
    }

    return Resena(
      id: map['id']?.toString() ?? '',
      pedidoId: map['pedido_id']?.toString() ?? '',
      negocioId: map['negocio_id']?.toString() ?? '',
      compradorId: map['comprador_id']?.toString() ?? '',
      calificacion: map['calificacion'] != null ? (map['calificacion'] as num).toInt() : 5,
      comentario: map['comentario']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      compradorNombre: compNombre,
      compradorSelfieUrl: compSelfie,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'negocio_id': negocioId,
      'comprador_id': compradorId,
      'calificacion': calificacion,
      'comentario': comentario,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
