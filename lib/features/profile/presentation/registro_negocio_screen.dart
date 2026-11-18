import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/presentation/auth_provider.dart';

class RegistroNegocioScreen extends StatefulWidget {
  const RegistroNegocioScreen({super.key});

  @override
  State<RegistroNegocioScreen> createState() => _RegistroNegocioScreenState();
}

class _RegistroNegocioScreenState extends State<RegistroNegocioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _shippingCostController = TextEditingController();

  XFile? _storePhotoFile;
  XFile? _qrPhotoFile;
  LatLng _selectedLocation = const LatLng(-17.7833, -63.1821);

  bool _deliveryPropio = true;
  bool _deliveryRecojo = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _shippingCostController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isStore) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (image != null) {
      setState(() {
        if (isStore) {
          _storePhotoFile = image;
        } else {
          _qrPhotoFile = image;
        }
      });
    }
  }

  Future<void> _registrarNegocio() async {
    if (!_formKey.currentState!.validate()) return;

    if (_storePhotoFile == null) {
      Notificaciones.mostrar(context, 'La foto del local es obligatoria', error: true);
      return;
    }
    if (_qrPhotoFile == null) {
      Notificaciones.mostrar(context, 'El código QR de pago es obligatorio', error: true);
      return;
    }

    List<String> deliveryOptions = [];
    if (_deliveryPropio) deliveryOptions.add('DELIVERY_PROPIO');
    if (_deliveryRecojo) deliveryOptions.add('RECOJO_LOCAL');

    if (deliveryOptions.isEmpty) {
      Notificaciones.mostrar(context, 'Seleccione al menos una opción de entrega', error: true);
      return;
    }

    final shippingDouble = Validadores.parsearDecimal(_shippingCostController.text) ?? 0.0;
    final shippingCents = (shippingDouble * 100).round();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registrarNegocio(
      nombre: _nombreController.text,
      descripcion: _descripcionController.text,
      storePhoto: _storePhotoFile!,
      qrPhoto: _qrPhotoFile!,
      deliveryOptions: deliveryOptions,
      shippingCost: shippingCents,
      lat: _selectedLocation.latitude,
      lng: _selectedLocation.longitude,
    );

    if (success && mounted) {
      Navigator.pop(context);
      Notificaciones.mostrar(context, '¡Negocio registrado con éxito!');
    } else if (mounted) {
      Notificaciones.mostrar(context, authProvider.errorMessage ?? 'Error al registrar negocio', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Negocio', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Abre tu Negocio en D\'BARRIO',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _nombreController,
                  label: 'Nombre del Negocio',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Nombre del Negocio'),
                  prefixIcon: const Icon(Icons.store, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _descripcionController,
                  label: 'Descripción de productos / servicios',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Descripción'),
                  prefixIcon: const Icon(Icons.description, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _shippingCostController,
                  label: 'Costo de envío (ej. 3.50 o 3,50)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'El costo de envío es requerido';
                    if (Validadores.parsearDecimal(v) == null) return 'Ingrese un número válido';
                    return null;
                  },
                  prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 24),
                Text('Opciones de Entrega', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  title: const Text('Delivery propio'),
                  value: _deliveryPropio,
                  activeColor: AppTheme.primaryButton,
                  onChanged: (v) {
                    final nuevoVal = v ?? true;
                    if (!nuevoVal && !_deliveryRecojo) {
                      Notificaciones.mostrar(context, 'Debe mantener al menos una modalidad de entrega activa', error: true);
                      return;
                    }
                    setState(() => _deliveryPropio = nuevoVal);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Recojo en local'),
                  value: _deliveryRecojo,
                  activeColor: AppTheme.primaryButton,
                  onChanged: (v) {
                    final nuevoVal = v ?? true;
                    if (!nuevoVal && !_deliveryPropio) {
                      Notificaciones.mostrar(context, 'Debe mantener al menos una modalidad de entrega activa', error: true);
                      return;
                    }
                    setState(() => _deliveryRecojo = nuevoVal);
                  },
                ),
                const SizedBox(height: 24),
                Text('Fotografías del Negocio y QR', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _storePhotoFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: XFileImagePreview(file: _storePhotoFile!, height: 100, width: 100, fit: BoxFit.cover),
                                )
                              : Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(color: AppTheme.containers, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.storefront, size: 40, color: AppTheme.primaryButton),
                                ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(true),
                            icon: const Icon(Icons.photo, size: 16),
                            label: const Text('Local'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _qrPhotoFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: XFileImagePreview(file: _qrPhotoFile!, height: 100, width: 100, fit: BoxFit.cover),
                                )
                              : Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(color: AppTheme.containers, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.qr_code, size: 40, color: AppTheme.primaryButton),
                                ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(false),
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: const Text('QR Pago'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Ubicación del Negocio', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectorMapaUbicacion(
                  initialLocation: _selectedLocation,
                  onLocationSelected: (loc) {
                    setState(() {
                      _selectedLocation = loc;
                    });
                  },
                ),
                const SizedBox(height: 32),
                BotonPrincipal(
                  texto: 'Registrar Negocio',
                  cargando: authProvider.isLoading,
                  onPressed: _registrarNegocio,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
