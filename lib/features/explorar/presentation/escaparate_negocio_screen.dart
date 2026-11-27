import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/moderacion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/domain/negocio.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../negocio/domain/producto.dart';
import '../../pedidos/data/pedidos_repository.dart';
import '../../pedidos/domain/item_carrito.dart';
import '../../pedidos/domain/resena.dart';
import '../../pedidos/presentation/carrito_provider.dart';
import '../data/explorar_repository.dart';
import 'detalle_producto_screen.dart';
import 'explorar_provider.dart';

class EscaparateNegocioScreen extends StatefulWidget {
  final String negocioId;

  const EscaparateNegocioScreen({super.key, required this.negocioId});

  @override
  State<EscaparateNegocioScreen> createState() =>
      _EscaparateNegocioScreenState();
}

class _EscaparateNegocioScreenState extends State<EscaparateNegocioScreen> {
  final ExplorarRepository _repository = ExplorarRepository();
  bool _cargando = true;
  Negocio? _negocio;
  List<Producto> _productos = [];
  List<Resena> _resenas = [];
  String? _error;
  RealtimeChannel? _canalProductos;
  int _versionCarga = 0;
  int _versionSuscripcion = 0;

  Future<void> _reportarNegocio() async {
    const motivos = [
      'Contenido ofensivo',
      'Información engañosa',
      'Spam o enlace sospechoso',
      'Otro',
    ];
    String motivo = motivos.first;
    final detalle = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reportar puesto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: motivo,
              items: motivos
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => motivo = value ?? motivo,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
            TextField(
              controller: detalle,
              maxLength: 600,
              decoration: const InputDecoration(labelText: 'Detalle opcional'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || _negocio == null) {
      detalle.dispose();
      return;
    }
    try {
      final error = Moderacion.validarReporte(
        motivo: motivo,
        detalle: detalle.text,
      );
      if (error != null) {
        throw error;
      }
      await _repository.reportarNegocio(
        negocioId: _negocio!.id,
        motivo: motivo,
        detalle: detalle.text,
      );
      if (mounted) {
        Notificaciones.mostrar(
          context,
          'Reporte enviado. Gracias por cuidar la comunidad.',
        );
      }
    } catch (e) {
      if (mounted) {
        Notificaciones.mostrar(context, e.toString(), error: true);
      }
    } finally {
      detalle.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosNegocio();
    _suscribirRealtimeProductos();
  }

  void _suscribirRealtimeProductos() {
    if (_canalProductos != null) {
      _canalProductos!.unsubscribe();
      Supabase.instance.client.removeChannel(_canalProductos!);
      _canalProductos = null;
    }
    final int versionActual = ++_versionSuscripcion;
    _canalProductos = Supabase.instance.client
        .channel('productos_escaparate_${widget.negocioId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'productos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'negocio_id',
            value: widget.negocioId,
          ),
          callback: (_) async {
            if (versionActual != _versionSuscripcion) return;
            await _cargarDatosNegocio();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _versionCarga++;
    _versionSuscripcion++;
    if (_canalProductos != null) {
      _canalProductos!.unsubscribe();
      Supabase.instance.client.removeChannel(_canalProductos!);
      _canalProductos = null;
    }
    super.dispose();
  }

  Future<void> _cargarDatosNegocio() async {
    final int versionActual = ++_versionCarga;
    try {
      if (!mounted) return;
      final explorar = context.read<ExplorarProvider>();
      Negocio? neg;
      try {
        neg = explorar.negociosCercanos.firstWhere(
          (n) => n.id == widget.negocioId,
        );
      } catch (_) {
        final response = await Supabase.instance.client
            .from('negocios')
            .select()
            .eq('id', widget.negocioId)
            .maybeSingle();
        if (!mounted) return;
        if (versionActual != _versionCarga) return;
        if (response != null) {
          neg = Negocio.fromMap(response);
        }
      }

      if (!mounted) return;
      if (versionActual != _versionCarga) return;

      if (neg != null) {
        final prods = await _repository.listarProductosDeNegocio(neg.id);
        if (!mounted) return;
        if (versionActual != _versionCarga) return;

        final res = await PedidosRepository().listarResenasNegocio(neg.id);
        if (!mounted) return;
        if (versionActual != _versionCarga) return;

        setState(() {
          _negocio = neg;
          _productos = prods;
          _resenas = res;
          _cargando = false;
        });
      } else {
        if (!mounted) return;
        if (versionActual != _versionCarga) return;
        setState(() {
          _error = 'No se encontró el negocio';
          _cargando = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (versionActual != _versionCarga) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  void _agregarAlCarrito(
    BuildContext context,
    Producto prod,
    Negocio negocio,
    String usuarioId,
  ) {
    final carrito = context.read<CarritoProvider>();
    final error = carrito.agregarProducto(
      negocio: negocio,
      producto: prod,
      usuarioActualId: usuarioId,
    );

    if (error == 'CONFLICTO_NEGOCIO') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conflicto de Carrito'),
          content: Text(
            "Tu carrito ya tiene productos de '${carrito.negocioActual?.nombre}'. ¿Deseas vaciarlo para agregar productos de '${negocio.nombre}'?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryButton,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                carrito.reemplazarCarritoYAgregar(
                  negocio: negocio,
                  producto: prod,
                  usuarioActualId: usuarioId,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Agregado al carrito')),
                );
              },
              child: const Text(
                'Vaciar y agregar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else if (error != null) {
      Notificaciones.mostrar(context, error, error: true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Agregado al carrito')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final carritoProvider = context.watch<CarritoProvider>();
    final currentUserId = authProvider.userProfile?.id;

    if (_cargando) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryButton),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryButton),
        ),
      );
    }

    if (_error != null || _negocio == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryButton),
        body: Center(
          child: Text(
            _error ?? 'Negocio no disponible',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      );
    }

    final negocio = _negocio!;
    final bool esMiPropioPuesto =
        currentUserId != null && negocio.ownerId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          negocio.nombre,
          style: const TextStyle(color: AppTheme.white),
        ),
        backgroundColor: AppTheme.primaryButton,
        iconTheme: const IconThemeData(color: AppTheme.white),
        actions: [
          if (!esMiPropioPuesto)
            TextButton.icon(
              onPressed: _reportarNegocio,
              icon: const Icon(
                Icons.flag_outlined,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Reportar',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: negocio.storePhotoUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 220,
                    color: AppTheme.containers,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 220,
                    color: AppTheme.containers,
                    child: const Icon(
                      Icons.storefront,
                      size: 60,
                      color: AppTheme.primaryButton,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    child: IconButton(
                      icon: const Icon(
                        Icons.open_in_full,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => abrirImagenExpandida(
                        context,
                        negocio.storePhotoUrl,
                        titulo: negocio.nombre,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          negocio.nombre,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: negocio.abierto
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          negocio.abierto ? 'Abierto' : 'Cerrado',
                          style: TextStyle(
                            color: negocio.abierto
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        negocio.calificacionPromedio.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${negocio.totalResenas} ${negocio.totalResenas == 1 ? "opinión" : "opiniones"})',
                        style: const TextStyle(
                          color: AppTheme.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    negocio.descripcion,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (negocio.horarioLegible != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: AppTheme.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Horario recurrente: ${negocio.horarioLegible}',
                          style: const TextStyle(
                            color: AppTheme.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: negocio.deliveryOptions.map((opt) {
                      return Chip(
                        avatar: Icon(
                          opt == 'DELIVERY_PROPIO'
                              ? Icons.delivery_dining
                              : Icons.store,
                          size: 16,
                          color: AppTheme.primaryButton,
                        ),
                        label: Text(
                          opt == 'DELIVERY_PROPIO'
                              ? 'Delivery Propio'
                              : 'Recojo en Local',
                        ),
                        backgroundColor: AppTheme.containers,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (esMiPropioPuesto) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.amber),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este es tu propio puesto. No puedes comprar tus propios productos en Modo Vecino.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!negocio.abierto) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'El puesto se encuentra cerrado temporalmente.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Ubicación del Puesto',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(negocio.lat, negocio.lng),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.d_barrio',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(negocio.lat, negocio.lng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Catálogo de Productos',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  _productos.isEmpty
                      ? const Text(
                          'No hay productos disponibles en este momento.',
                          style: TextStyle(color: AppTheme.grey),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _productos.length,
                          itemBuilder: (context, index) {
                            final prod = _productos[index];
                            final bool puedeComprar =
                                negocio.abierto &&
                                !esMiPropioPuesto &&
                                prod.estaDisponible;

                            final cartItem = carritoProvider.items.firstWhere(
                              (item) => item.producto.id == prod.id,
                              orElse: () =>
                                  ItemCarrito(producto: prod, cantidad: 0),
                            );
                            final int cantidadEnCarrito = cartItem.cantidad;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetalleProductoScreen(
                                        producto: prod,
                                        puedeComprar: puedeComprar,
                                        negocio: negocio,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 70,
                                        width: 70,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: prod.fotosUrls.isNotEmpty
                                              ? _ProductoFotoView(
                                                  producto: prod,
                                                )
                                              : Container(
                                                  color: AppTheme.containers,
                                                  child: const Icon(
                                                    Icons.fastfood,
                                                    color:
                                                        AppTheme.primaryButton,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prod.nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              prod.precioFormateado,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryButton,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              prod.etiquetaDisponibilidad,
                                              style: TextStyle(
                                                color: prod.estaDisponible
                                                    ? Colors.green.shade800
                                                    : Colors.red.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: puedeComprar
                                                ? AppTheme.primaryButton
                                                : AppTheme.grey,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: puedeComprar
                                              ? () => _agregarAlCarrito(
                                                  context,
                                                  prod,
                                                  negocio,
                                                  currentUserId ?? '',
                                                )
                                              : null,
                                          child: Text(
                                            cantidadEnCarrito > 0
                                                ? 'En carrito: $cantidadEnCarrito'
                                                : 'Agregar',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),
                  Text(
                    'Reseñas Verificadas',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _resenas.isEmpty
                      ? const Text(
                          'Sin reseñas todavía — Sé el primero en calificar',
                          style: TextStyle(color: AppTheme.grey),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _resenas.length,
                          itemBuilder: (context, index) {
                            final res = _resenas[index];
                            final nombreComprador = res.compradorNombre?.trim();
                            final String fecha = res.createdAt != null
                                ? '${res.createdAt!.day.toString().padLeft(2, '0')}/${res.createdAt!.month.toString().padLeft(2, '0')}/${res.createdAt!.year}'
                                : '';

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.containers,
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                                              radius: 16,
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
                                                      size: 16,
                                                      color: AppTheme
                                                          .primaryButton,
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
          ],
        ),
      ),
    );
  }
}

class _ProductoFotoView extends StatefulWidget {
  final Producto producto;

  const _ProductoFotoView({required this.producto});

  @override
  State<_ProductoFotoView> createState() => _ProductoFotoViewState();
}

class _ProductoFotoViewState extends State<_ProductoFotoView> {
  int _paginaActual = 0;

  @override
  Widget build(BuildContext context) {
    final prod = widget.producto;
    return Stack(
      children: [
        PageView.builder(
          itemCount: prod.fotosUrls.length,
          onPageChanged: (index) {
            setState(() {
              _paginaActual = index;
            });
          },
          itemBuilder: (context, photoIndex) {
            return CachedNetworkImage(
              imageUrl: prod.fotosUrls[photoIndex],
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: AppTheme.containers,
                child: const Icon(
                  Icons.fastfood,
                  color: AppTheme.primaryButton,
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_paginaActual + 1}/${prod.fotosUrls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
