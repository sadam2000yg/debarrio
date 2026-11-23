class Producto {
  final String id;
  final String negocioId;
  final String nombre;
  final String descripcion;
  final List<String> fotosUrls;
  final double precio;
  final String tipoInventario; // 'UNICO', 'RECURRENTE', 'DIARIO_PERECEDERO'
  final int stockDisponible;
  final int stockReservado;
  final int stockBaseDiario;
  final bool activo;
  final bool vendidoUnico;
  final bool eliminado;

  Producto({
    required this.id,
    required this.negocioId,
    required this.nombre,
    required this.descripcion,
    required this.fotosUrls,
    required this.precio,
    required this.tipoInventario,
    required this.stockDisponible,
    required this.stockReservado,
    required this.stockBaseDiario,
    required this.activo,
    required this.vendidoUnico,
    this.eliminado = false,
  });

  String get fotoUrl => fotosUrls.isNotEmpty ? fotosUrls.first : '';

  bool get estaDisponible => activo && !eliminado && !vendidoUnico && stockDisponible > 0;

  String get etiquetaDisponibilidad {
    if (eliminado) return 'Eliminado';
    if (tipoInventario == 'UNICO' && (vendidoUnico || stockDisponible <= 0)) {
      return 'Vendido';
    }
    if (!activo || stockDisponible <= 0) return 'Agotado';
    return 'Disponible';
  }

  String get precioFormateado => 'Bs ${precio.toStringAsFixed(2)}';

  Producto copyWith({
    String? id,
    String? negocioId,
    String? nombre,
    String? descripcion,
    List<String>? fotosUrls,
    double? precio,
    String? tipoInventario,
    int? stockDisponible,
    int? stockReservado,
    int? stockBaseDiario,
    bool? activo,
    bool? vendidoUnico,
    bool? eliminado,
  }) {
    return Producto(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      precio: precio ?? this.precio,
      tipoInventario: tipoInventario ?? this.tipoInventario,
      stockDisponible: stockDisponible ?? this.stockDisponible,
      stockReservado: stockReservado ?? this.stockReservado,
      stockBaseDiario: stockBaseDiario ?? this.stockBaseDiario,
      activo: activo ?? this.activo,
      vendidoUnico: vendidoUnico ?? this.vendidoUnico,
      eliminado: eliminado ?? this.eliminado,
    );
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    List<String> fotos = [];
    if (map['fotos_urls'] is List) {
      fotos = (map['fotos_urls'] as List).map((e) => e.toString()).toList();
    } else if (map['foto_url'] != null && map['foto_url'].toString().isNotEmpty) {
      fotos = [map['foto_url'].toString()];
    }

    return Producto(
      id: map['id']?.toString() ?? '',
      negocioId: map['negocio_id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      fotosUrls: fotos,
      precio: map['precio'] != null ? (map['precio'] as num).toDouble() : 0.0,
      tipoInventario: map['tipo_inventario']?.toString() ?? 'RECURRENTE',
      stockDisponible: map['stock_disponible'] != null ? (map['stock_disponible'] as num).toInt() : 0,
      stockReservado: map['stock_reservado'] != null ? (map['stock_reservado'] as num).toInt() : 0,
      stockBaseDiario: map['stock_base_diario'] != null ? (map['stock_base_diario'] as num).toInt() : 0,
      activo: map['activo'] ?? true,
      vendidoUnico: map['vendido_unico'] ?? false,
      eliminado: map['eliminado'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'negocio_id': negocioId,
      'nombre': nombre,
      'descripcion': descripcion,
      'fotos_urls': fotosUrls,
      'foto_url': fotosUrls.isNotEmpty ? fotosUrls.first : '',
      'precio': precio,
      'tipo_inventario': tipoInventario,
      'stock_disponible': stockDisponible,
      'stock_reservado': stockReservado,
      'stock_base_diario': stockBaseDiario,
      'activo': activo,
      'vendido_unico': vendidoUnico,
      'eliminado': eliminado,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
