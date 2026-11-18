import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../services/storage_service.dart';
import '../domain/producto.dart';
import 'catalogo_provider.dart';

class FormProductoScreen extends StatefulWidget {
  final Producto? producto; // If null, creating new product

  const FormProductoScreen({super.key, this.producto});

  @override
  State<FormProductoScreen> createState() => _FormProductoScreenState();
}

class _FormProductoScreenState extends State<FormProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late TextEditingController _precioController;
  late TextEditingController _stockController;
  late TextEditingController _stockBaseController;

  String _tipoInventario = 'RECURRENTE';
  XFile? _fotoFile;
  String? _fotoUrlActual;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _precioController = TextEditingController(text: p != null ? p.precio.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: p != null ? p.stockDisponible.toString() : '10');
    _stockBaseController = TextEditingController(text: p != null ? p.stockBaseDiario.toString() : '10');
    _tipoInventario = p?.tipoInventario ?? 'RECURRENTE';
    _fotoUrlActual = p?.fotoUrl;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _stockBaseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      setState(() {
        _fotoFile = image;
      });
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fotoFile == null && (_fotoUrlActual == null || _fotoUrlActual!.isEmpty)) {
      Notificaciones.mostrar(context, 'La fotografía del producto es obligatoria', error: true);
      return;
    }

    final catalogo = context.read<CatalogoProvider>();
    final negocio = catalogo.negocioActual;
    if (negocio == null) return;

    setState(() => _guardando = true);

    final isEditing = widget.producto != null;
    final precio = Validadores.parsearDecimal(_precioController.text) ?? 0.0;
    int stock = int.tryParse(_stockController.text) ?? (isEditing ? widget.producto!.stockDisponible : 1);
    int stockBase = int.tryParse(_stockBaseController.text) ?? stock;

    if (_tipoInventario == 'UNICO') {
      stock = 1;
      stockBase = 1;
    } else if (_tipoInventario == 'DIARIO_PERECEDERO') {
      stockBase = int.tryParse(_stockBaseController.text) ?? stock;
      stock = isEditing ? stock : stockBase;
    }

    try {
      String fotoUrl = _fotoUrlActual ?? '';
      if (_fotoFile != null) {
        fotoUrl = await _storageService.uploadImage(_fotoFile!, 'productos_assets', 'productos');
      }

      final producto = Producto(
        id: isEditing ? widget.producto!.id : '',
        negocioId: negocio.id,
        nombre: _nombreController.text,
        descripcion: _descripcionController.text,
        fotoUrl: fotoUrl,
        precio: precio,
        tipoInventario: _tipoInventario,
        stockDisponible: stock,
        stockReservado: isEditing ? widget.producto!.stockReservado : 0,
        stockBaseDiario: stockBase,
        activo: isEditing ? widget.producto!.activo : true,
        vendidoUnico: isEditing ? widget.producto!.vendidoUnico : false,
      );

      bool success;
      if (isEditing) {
        success = await catalogo.actualizarProducto(producto);
      } else {
        success = await catalogo.crearProducto(producto);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          Notificaciones.mostrar(context, isEditing ? '¡Producto actualizado!' : '¡Producto creado con éxito!');
        } else {
          Notificaciones.mostrar(context, catalogo.error ?? 'Error al guardar producto', error: true);
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
    final isEditing = widget.producto != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto', style: const TextStyle(color: AppTheme.white)),
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
                Center(
                  child: Stack(
                    children: [
                      _fotoFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: XFileImagePreview(file: _fotoFile!, height: 140, width: 140, fit: BoxFit.cover),
                            )
                          : (_fotoUrlActual != null && _fotoUrlActual!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _fotoUrlActual!,
                                    height: 140,
                                    width: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 140,
                                      width: 140,
                                      decoration: BoxDecoration(color: AppTheme.containers, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.fastfood, size: 50, color: AppTheme.primaryButton),
                                    ),
                                  ),
                                )
                              : Container(
                                  height: 140,
                                  width: 140,
                                  decoration: BoxDecoration(color: AppTheme.containers, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.fastfood, size: 50, color: AppTheme.primaryButton),
                                )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Cámara'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Galería'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CampoTexto(
                  controller: _nombreController,
                  label: 'Nombre del Producto',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Nombre'),
                  prefixIcon: const Icon(Icons.label, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _descripcionController,
                  label: 'Descripción',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Descripción'),
                  prefixIcon: const Icon(Icons.notes, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _precioController,
                  label: 'Precio (Bs 0.00)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El precio es requerido';
                    final p = Validadores.parsearDecimal(v);
                    if (p == null || p <= 0) return 'El precio debe ser un número mayor a cero (Bs 0.00)';
                    return null;
                  },
                  prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 20),
                Text('Tipo de Inventario', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _tipoInventario,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.containers,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'RECURRENTE', child: Text('Recurrente (Stock continuo)')),
                    DropdownMenuItem(value: 'DIARIO_PERECEDERO', child: Text('Diario Perecedero (Renovable cada día)')),
                    DropdownMenuItem(value: 'UNICO', child: Text('Único (Plato único / Pieza única)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _tipoInventario = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_tipoInventario == 'UNICO') ...[
                  const Text('El inventario para productos ÚNICOS es fijo a 1 unidad.', style: TextStyle(color: AppTheme.grey, fontStyle: FontStyle.italic)),
                ] else if (_tipoInventario == 'DIARIO_PERECEDERO') ...[
                  CampoTexto(
                    controller: _stockBaseController,
                    label: 'Stock Base Diario',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El stock base es requerido';
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) return 'El stock entero debe ser mayor a cero';
                      return null;
                    },
                    prefixIcon: const Icon(Icons.inventory, color: AppTheme.primaryButton),
                  ),
                ] else ...[
                  CampoTexto(
                    controller: _stockController,
                    label: 'Stock Disponible',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El stock es requerido';
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) return 'El stock entero debe ser mayor a cero';
                      return null;
                    },
                    prefixIcon: const Icon(Icons.inventory, color: AppTheme.primaryButton),
                  ),
                ],
                const SizedBox(height: 32),
                BotonPrincipal(
                  texto: isEditing ? 'Actualizar Producto' : 'Crear Producto',
                  cargando: _guardando,
                  onPressed: _guardarProducto,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
