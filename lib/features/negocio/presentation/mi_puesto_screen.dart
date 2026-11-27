import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../services/storage_service.dart';
import '../../auth/domain/negocio.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../pedidos/data/pedidos_repository.dart';
import '../../pedidos/domain/resena.dart';
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
  TimeOfDay? _horaApertura;
  TimeOfDay? _horaCierre;

  bool _inicializado = false;
  Negocio? _lastNegocio;
  List<Resena> _resenasPuesto = [];
  bool _cargandoResenas = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _descripcionController = TextEditingController();
    _shippingCostController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final catalogo = context.watch<CatalogoProvider>();
    final auth = context.watch<AuthProvider>();
    final negocio = catalogo.negocioActual ?? auth.negocio;

    if (negocio != null && (!_inicializado || _lastNegocio?.id != negocio.id)) {
      _precargarDatos(negocio);
      _cargarResenasPuesto(negocio.id);
      _lastNegocio = negocio;
      _inicializado = true;
    }
  }

  Future<void> _cargarResenasPuesto(String negocioId) async {
    if (_cargandoResenas) return;
    setState(() => _cargandoResenas = true);
    try {
      final list = await PedidosRepository().listarResenasNegocio(negocioId);
      if (mounted) {
        setState(() {
          _resenasPuesto = list;
          _cargandoResenas = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargandoResenas = false);
      }
    }
  }

  void _precargarDatos(Negocio negocio) {
    _nombreController.text = negocio.nombre;
    _descripcionController.text = negocio.descripcion;

    if (negocio.shippingCost > 0) {
      final double bs = negocio.shippingCost / 100.0;
      _shippingCostController.text = (bs == bs.roundToDouble())
          ? bs.toInt().toString()
          : bs.toStringAsFixed(2);
    } else {
      _shippingCostController.text = '';
    }

    _deliveryPropio = negocio.deliveryOptions.contains('DELIVERY_PROPIO');
    _deliveryRecojo = negocio.deliveryOptions.contains('RECOJO_LOCAL');
    _horaApertura = _parseHora(negocio.horaApertura);
    _horaCierre = _parseHora(negocio.horaCierre);
  }

  TimeOfDay? _parseHora(String? hora) {
    if (hora == null || hora.length < 5) return null;
    final partes = hora.split(':');
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  String? _horaSql(TimeOfDay? hora) => hora == null
      ? null
      : '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00';

  Future<void> _seleccionarHora(bool apertura) async {
    final seleccionada = await showTimePicker(
      context: context,
      initialTime: apertura
          ? (_horaApertura ?? TimeOfDay.now())
          : (_horaCierre ?? TimeOfDay.now()),
    );
    if (seleccionada != null && mounted) {
      setState(() {
        if (apertura) {
          _horaApertura = seleccionada;
        } else {
          _horaCierre = seleccionada;
        }
      });
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
      Notificaciones.mostrar(
        context,
        'Seleccione al menos una opción de entrega',
        error: true,
      );
      return;
    }

    final catalogo = context.read<CatalogoProvider>();
    final authProvider = context.read<AuthProvider>();
    final negocio = catalogo.negocioActual ?? authProvider.negocio;
    if (negocio == null) return;

    setState(() => _guardando = true);

    try {
      String storeUrl = negocio.storePhotoUrl;
      if (_nuevaStoreFile != null) {
        storeUrl = await _storageService.uploadImage(
          _nuevaStoreFile!,
          'negocios_assets',
          'stores',
        );
      }

      String qrUrl = negocio.qrPhotoUrl;
      if (_nuevaQrFile != null) {
        qrUrl = await _storageService.uploadImage(
          _nuevaQrFile!,
          'negocios_assets',
          'qrs',
        );
      }

      int shippingCents = 0;
      if (_deliveryPropio && _shippingCostController.text.trim().isNotEmpty) {
        final shippingDouble =
            Validadores.parsearDecimal(_shippingCostController.text.trim()) ??
            0.0;
        if (shippingDouble > 0) {
          shippingCents = (shippingDouble * 100).round();
        }
      }

      final success = await catalogo.actualizarConfiguracionPuesto(
        negocioId: negocio.id,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        deliveryOptions: deliveryOptions,
        shippingCost: shippingCents,
        qrPhotoUrl: qrUrl,
        storePhotoUrl: storeUrl,
        horaApertura: _horaSql(_horaApertura),
        horaCierre: _horaSql(_horaCierre),
      );

      if (mounted) {
        if (success) {
          final negocioActualizado = (catalogo.negocioActual ?? negocio)
              .copyWith(
                nombre: _nombreController.text.trim(),
                descripcion: _descripcionController.text.trim(),
                deliveryOptions: deliveryOptions,
                shippingCost: shippingCents,
                qrPhotoUrl: qrUrl,
                storePhotoUrl: storeUrl,
                horaApertura: _horaSql(_horaApertura),
                horaCierre: _horaSql(_horaCierre),
              );

          catalogo.setNegocioActual(negocioActualizado);
          authProvider.actualizarNegocio(negocioActualizado);

          Notificaciones.mostrar(context, '¡Puesto actualizado con éxito!');
          setState(() {
            _nuevaStoreFile = null;
            _nuevaQrFile = null;
            _lastNegocio = negocioActualizado;
          });
        } else {
          Notificaciones.mostrar(
            context,
            catalogo.error ?? 'Error al actualizar puesto',
            error: true,
          );
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
    final auth = context.watch<AuthProvider>();
    final negocio = catalogo.negocioActual ?? auth.negocio;

    if (negocio == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mi Puesto',
            style: TextStyle(color: AppTheme.white),
          ),
          backgroundColor: AppTheme.primaryButton,
        ),
        body: Center(
          child: catalogo.cargando || auth.isLoading
              ? const CircularProgressIndicator()
              : const Text('No hay información del negocio registrada.'),
        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Estado Operativo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      negocio.abierto
                          ? 'Puesto Abierto (Aceptando pedidos)'
                          : 'Puesto Cerrado',
                      style: TextStyle(
                        color: negocio.abierto ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: negocio.abierto,
                    activeThumbColor: Colors.green,
                    onChanged: (val) async {
                      final success = await catalogo.actualizarEstadoOperativo(
                        val,
                      );
                      if (!mounted) return;
                      if (success && catalogo.negocioActual != null) {
                        auth.actualizarNegocio(catalogo.negocioActual!);
                      } else if (!success) {
                        if (!context.mounted) return;
                        Notificaciones.mostrar(
                          context,
                          catalogo.error ?? 'Error al actualizar estado',
                          error: true,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Configuración del Puesto',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _nombreController,
                  label: 'Nombre del Negocio',
                  validator: (v) =>
                      Validadores.validarTextoRequerido(v, 'Nombre'),
                  prefixIcon: const Icon(
                    Icons.store,
                    color: AppTheme.primaryButton,
                  ),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _descripcionController,
                  label: 'Descripción',
                  validator: (v) =>
                      Validadores.validarTextoRequerido(v, 'Descripción'),
                  prefixIcon: const Icon(
                    Icons.description,
                    color: AppTheme.primaryButton,
                  ),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Horario operativo (Catálogo Recurrente)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Perecederos y productos únicos siguen regidos por su stock disponible.',
                    style: TextStyle(fontSize: 12),
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _seleccionarHora(true),
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              _horaApertura == null
                                  ? 'Hora de apertura'
                                  : _horaApertura!.format(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _seleccionarHora(false),
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              _horaCierre == null
                                  ? 'Hora de cierre'
                                  : _horaCierre!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _horaApertura = null;
                        _horaCierre = null;
                      }),
                      child: const Text('Quitar horario'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Opciones de Entrega',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                CheckboxListTile(
                  title: const Text('Delivery propio'),
                  value: _deliveryPropio,
                  activeColor: AppTheme.primaryButton,
                  onChanged: (v) {
                    final nuevoVal = v ?? true;
                    if (!nuevoVal && !_deliveryRecojo) {
                      Notificaciones.mostrar(
                        context,
                        'Debe mantener al menos una modalidad de entrega activa',
                        error: true,
                      );
                      return;
                    }
                    setState(() {
                      _deliveryPropio = nuevoVal;
                      if (!nuevoVal) {
                        _shippingCostController.clear();
                      }
                    });
                  },
                ),
                if (_deliveryPropio) ...[
                  const SizedBox(height: 8),
                  CampoTexto(
                    controller: _shippingCostController,
                    label: 'Costo de envío (Bs) (Opcional)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (!_deliveryPropio) return null;
                      if (v == null || v.trim().isEmpty) return null;
                      final val = Validadores.parsearDecimal(v.trim());
                      if (val == null || val < 0) {
                        return 'Ingrese un monto válido (≥ 0)';
                      }
                      return null;
                    },
                    prefixIcon: const Icon(
                      Icons.attach_money,
                      color: AppTheme.primaryButton,
                    ),
                  ),
                ],
                CheckboxListTile(
                  title: const Text('Recojo en local'),
                  value: _deliveryRecojo,
                  activeColor: AppTheme.primaryButton,
                  onChanged: (v) {
                    final nuevoVal = v ?? true;
                    if (!nuevoVal && !_deliveryPropio) {
                      Notificaciones.mostrar(
                        context,
                        'Debe mantener al menos una modalidad de entrega activa',
                        error: true,
                      );
                      return;
                    }
                    setState(() => _deliveryRecojo = nuevoVal);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Fotografías y QR de Pago',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _nuevaStoreFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: XFileImagePreview(
                                    file: _nuevaStoreFile!,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : (negocio.storePhotoUrl.isNotEmpty
                                    ? ClipRRect(
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
                                            child: const Icon(
                                              Icons.storefront,
                                              color: AppTheme.primaryButton,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          color: AppTheme.containers,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.storefront,
                                          color: AppTheme.primaryButton,
                                          size: 40,
                                        ),
                                      )),
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
                                  child: XFileImagePreview(
                                    file: _nuevaQrFile!,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : (negocio.qrPhotoUrl.isNotEmpty
                                    ? ClipRRect(
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
                                            child: const Icon(
                                              Icons.qr_code,
                                              color: AppTheme.primaryButton,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          color: AppTheme.containers,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.qr_code,
                                          color: AppTheme.primaryButton,
                                          size: 40,
                                        ),
                                      )),
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
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Reputación y Reseñas de Vecinos',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 40),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Promedio: ${negocio.calificacionPromedio.toStringAsFixed(1)} / 5.0',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${negocio.totalResenas} ${negocio.totalResenas == 1 ? "opinión recibida" : "opiniones recibidas"}',
                              style: const TextStyle(
                                color: AppTheme.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _cargandoResenas
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryButton,
                        ),
                      )
                    : _resenasPuesto.isEmpty
                    ? const Text(
                        'Aún no tienes opiniones registradas de tus vecinos.',
                        style: TextStyle(color: AppTheme.grey),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _resenasPuesto.length,
                        itemBuilder: (context, index) {
                          final res = _resenasPuesto[index];
                          final nombreComprador = res.compradorNombre?.trim();
                          final String fecha = res.createdAt != null
                              ? '${res.createdAt!.day.toString().padLeft(2, '0')}/${res.createdAt!.month.toString().padLeft(2, '0')}/${res.createdAt!.year}'
                              : '';

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                AppTheme.containers,
                                            backgroundImage:
                                                res.compradorAvatarUrl !=
                                                        null &&
                                                    res
                                                        .compradorAvatarUrl!
                                                        .isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    res.compradorAvatarUrl!,
                                                  ) as ImageProvider
                                                : null,
                                            child:
                                                res.compradorAvatarUrl ==
                                                        null ||
                                                    res
                                                        .compradorAvatarUrl!
                                                        .isEmpty
                                                ? const Icon(
                                                    Icons.person,
                                                    size: 14,
                                                    color:
                                                        AppTheme.primaryButton,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            nombreComprador == null ||
                                                    nombreComprador.isEmpty
                                                ? 'Nombre no disponible'
                                                : nombreComprador,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: List.generate(
                                          res.calificacion,
                                          (_) => const Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (fecha.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      fecha,
                                      style: const TextStyle(
                                        color: AppTheme.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (res.comentario.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      res.comentario,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
