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
      cantidad: map['cantidad'] != null ? (map['cantidad'] as num).toInt() : 1,
      precioUnitario: map['precio_unitario'] != null ? (map['precio_unitario'] as num).toDouble() : 0.0,
      subtotal: map['subtotal'] != null ? (map['subtotal'] as num).toDouble() : 0.0,
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
