class DetallePedido {
  final String id;
  final String pedidoId;
  final String productoId;
  final String nombreProducto;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  const DetallePedido({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory DetallePedido.fromMap(Map<String, dynamic> map) {
    return DetallePedido(
      id: map['id']?.toString() ?? '',
      pedidoId: map['pedido_id']?.toString() ?? '',
      productoId: map['producto_id']?.toString() ?? '',
      nombreProducto: map['nombre_producto']?.toString() ?? map['nombre']?.toString() ?? '',
      cantidad: _enteroSeguro(map['cantidad'], defecto: 1),
      precioUnitario: _numeroSeguro(map['precio_unitario']),
      subtotal: _numeroSeguro(map['subtotal']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'nombre_producto': nombreProducto,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    };
  }
}

int _enteroSeguro(dynamic valor, {int defecto = 0}) {
  final parsed = valor is num
      ? valor
      : num.tryParse(valor?.toString().trim() ?? '');
  if (parsed == null || !parsed.isFinite) return defecto;

  final value = parsed.toDouble();
  if (value != value.roundToDouble()) return defecto;
  return value.toInt();
}

double _numeroSeguro(dynamic valor) {
  final parsed = valor is num
      ? valor.toDouble()
      : double.tryParse(valor?.toString().trim() ?? '');
  return parsed != null && parsed.isFinite ? parsed : 0.0;
}
