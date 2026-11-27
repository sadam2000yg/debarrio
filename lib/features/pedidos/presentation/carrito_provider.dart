import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/negocio.dart';
import '../../negocio/domain/producto.dart';
import '../domain/item_carrito.dart';

class CarritoProvider extends ChangeNotifier {
  Negocio? _negocioActual;
  final List<ItemCarrito> _items = [];
  bool _validandoStock = false;
  String? _error;

  Negocio? get negocioActual => _negocioActual;
  List<ItemCarrito> get items => List.unmodifiable(_items);
  bool get validandoStock => _validandoStock;
  String? get error => _error;
  bool get estaVacio => _items.isEmpty;
  int get cantidadTotalItems =>
      _items.fold(0, (sum, item) => sum + item.cantidad);
  double get subtotalProductos {
    final total = _items.fold(0.0, (sum, item) => sum + item.subtotal);
    return double.parse(total.toStringAsFixed(2));
  }

  bool perteneceAOtroNegocio(String negocioId) {
    return _negocioActual != null &&
        _items.isNotEmpty &&
        _negocioActual!.id != negocioId;
  }

  String? agregarProducto({
    required Negocio negocio,
    required Producto producto,
    required String usuarioActualId,
    int cantidad = 1,
  }) {
    if (negocio.ownerId == usuarioActualId) {
      return 'No puedes comprar en tu propio puesto';
    }
    if (!negocio.abierto) {
      return 'Este puesto se encuentra cerrado';
    }
    if (!producto.estaDisponible || producto.eliminado) {
      return 'Producto no disponible';
    }
    if (perteneceAOtroNegocio(negocio.id)) {
      return 'CONFLICTO_NEGOCIO';
    }

    _negocioActual ??= negocio;

    final int maxPermitido = producto.tipoInventario == 'UNICO'
        ? 1
        : producto.stockDisponible;
    final existingIndex = _items.indexWhere(
      (item) => item.producto.id == producto.id,
    );
    final int cantidadActual = existingIndex != -1
        ? _items[existingIndex].cantidad
        : 0;

    if (cantidadActual + cantidad > maxPermitido) {
      return 'Stock máximo disponible: $maxPermitido';
    }

    if (existingIndex != -1) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        cantidad: cantidadActual + cantidad,
      );
    } else {
      _items.add(ItemCarrito(producto: producto, cantidad: cantidad));
    }

    _error = null;
    notifyListeners();
    return null;
  }

  void reemplazarCarritoYAgregar({
    required Negocio negocio,
    required Producto producto,
    required String usuarioActualId,
    int cantidad = 1,
  }) {
    _items.clear();
    _negocioActual = negocio;
    agregarProducto(
      negocio: negocio,
      producto: producto,
      usuarioActualId: usuarioActualId,
      cantidad: cantidad,
    );
  }

  String? incrementarCantidad(String productoId) {
    final index = _items.indexWhere((item) => item.producto.id == productoId);
    if (index == -1) return 'Producto no encontrado en el carrito';

    final item = _items[index];
    final producto = item.producto;
    final int maxPermitido = producto.tipoInventario == 'UNICO'
        ? 1
        : producto.stockDisponible;

    if (item.cantidad + 1 > maxPermitido) {
      return 'Stock máximo disponible: $maxPermitido';
    }

    _items[index] = item.copyWith(cantidad: item.cantidad + 1);
    _error = null;
    notifyListeners();
    return null;
  }

  void decrementarCantidad(String productoId) {
    final index = _items.indexWhere((item) => item.producto.id == productoId);
    if (index == -1) return;

    final item = _items[index];
    if (item.cantidad > 1) {
      _items[index] = item.copyWith(cantidad: item.cantidad - 1);
    } else {
      _items.removeAt(index);
    }

    if (_items.isEmpty) {
      _negocioActual = null;
    }
    _error = null;
    notifyListeners();
  }

  void eliminarProducto(String productoId) {
    _items.removeWhere((item) => item.producto.id == productoId);
    if (_items.isEmpty) {
      _negocioActual = null;
    }
    _error = null;
    notifyListeners();
  }

  void limpiarCarrito() {
    _items.clear();
    _negocioActual = null;
    _error = null;
    _validandoStock = false;
    notifyListeners();
  }

  Future<String?> validarDisponibilidadEnServidor() async {
    if (_negocioActual == null || _items.isEmpty) return null;
    _validandoStock = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final negRes = await supabase
          .from('negocios')
          .select()
          .eq('id', _negocioActual!.id)
          .maybeSingle();

      if (negRes == null) {
        _validandoStock = false;
        notifyListeners();
        return 'El negocio ya no se encuentra disponible';
      }
      final bool abierto = negRes['abierto'] ?? false;
      if (!abierto) {
        _validandoStock = false;
        notifyListeners();
        return 'El puesto se encuentra cerrado actualmente';
      }

      for (final item in _items) {
        final prodRes = await supabase
            .from('productos')
            .select()
            .eq('id', item.producto.id)
            .maybeSingle();

        if (prodRes == null) {
          _validandoStock = false;
          notifyListeners();
          return 'El producto "${item.producto.nombre}" ya no existe';
        }

        final bool activo = prodRes['activo'] ?? true;
        final bool eliminado = prodRes['eliminado'] ?? false;
        final String tipoInventario =
            prodRes['tipo_inventario']?.toString() ?? 'RECURRENTE';
        final bool vendidoUnico = prodRes['vendido_unico'] ?? false;
        final int stockDisponible = prodRes['stock_disponible'] ?? 0;

        if (!activo ||
            eliminado ||
            (tipoInventario == 'UNICO' && vendidoUnico)) {
          _validandoStock = false;
          notifyListeners();
          return 'El producto "${item.producto.nombre}" ya no está disponible';
        }

        if (stockDisponible < item.cantidad) {
          _validandoStock = false;
          notifyListeners();
          return 'El producto "${item.producto.nombre}" ha sido reservado por otro vecino o el stock es insuficiente (Disponible: $stockDisponible). Si no completa su compra en 3 minutos, volverá a estar disponible.';
        }
      }

      _validandoStock = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      _validandoStock = false;
      notifyListeners();
      return 'Error al validar disponibilidad: $_error';
    }
  }
}
