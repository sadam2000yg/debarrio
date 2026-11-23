import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../services/storage_service.dart';
import '../domain/producto.dart';
import 'catalogo_provider.dart';

class _FotoItem {
  final String? url;
  final XFile? file;
  _FotoItem.url(this.url) : file = null;
  _FotoItem.file(this.file) : url = null;
  bool get isUrl => url != null;
}

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
  List<_FotoItem> _fotos = [];
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
    _fotos = p?.fotosUrls.map((u) => _FotoItem.url(u)).toList() ?? [];
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

  int get _totalFotosCount => _fotos.length;

  Future<void> _pickImages(ImageSource source) async {
    if (_totalFotosCount >= 5) {
      Notificaciones.mostrar(context, 'Máximo 5 fotografías permitidas por producto', error: true);
      return;
    }

    if (source == ImageSource.gallery) {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
      );
      if (images.isNotEmpty) {
        setState(() {
          for (final img in images) {
            if (_fotos.length < 5) {
              _fotos.add(_FotoItem.file(img));
            }
          }
        });
      }
    } else {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        setState(() {
          if (_fotos.length < 5) {
            _fotos.add(_FotoItem.file(image));
          }
        });
      }
    }
  }

  void _eliminarFoto(int index) {
    setState(() {
      _fotos.removeAt(index);
    });
  }

  void _moverAPortada(int index) {
    setState(() {
      final item = _fotos.removeAt(index);
      _fotos.insert(0, item);
    });
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    if (_totalFotosCount == 0) {
      Notificaciones.mostrar(context, 'Debe adjuntar al menos una fotografía del producto (1 a 5)', error: true);
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
      final List<String> fotosFinales = await Future.wait(
        _fotos.map((foto) async {
          if (foto.isUrl) {
            return foto.url!;
          } else {
            return await _storageService.uploadImage(foto.file!, 'productos_assets', 'productos');
          }
        }),
      );

      final producto = Producto(
        id: isEditing ? widget.producto!.id : '',
        negocioId: negocio.id,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        fotosUrls: fotosFinales,
        precio: precio,
        tipoInventario: _tipoInventario,
        stockDisponible: stock,
        stockReservado: isEditing ? widget.producto!.stockReservado : 0,
        stockBaseDiario: stockBase,
        activo: isEditing ? widget.producto!.activo : true,
        vendidoUnico: isEditing ? widget.producto!.vendidoUnico : false,
        eliminado: isEditing ? widget.producto!.eliminado : false,
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
                Text(
                  'Galería de Fotos ($_totalFotosCount/5)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._fotos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final foto = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: idx > 0 ? () => _moverAPortada(idx) : null,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: foto.isUrl
                                      ? CachedNetworkImage(
                                          imageUrl: foto.url!,
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : XFileImagePreview(
                                          file: foto.file!,
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: idx == 0 ? AppTheme.primaryButton : Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      idx == 0 ? 'Portada' : 'Usar portada',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () => _eliminarFoto(idx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_totalFotosCount < 5)
                        GestureDetector(
                          onTap: () => _pickImages(ImageSource.gallery),
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.containers,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryButton.withValues(alpha: 0.5)),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: AppTheme.primaryButton, size: 32),
                                SizedBox(height: 4),
                                Text('Añadir foto', style: TextStyle(color: AppTheme.primaryButton, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickImages(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Cámara'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickImages(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Galería múltiple'),
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
