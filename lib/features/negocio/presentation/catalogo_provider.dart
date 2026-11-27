import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/negocio.dart';
import '../data/negocio_repository.dart';
import '../domain/producto.dart';

class CatalogoProvider extends ChangeNotifier {
  final NegocioRepository _repository = NegocioRepository();

  bool _cargando = false;
  String? _error;
  Negocio? _negocioActual;
  List<Producto> _productos = [];
  RealtimeChannel? _canalProductosRealtime;
  int _versionCarga = 0;

  bool get cargando => _cargando;
  String? get error => _error;
  Negocio? get negocioActual => _negocioActual;
  List<Producto> get productos => _productos;

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  void _suscribirRealtimeProductos() {
    if (_negocioActual == null) return;
    if (_canalProductosRealtime != null) {
      _canalProductosRealtime!.unsubscribe();
      Supabase.instance.client.removeChannel(_canalProductosRealtime!);
      _canalProductosRealtime = null;
    }
    final int versionSuscripcion = _versionCarga;
    _canalProductosRealtime = Supabase.instance.client
        .channel('productos_catalogo_${_negocioActual!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'productos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'negocio_id',
            value: _negocioActual!.id,
          ),
          callback: (_) async {
            if (_negocioActual == null || versionSuscripcion != _versionCarga) {
              return;
            }
            try {
              final prods = await _repository.listarProductosDeNegocio(
                _negocioActual!.id,
              );
              if (versionSuscripcion != _versionCarga ||
                  _negocioActual == null) {
                return;
              }
              _productos = prods;
              notifyListeners();
            } catch (_) {
              // No sobreescribir _error de una acción del usuario si Realtime falla
            }
          },
        )
        .subscribe();
  }

  Future<void> cargarNegocioYProductos(String ownerId) async {
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final negocio = await _repository.obtenerNegocioPorOwner(ownerId);
      if (versionActual != _versionCarga) return;
      _negocioActual = negocio;
      if (_negocioActual != null) {
        final prods = await _repository.listarProductosDeNegocio(
          _negocioActual!.id,
        );
        if (versionActual != _versionCarga) return;
        _productos = prods;
        _suscribirRealtimeProductos();
      } else {
        _productos = [];
      }
    } catch (e) {
      if (versionActual != _versionCarga) return;
      _error = e.toString();
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<bool> actualizarEstadoOperativo(bool abierto) async {
    if (_negocioActual == null) return false;
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.actualizarEstadoOperativo(_negocioActual!.id, abierto);
      if (versionActual != _versionCarga) return false;
      _negocioActual = _negocioActual!.copyWith(abierto: abierto);
      if (!abierto) {
        _productos = _productos.map((p) {
          if (p.tipoInventario == 'DIARIO_PERECEDERO') {
            return p.copyWith(activo: false);
          }
          return p;
        }).toList();
      }
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      return false;
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  void setNegocioActual(Negocio negocio) {
    _negocioActual = negocio;
    _suscribirRealtimeProductos();
    notifyListeners();
  }

  Future<bool> actualizarConfiguracionPuesto({
    String? negocioId,
    required String nombre,
    required String descripcion,
    required List<String> deliveryOptions,
    required int shippingCost,
    required String qrPhotoUrl,
    required String storePhotoUrl,
    String? horaApertura,
    String? horaCierre,
  }) async {
    final targetId = negocioId ?? _negocioActual?.id;
    if (targetId == null) return false;
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.actualizarConfiguracionPuesto(
        negocioId: targetId,
        nombre: nombre,
        descripcion: descripcion,
        deliveryOptions: deliveryOptions,
        shippingCost: shippingCost,
        qrPhotoUrl: qrPhotoUrl,
        storePhotoUrl: storePhotoUrl,
        horaApertura: horaApertura,
        horaCierre: horaCierre,
      );
      if (versionActual != _versionCarga) return false;
      if (_negocioActual != null) {
        _negocioActual = _negocioActual!.copyWith(
          nombre: nombre,
          descripcion: descripcion,
          deliveryOptions: deliveryOptions,
          shippingCost: shippingCost,
          qrPhotoUrl: qrPhotoUrl,
          storePhotoUrl: storePhotoUrl,
          horaApertura: horaApertura,
          horaCierre: horaCierre,
        );
      }
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      return false;
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<bool> crearProducto(Producto producto) async {
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.crearProducto(producto);
      if (versionActual != _versionCarga) return false;
      if (_negocioActual != null) {
        final prods = await _repository.listarProductosDeNegocio(
          _negocioActual!.id,
        );
        if (versionActual != _versionCarga) return false;
        _productos = prods;
      }
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      return false;
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<bool> actualizarProducto(Producto producto) async {
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.actualizarProducto(producto);
      if (versionActual != _versionCarga) return false;
      _productos = _productos.map((p) {
        if (p.id == updated.id) {
          return updated;
        }
        return p;
      }).toList();
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      return false;
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<bool> alternarActivoProducto(String productoId, bool activo) async {
    final int versionActual = ++_versionCarga;
    try {
      await _repository.alternarActivoProducto(productoId, activo);
      if (versionActual != _versionCarga) return false;
      _productos = _productos.map((p) {
        if (p.id == productoId) {
          return p.copyWith(activo: activo);
        }
        return p;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarProductoLogico(String productoId) async {
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.eliminarProductoLogico(productoId);
      if (versionActual != _versionCarga) return false;
      _productos = _productos.where((p) => p.id != productoId).toList();
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      return false;
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<bool> reiniciarStockDiario() async {
    if (_negocioActual == null) return false;
    final int versionActual = ++_versionCarga;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.reiniciarStockDiario(_negocioActual!.id);
      if (versionActual != _versionCarga) return false;
      final prods = await _repository.listarProductosDeNegocio(
        _negocioActual!.id,
      );
      if (versionActual != _versionCarga) return false;
      _productos = prods;
      return true;
    } catch (e) {
      if (versionActual != _versionCarga) return false;
      _error = e.toString();
      return false;
    } finally {
      if (versionActual == _versionCarga) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<void> recargarProductos() async {
    if (_negocioActual == null) return;
    final int versionActual = ++_versionCarga;
    try {
      final prods = await _repository.listarProductosDeNegocio(
        _negocioActual!.id,
      );
      if (versionActual != _versionCarga) return;
      _productos = prods;
      notifyListeners();
    } catch (e) {
      if (versionActual != _versionCarga) return;
      _error = e.toString();
      notifyListeners();
    }
  }

  void limpiar() {
    _versionCarga++;
    if (_canalProductosRealtime != null) {
      _canalProductosRealtime!.unsubscribe();
      Supabase.instance.client.removeChannel(_canalProductosRealtime!);
      _canalProductosRealtime = null;
    }
    _negocioActual = null;
    _productos = [];
    _error = null;
    _cargando = false;
    notifyListeners();
  }
}
