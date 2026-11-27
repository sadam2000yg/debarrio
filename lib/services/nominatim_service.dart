import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimPlace {
  final String displayName;
  final LatLng location;

  const NominatimPlace({required this.displayName, required this.location});

  factory NominatimPlace.fromMap(Map<String, dynamic> map) {
    final lat = double.tryParse(map['lat']?.toString() ?? '');
    final lon = double.tryParse(map['lon']?.toString() ?? '');
    if (lat == null || lon == null) {
      throw const FormatException('Nominatim devolvió coordenadas inválidas.');
    }
    return NominatimPlace(
      displayName: map['display_name']?.toString() ?? 'Ubicación sin nombre',
      location: LatLng(lat, lon),
    );
  }
}

class NominatimService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'DBarrio/1.0 (contacto@dbarrio.app)',
    'Accept': 'application/json',
  };

  Future<List<NominatimPlace>> buscar(String query) async {
    final texto = query.trim();
    if (texto.length < 3) return const [];

    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {
        'q': texto,
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'bo',
      },
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    _validarRespuesta(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(NominatimPlace.fromMap)
        .toList(growable: false);
  }

  Future<String?> resolverDireccion(LatLng location) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(
      queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
      },
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));
    _validarRespuesta(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['display_name']?.toString();
  }

  void _validarRespuesta(http.Response response) {
    if (response.statusCode == 429) {
      throw const NominatimException(
        'Demasiadas consultas. Intenta nuevamente en unos segundos.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NominatimException(
        'No se pudo buscar la dirección (${response.statusCode}).',
      );
    }
  }
}

class NominatimException implements Exception {
  final String message;

  const NominatimException(this.message);

  @override
  String toString() => message;
}
