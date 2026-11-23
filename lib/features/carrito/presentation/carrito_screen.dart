import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../negocio/domain/producto.dart';

class CarritoItem {
  final Producto producto;
  int cantidad;

  CarritoItem({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final List<CarritoItem> _items = [];
  String _modalidadEntrega = 'RETIRO'; // 'RETIRO' or 'DOMICILIO'
  double _costoEnvio = 0.0;
  bool _procesando = false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _total => _subtotal + _costoEnvio;

  void _cambiarModalidad(String modalidad) {
    setState(() {
      _modalidadEntrega = modalidad;
      _costoEnvio = modalidad == 'DOMICILIO' ? 5.00 : 0.00;
    });
  }

  Future<void> _enviarPedido() async {
    if (_items.isEmpty) return;
    setState(() => _procesando = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw 'Debe iniciar sesión para realizar un pedido.';
      }

      final negocioId = _items.first.producto.negocioId;

      final pedidoRes = await supabase.from('pedidos').insert({
        'cliente_id': user.id,
        'negocio_id': negocioId,
        'modalidad': _modalidadEntrega,
        'subtotal': _subtotal,
        'costo_envio': _costoEnvio,
        'total': _total,
        'estado': 'Pendiente',
      }).select().single();

      final pedidoId = pedidoRes['id'];

      for (final item in _items) {
        await supabase.from('items_pedido').insert({
          'pedido_id': pedidoId,
          'producto_id': item.producto.id,
          'cantidad': item.cantidad,
          'precio_unitario': item.producto.precio,
        });
      }

      if (mounted) {
        setState(() {
          _items.clear();
        });
        Notificaciones.mostrar(context, '¡Pedido registrado y enviado a Supabase con éxito!');
      }
    } catch (e) {
      if (mounted) {
        Notificaciones.mostrar(context, 'Error al procesar pedido: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 80, color: AppTheme.grey),
                  const SizedBox(height: 16),
                  const Text('Tu carrito está vacío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Explora los puestos cercanos y añade productos.', style: TextStyle(color: AppTheme.grey)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
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
                                  imageUrl: item.producto.fotoUrl,
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
                                    Text(item.producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(item.producto.precioFormateado, style: const TextStyle(color: AppTheme.primaryButton, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.primaryButton),
                                    onPressed: () {
                                      setState(() {
                                        if (item.cantidad > 1) {
                                          item.cantidad--;
                                        } else {
                                          _items.removeAt(index);
                                        }
                                      });
                                    },
                                  ),
                                  Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryButton),
                                    onPressed: () {
                                      setState(() {
                                        item.cantidad++;
                                      });
                                    },
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Modalidad de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Retiro en puerta (0 Bs)'),
                              selected: _modalidadEntrega == 'RETIRO',
                              selectedColor: AppTheme.primaryButton,
                              labelStyle: TextStyle(color: _modalidadEntrega == 'RETIRO' ? Colors.white : AppTheme.textPrimary),
                              onSelected: (_) => _cambiarModalidad('RETIRO'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Entrega a domicilio (5 Bs)'),
                              selected: _modalidadEntrega == 'DOMICILIO',
                              selectedColor: AppTheme.primaryButton,
                              labelStyle: TextStyle(color: _modalidadEntrega == 'DOMICILIO' ? Colors.white : AppTheme.textPrimary),
                              onSelected: (_) => _cambiarModalidad('DOMICILIO'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(color: AppTheme.grey)),
                          Text('Bs ${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Costo de envío:', style: TextStyle(color: AppTheme.grey)),
                          Text('Bs ${_costoEnvio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total a Pagar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('Bs ${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BotonPrincipal(
                        texto: 'Confirmar y Enviar Pedido',
                        cargando: _procesando,
                        onPressed: _enviarPedido,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
