import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/location_service.dart';
import '../../../services/nominatim_service.dart';
import '../../auth/domain/negocio.dart';
import '../../auth/domain/user_profile.dart';
import '../data/explorar_repository.dart';

class ExplorarProvider extends ChangeNotifier {
  final ExplorarRepository _repository = ExplorarRepository();
  final NominatimService _nominatim = NominatimService();

  bool _cargando = false;
  String? _error;
  String? _direccionZona;
  List<Negocio> _negociosCercanos = [];
  double _lat = -16.5000;
  double _lng = -68.1500;
  String _categoriaSeleccionada = 'TODOS';
  String _busquedaTexto = '';
  Timer? _debounceTimer;

  bool get cargando => _cargando;
  String? get error => _error;
  String? get direccionZona => _direccionZona;
  List<Negocio> get negociosCercanos => _negociosCercanos;
  double get lat => _lat;
  double get lng => _lng;
  String get categoriaSeleccionada => _categoriaSeleccionada;
  String get busquedaTexto => _busquedaTexto;

  Future<void> inicializarUbicacionYBuscar(UserProfile? profile) async {
    if (profile != null) {
      _lat = profile.lat;
      _lng = profile.lng;
    }

    try {
      final position = await LocationService.obtenerUbicacionActual(
        fallbackLat: _lat,
        fallbackLng: _lng,
      );
      _lat = position.latitude;
      _lng = position.longitude;
    } catch (_) {
      // Keep profile or default coordinates on error
    }

    await buscarNegocios();
  }

  Future<void> actualizarMiZonaManual() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final position = await LocationService.obtenerUbicacionActual(
        fallbackLat: _lat,
        fallbackLng: _lng,
      );
      _lat = position.latitude;
      _lng = position.longitude;
      await buscarNegocios();
    } catch (e) {
      _error = 'No se pudo actualizar la ubicación: $e';
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> explorarZonaPorTexto(String consulta) async {
    final lugares = await _nominatim.buscar(consulta);
    if (lugares.isEmpty) {
      throw const NominatimException(
        'No encontramos esa calle o zona en Bolivia.',
      );
    }

    final lugar = lugares.first;
    _lat = lugar.location.latitude;
    _lng = lugar.location.longitude;
    _direccionZona = lugar.displayName;
    notifyListeners();
    await buscarNegocios();
  }

  void setCategoria(String categoria) {
    _categoriaSeleccionada = categoria;
    notifyListeners();
    buscarNegocios();
  }

  void setBusqueda(String query) {
    _busquedaTexto = query;
    notifyListeners();

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      buscarNegocios();
    });
  }

  Future<void> buscarNegocios() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _negociosCercanos = await _repository.buscarNegociosCercanos(
        lat: _lat,
        lon: _lng,
        radioMetros: 1000,
        categoria: _categoriaSeleccionada,
        busqueda: _busquedaTexto,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void limpiar() {
    _negociosCercanos = [];
    _categoriaSeleccionada = 'TODOS';
    _busquedaTexto = '';
    _error = null;
    _cargando = false;
    notifyListeners();
  }
}
