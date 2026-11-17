import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/domain/negocio.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../negocio/domain/producto.dart';
import '../data/explorar_repository.dart';
import '../domain/resena.dart';
import 'explorar_provider.dart';

class EscaparateNegocioScreen extends StatefulWidget {
  final String negocioId;

  const EscaparateNegocioScreen({super.key, required this.negocioId});

  @override
  State<EscaparateNegocioScreen> createState() => _EscaparateNegocioScreenState();
}

class _EscaparateNegocioScreenState extends State<EscaparateNegocioScreen> {
  final ExplorarRepository _repository = ExplorarRepository();
  bool _cargando = true;
  Negocio? _negocio;
  List<Producto> _productos = [];
  List<Resena> _resenas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatosNegocio();
  }

  Future<void> _cargarDatosNegocio() async {
    try {
      final explorar = context.read<ExplorarProvider>();
      Negocio? neg;
      try {
        neg = explorar.negociosCercanos.firstWhere((n) => n.id == widget.negocioId);
      } catch (_) {
        final response = await Supabase.instance.client
            .from('negocios')
            .select()
            .eq('id', widget.negocioId)
            .maybeSingle();
        if (response != null) {
          neg = Negocio.fromMap(response);
        }
      }

      if (neg != null) {
        final prods = await _repository.listarProductosDeNegocio(neg.id);
        final res = await _repository.obtenerResenasDeNegocio(neg.id);
        if (mounted) {
          setState(() {
            _negocio = neg;
            _productos = prods;
            _resenas = res;
            _cargando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'No se encontró el negocio';
            _cargando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.userProfile?.id;

    if (_cargando) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryButton),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryButton)),
      );
    }

    if (_error != null || _negocio == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryButton),
        body: Center(child: Text(_error ?? 'Negocio no disponible', style: const TextStyle(color: AppTheme.error))),
      );
    }

    final negocio = _negocio!;
    final bool esMiPropioPuesto = currentUserId != null && negocio.ownerId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(negocio.nombre, style: const TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CachedNetworkImage(
              imageUrl: negocio.storePhotoUrl,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 220,
                color: AppTheme.containers,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 220,
                color: AppTheme.containers,
                child: const Icon(Icons.storefront, size: 60, color: AppTheme.primaryButton),
              ),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: negocio.abierto ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          negocio.abierto ? 'Abierto' : 'Cerrado',
                          style: TextStyle(
                            color: negocio.abierto ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(negocio.descripcion, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: negocio.deliveryOptions.map((opt) {
                      return Chip(
                        avatar: Icon(opt == 'DELIVERY_PROPIO' ? Icons.delivery_dining : Icons.store, size: 16, color: AppTheme.primaryButton),
                        label: Text(opt == 'DELIVERY_PROPIO' ? 'Delivery Propio' : 'Recojo en Local'),
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
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Ubicación del Puesto', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Catálogo de Productos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
                  const SizedBox(height: 12),
                  _productos.isEmpty
                      ? const Text('No hay productos disponibles en este momento.', style: TextStyle(color: AppTheme.grey))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _productos.length,
                          itemBuilder: (context, index) {
                            final prod = _productos[index];
                            final bool puedeComprar = negocio.abierto && !esMiPropioPuesto && prod.estaDisponible;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: prod.fotoUrl,
                                        height: 70,
                                        width: 70,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Container(
                                          height: 70,
                                          width: 70,
                                          color: AppTheme.containers,
                                          child: const Icon(Icons.fastfood, color: AppTheme.primaryButton),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(prod.precioFormateado, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryButton)),
                                          const SizedBox(height: 4),
                                          Text(
                                            prod.etiquetaDisponibilidad,
                                            style: TextStyle(
                                              color: prod.estaDisponible ? Colors.green.shade800 : Colors.red.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: puedeComprar ? AppTheme.primaryButton : AppTheme.grey,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: puedeComprar
                                          ? () {
                                              Notificaciones.mostrar(context, 'Añadido al carrito — Próximo Sprint 3');
                                            }
                                          : null,
                                      child: const Text('Comprar', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),
                  Text('Reseñas Verificadas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _resenas.isEmpty
                      ? const Text('Aún no hay reseñas para este puesto.', style: TextStyle(color: AppTheme.grey))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _resenas.length,
                          itemBuilder: (context, index) {
                            final res = _resenas[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(res.nombreUsuario, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Row(
                                          children: List.generate(
                                            res.calificacion,
                                            (_) => const Icon(Icons.star, size: 14, color: Colors.amber),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (res.comentario.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(res.comentario, style: const TextStyle(fontSize: 13)),
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
