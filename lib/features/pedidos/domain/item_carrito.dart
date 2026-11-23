import '../../negocio/domain/producto.dart';

class ItemCarrito {
  final Producto producto;
  final int cantidad;

  const ItemCarrito({
    required this.producto,
    required this.cantidad,
  });

  double get subtotal => double.parse((producto.precio * cantidad).toStringAsFixed(2));

  ItemCarrito copyWith({
    Producto? producto,
    int? cantidad,
  }) {
    return ItemCarrito(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
    );
  }
}
