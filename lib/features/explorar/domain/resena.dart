class Resena {
  final String id;
  final String negocioId;
  final String usuarioId;
  final String nombreUsuario;
  final int calificacion;
  final String comentario;
  final DateTime? createdAt;

  Resena({
    required this.id,
    required this.negocioId,
    required this.usuarioId,
    required this.nombreUsuario,
    required this.calificacion,
    required this.comentario,
    this.createdAt,
  });

  factory Resena.fromMap(Map<String, dynamic> map) {
    String nombre = 'Vecino';
    if (map['perfiles'] is Map) {
      nombre = map['perfiles']['nombre']?.toString() ??
          map['perfiles']['nombre_completo']?.toString() ??
          'Vecino';
    } else if (map['nombre_usuario'] != null) {
      nombre = map['nombre_usuario'].toString();
    }

    return Resena(
      id: map['id']?.toString() ?? '',
      negocioId: map['negocio_id']?.toString() ?? '',
      usuarioId: map['usuario_id']?.toString() ?? '',
      nombreUsuario: nombre,
      calificacion: map['calificacion'] != null ? (map['calificacion'] as num).toInt() : 5,
      comentario: map['comentario']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}
