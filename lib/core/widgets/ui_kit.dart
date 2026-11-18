import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../theme/app_theme.dart';

class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: cargando ? null : onPressed,
      child: cargando
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: AppTheme.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(texto),
    );
  }
}

class CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const CampoTexto({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
    );
  }
}

class CampoContrasena extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const CampoContrasena({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.validator,
  });

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.primaryButton),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
    );
  }
}

class SelectorMapaUbicacion extends StatefulWidget {
  final LatLng initialLocation;
  final ValueChanged<LatLng> onLocationSelected;

  const SelectorMapaUbicacion({
    super.key,
    required this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<SelectorMapaUbicacion> createState() => _SelectorMapaUbicacionState();
}

class _SelectorMapaUbicacionState extends State<SelectorMapaUbicacion> {
  late LatLng _currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final position = await LocationService.obtenerUbicacionActual(
        fallbackLat: _currentLocation.latitude,
        fallbackLng: _currentLocation.longitude,
      );
      final newLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = newLatLng;
      });
      _mapController.move(newLatLng, 16);
      widget.onLocationSelected(newLatLng);
    } catch (e) {
      if (mounted) {
        if (e.toString() == 'GPS_APAGADO' || e.toString() == 'PERMISO_DENEGADO_PERMANENTE' || e.toString() == 'PERMISO_DENEGADO') {
          _mostrarDialogoConfiguracionUbicacion(e.toString());
        } else {
          Notificaciones.mostrar(context, 'Error al obtener ubicación: $e', error: true);
        }
      }
    }
  }

  void _mostrarDialogoConfiguracionUbicacion(String errorType) {
    String mensaje = 'Los servicios de ubicación son necesarios para ubicar tu puesto o residencia en D\'BARRIO.';
    if (errorType == 'GPS_APAGADO') {
      mensaje = 'El GPS está desactivado. Por favor, activa la ubicación en la configuración del dispositivo.';
    } else if (errorType == 'PERMISO_DENEGADO_PERMANENTE') {
      mensaje = 'Los permisos de ubicación fueron denegados permanentemente. Por favor, habilítalos en la configuración de la aplicación.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración de Ubicación'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
            onPressed: () async {
              Navigator.pop(context);
              if (errorType == 'GPS_APAGADO') {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
            },
            child: const Text('Abrir Configuración', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _currentLocation = latLng;
                  });
                  widget.onLocationSelected(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.d_barrio',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _obtenerUbicacionActual,
          icon: const Icon(Icons.my_location),
          label: const Text('Usar mi ubicación actual'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryButton,
            side: const BorderSide(color: AppTheme.primaryButton),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class Notificaciones {
  static void mostrar(BuildContext context, String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? AppTheme.error : AppTheme.primaryButton,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class XFileImagePreview extends StatelessWidget {
  final XFile file;
  final double? width;
  final double? height;
  final BoxFit fit;

  const XFileImagePreview({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: AppTheme.containers,
          child: const Icon(Icons.broken_image, color: AppTheme.primaryButton),
        ),
      );
    } else {
      return Image.file(
        File(file.path),
        width: width,
        height: height,
        fit: fit,
      );
    }
  }
}
