import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/domain/negocio.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../negocio/domain/producto.dart';
import '../../pedidos/presentation/carrito_provider.dart';

void abrirImagenExpandida(BuildContext context, String imageUrl, {String? titulo}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (ctx) => Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          if (titulo != null)
            Positioned(
              top: 45,
              left: 20,
              right: 80,
              child: Text(
                titulo,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    ),
  );
}

class DetalleProductoScreen extends StatefulWidget {
  final Producto producto;
  final bool puedeComprar;
  final Negocio negocio;

  const DetalleProductoScreen({
    super.key,
    required this.producto,
    required this.puedeComprar,
    required this.negocio,
  });

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  int _paginaActual = 0;

  void _agregarAlCarrito(BuildContext context, Producto prod, Negocio negocio) {
    final authProvider = context.read<AuthProvider>();
    final carrito = context.read<CarritoProvider>();
    final usuarioId = authProvider.userProfile?.id ?? '';

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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
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
              child: const Text('Vaciar y agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (error != null) {
      Notificaciones.mostrar(context, error, error: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregado al carrito')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final producto = widget.producto;
    final List<String> fotos = producto.fotosUrls.isNotEmpty
        ? producto.fotosUrls
        : (producto.fotoUrl.isNotEmpty ? [producto.fotoUrl] : []);

    return Scaffold(
      appBar: AppBar(
        title: Text(producto.nombre, style: const TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fotos.isNotEmpty)
              SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: fotos.length,
                      onPageChanged: (index) {
                        setState(() {
                          _paginaActual = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: fotos[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.containers,
                            child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryButton)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.containers,
                            child: const Icon(Icons.fastfood, size: 60, color: AppTheme.primaryButton),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_paginaActual + 1}/${fotos.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        child: IconButton(
                          icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                          onPressed: () => abrirImagenExpandida(
                            context,
                            fotos[_paginaActual],
                            titulo: producto.nombre,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 280,
                color: AppTheme.containers,
                child: const Icon(Icons.fastfood, size: 80, color: AppTheme.primaryButton),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          producto.nombre,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bs ${producto.precio.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryButton),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        label: Text(producto.etiquetaDisponibilidad),
                        backgroundColor: producto.estaDisponible ? Colors.green.shade100 : Colors.red.shade100,
                        labelStyle: TextStyle(
                          color: producto.estaDisponible ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Stock disponible: ${producto.stockDisponible}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Descripción',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    producto.descripcion.isNotEmpty ? producto.descripcion : 'Sin descripción disponible.',
                    style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  BotonPrincipal(
                    texto: widget.puedeComprar ? 'Añadir al Carrito' : 'No disponible para compra',
                    onPressed: widget.puedeComprar
                        ? () => _agregarAlCarrito(context, producto, widget.negocio)
                        : null,
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
