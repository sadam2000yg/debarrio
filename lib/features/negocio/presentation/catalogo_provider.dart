import 'package:flutter/foundation.dart';
import '../../auth/domain/negocio.dart';
import '../data/negocio_repository.dart';
import '../domain/producto.dart';

class CatalogoProvider extends ChangeNotifier {
  final NegocioRepository _repository = NegocioRepository();

  bool _cargando = false;
  String? _error;
  Negocio? _negocioActual;
  List<Producto> _productos = [];

  bool get cargando => _cargando;
  String? get error => _error;
  Negocio? get negocioActual => _negocioActual;
  List<Producto> get productos => _productos;

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  Future<void> cargarNegocioYProductos(String ownerId) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _negocioActual = await _repository.obtenerNegocioPorOwner(ownerId);
      if (_negocioActual != null) {
        _productos = await _repository.listarProductosDeNegocio(_negocioActual!.id);
      } else {
        _productos = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> actualizarEstadoOperativo(bool abierto) async {
    if (_negocioActual == null) return false;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.actualizarEstadoOperativo(_negocioActual!.id, abierto);
      _negocioActual = _negocioActual!.copyWith(abierto: abierto);
      if (!abierto) {
        // Refresh products locally
        _productos = _productos.map((p) {
          if (p.tipoInventario == 'DIARIO_PERECEDERO') {
            return p.copyWith(activo: false);
          }
          return p;
        }).toList();
      }
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarConfiguracionPuesto({
    required String nombre,
    required String descripcion,
    required List<String> deliveryOptions,
    required int shippingCost,
    required String qrPhotoUrl,
    required String storePhotoUrl,
  }) async {
    if (_negocioActual == null) return false;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.actualizarConfiguracionPuesto(
        negocioId: _negocioActual!.id,
        nombre: nombre,
        descripcion: descripcion,
        deliveryOptions: deliveryOptions,
        shippingCost: shippingCost,
        qrPhotoUrl: qrPhotoUrl,
        storePhotoUrl: storePhotoUrl,
      );
      _negocioActual = _negocioActual!.copyWith(
        nombre: nombre,
        descripcion: descripcion,
        deliveryOptions: deliveryOptions,
        shippingCost: shippingCost,
        qrPhotoUrl: qrPhotoUrl,
        storePhotoUrl: storePhotoUrl,
      );
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> crearProducto(Producto producto) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.crearProducto(producto);
      if (_negocioActual != null) {
        _productos = await _repository.listarProductosDeNegocio(_negocioActual!.id);
      }
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarProducto(Producto producto) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.actualizarProducto(producto);
      if (_negocioActual != null) {
        _productos = await _repository.listarProductosDeNegocio(_negocioActual!.id);
      }
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> alternarActivoProducto(String productoId, bool activo) async {
    try {
      await _repository.alternarActivoProducto(productoId, activo);
      _productos = _productos.map((p) {
        if (p.id == productoId) {
          return p.copyWith(activo: activo);
        }
        return p;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reiniciarStockDiario() async {
    if (_negocioActual == null) return false;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.reiniciarStockDiario(_negocioActual!.id);
      _productos = await _repository.listarProductosDeNegocio(_negocioActual!.id);
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
      return false;
    }
  }
}
