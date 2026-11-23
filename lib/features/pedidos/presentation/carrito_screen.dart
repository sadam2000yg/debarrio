import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import 'carrito_provider.dart';
import 'checkout_screen.dart';

class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CarritoProvider>(
      builder: (context, carrito, child) {
        if (carrito.estaVacio) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Mi Carrito', style: TextStyle(color: AppTheme.white)),
              backgroundColor: AppTheme.primaryButton,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 80, color: AppTheme.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu carrito está vacío',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explora los puestos cercanos de tu barrio y agrega productos de un mismo puesto',
                      style: TextStyle(color: AppTheme.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi Carrito', style: TextStyle(color: AppTheme.white)),
            backgroundColor: AppTheme.primaryButton,
          ),
          body: Column(
            children: [
              if (carrito.negocioActual != null)
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                carrito.negocioActual!.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Vaciar Carrito'),
                                    content: const Text('¿Estás seguro de que deseas vaciar tu carrito?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          carrito.limpiarCarrito();
                                        },
                                        child: const Text('Vaciar', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              label: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(carrito.negocioActual!.descripcion, style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('Categoría: ${carrito.negocioActual!.categoria}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: carrito.items.length,
                  itemBuilder: (context, index) {
                    final item = carrito.items[index];
                    final prod = item.producto;
                    final int maxPermitido = prod.tipoInventario == 'UNICO' ? 1 : prod.stockDisponible;

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
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  height: 60,
                                  width: 60,
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
                                  Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(prod.precioFormateado, style: const TextStyle(color: AppTheme.primaryButton, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('Subtotal: Bs ${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: const Icon(Icons.remove, size: 20, color: AppTheme.primaryButton),
                                    onPressed: () => carrito.decrementarCantidad(prod.id),
                                  ),
                                ),
                                Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: const Icon(Icons.add, size: 20, color: AppTheme.primaryButton),
                                    onPressed: item.cantidad < maxPermitido
                                        ? () => carrito.incrementarCantidad(prod.id)
                                        : null,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                  onPressed: () => carrito.eliminarProducto(prod.id),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal productos:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                          Text('Bs ${carrito.subtotalProductos.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El costo de envío (Bs 0.00 en retiro o Bs 5.00 delivery) se calculará en el siguiente paso',
                        style: TextStyle(color: AppTheme.grey, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 54,
                        child: BotonPrincipal(
                          texto: 'Continuar al Checkout',
                          cargando: carrito.validandoStock,
                          onPressed: carrito.validandoStock
                              ? null
                              : () async {
                                  final error = await carrito.validarDisponibilidadEnServidor();
                                  if (!context.mounted) return;
                                  if (error != null) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Aviso de Stock'),
                                        content: Text(error),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
