import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> obtenerUbicacionActual({double? fallbackLat, double? fallbackLng}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'GPS_APAGADO';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'PERMISO_DENEGADO';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'PERMISO_DENEGADO_PERMANENTE';
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position;
    } catch (_) {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      if (fallbackLat != null && fallbackLng != null) {
        return Position(
          latitude: fallbackLat,
          longitude: fallbackLng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      return Position(
        latitude: -16.5000,
        longitude: -68.1500,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }
}
