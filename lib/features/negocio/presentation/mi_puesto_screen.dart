import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../services/storage_service.dart';
import 'catalogo_provider.dart';

class MiPuestoScreen extends StatefulWidget {
  const MiPuestoScreen({super.key});

  @override
  State<MiPuestoScreen> createState() => _MiPuestoScreenState();
}

class _MiPuestoScreenState extends State<MiPuestoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late TextEditingController _shippingCostController;

  bool _deliveryPropio = true;
  bool _deliveryRecojo = true;
  XFile? _nuevaQrFile;
  XFile? _nuevaStoreFile;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final catalogo = context.read<CatalogoProvider>();
    final negocio = catalogo.negocioActual;
    _nombreController = TextEditingController(text: negocio?.nombre ?? '');
    _descripcionController = TextEditingController(text: negocio?.descripcion ?? '');
    _shippingCostController = TextEditingController(
      text: negocio != null ? (negocio.shippingCost / 100).toStringAsFixed(2) : '0.00',
    );
    if (negocio != null) {
      _deliveryPropio = negocio.deliveryOptions.contains('DELIVERY_PROPIO');
      _deliveryRecojo = negocio.deliveryOptions.contains('RECOJO_LOCAL');
    }
  }

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
          _nuevaStoreFile = image;
        } else {
          _nuevaQrFile = image;
        }
      });
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    List<String> deliveryOptions = [];
    if (_deliveryPropio) deliveryOptions.add('DELIVERY_PROPIO');
    if (_deliveryRecojo) deliveryOptions.add('RECOJO_LOCAL');

    if (deliveryOptions.isEmpty) {
      Notificaciones.mostrar(context, 'Seleccione al menos una opción de entrega', error: true);
      return;
    }

    final catalogo = context.read<CatalogoProvider>();
    final negocio = catalogo.negocioActual;
    if (negocio == null) return;

    setState(() => _guardando = true);

    try {
      String storeUrl = negocio.storePhotoUrl;
      if (_nuevaStoreFile != null) {
        storeUrl = await _storageService.uploadImage(_nuevaStoreFile!, 'negocios_assets', 'stores');
      }

      String qrUrl = negocio.qrPhotoUrl;
      if (_nuevaQrFile != null) {
        qrUrl = await _storageService.uploadImage(_nuevaQrFile!, 'negocios_assets', 'qrs');
      }

      final shippingDouble = Validadores.parsearDecimal(_shippingCostController.text) ?? 0.0;
      final shippingCents = (shippingDouble * 100).round();

      final success = await catalogo.actualizarConfiguracionPuesto(
        nombre: _nombreController.text,
        descripcion: _descripcionController.text,
        deliveryOptions: deliveryOptions,
        shippingCost: shippingCents,
        qrPhotoUrl: qrUrl,
        storePhotoUrl: storeUrl,
      );

      if (mounted) {
        if (success) {
          Notificaciones.mostrar(context, '¡Puesto actualizado con éxito!');
          setState(() {
            _nuevaStoreFile = null;
            _nuevaQrFile = null;
          });
        } else {
          Notificaciones.mostrar(context, catalogo.error ?? 'Error al actualizar puesto', error: true);
        }
      }
    } catch (e) {
      if (mounted) Notificaciones.mostrar(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    final negocio = catalogo.negocioActual;

    if (negocio == null) {
      return const Scaffold(
        body: Center(child: Text('No hay información del negocio registrada.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Puesto', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    title: const Text('Estado Operativo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      negocio.abierto ? 'Puesto Abierto (Aceptando pedidos)' : 'Puesto Cerrado',
                      style: TextStyle(color: negocio.abierto ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
                    ),
                    value: negocio.abierto,
                    activeThumbColor: Colors.green,
                    onChanged: (val) async {
                      final success = await catalogo.actualizarEstadoOperativo(val);
                      if (!mounted) return;
                      if (!success) {
                        // ignore: use_build_context_synchronously
                        Notificaciones.mostrar(context, catalogo.error ?? 'Error al actualizar estado', error: true);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text('Configuración del Puesto', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryButton)),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _nombreController,
                  label: 'Nombre del Negocio',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Nombre'),
                  prefixIcon: const Icon(Icons.store, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _descripcionController,
                  label: 'Descripción',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Descripción'),
                  prefixIcon: const Icon(Icons.description, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _shippingCostController,
                  label: 'Costo de envío (Bs)',
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
                  onChanged: (v) => setState(() => _deliveryPropio = v ?? true),
                ),
                CheckboxListTile(
                  title: const Text('Recojo en local'),
                  value: _deliveryRecojo,
                  activeColor: AppTheme.primaryButton,
                  onChanged: (v) => setState(() => _deliveryRecojo = v ?? true),
                ),
                const SizedBox(height: 24),
                Text('Fotografías y QR de Pago', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _nuevaStoreFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(_nuevaStoreFile!.path), height: 100, width: 100, fit: BoxFit.cover),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    negocio.storePhotoUrl,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 100,
                                      width: 100,
                                      color: AppTheme.containers,
                                      child: const Icon(Icons.storefront, color: AppTheme.primaryButton),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(true),
                            icon: const Icon(Icons.photo, size: 16),
                            label: const Text('Cambiar Local'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _nuevaQrFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(_nuevaQrFile!.path), height: 100, width: 100, fit: BoxFit.cover),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    negocio.qrPhotoUrl,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 100,
                                      width: 100,
                                      color: AppTheme.containers,
                                      child: const Icon(Icons.qr_code, color: AppTheme.primaryButton),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(false),
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: const Text('Cambiar QR'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                BotonPrincipal(
                  texto: 'Guardar Cambios del Puesto',
                  cargando: _guardando || catalogo.cargando,
                  onPressed: _guardarCambios,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
