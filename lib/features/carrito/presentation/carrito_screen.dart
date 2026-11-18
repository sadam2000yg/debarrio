import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class CartItemMock {
  final String id;
  final String nombre;
  final double precio;
  int cantidad;
  final String fotoUrl;

  CartItemMock({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.fotoUrl,
  });
}

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final List<CartItemMock> _items = [
    CartItemMock(
      id: 'p1',
      nombre: 'Pan Casero Integral (Paquete de 4)',
      precio: 6.50,
      cantidad: 2,
      fotoUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
    ),
    CartItemMock(
      id: 'p2',
      nombre: 'Queso Criollo del Valle (500g)',
      precio: 18.00,
      cantidad: 1,
      fotoUrl: 'https://images.unsplash.com/photo-1452195100486-9cc805987862?w=400',
    ),
    CartItemMock(
      id: 'p3',
      nombre: 'Tomates Frescos Seleccionados (1kg)',
      precio: 8.50,
      cantidad: 1,
      fotoUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400',
    ),
  ];

  String _modalidadEntrega = 'RETIRO'; // 'RETIRO' or 'DOMICILIO'
  double _costoEnvio = 0.0;

  double get _subtotal => _items.fold(0, (sum, item) => sum + (item.precio * item.cantidad));
  double get _total => _subtotal + _costoEnvio;

  void _cambiarModalidad(String modalidad) {
    setState(() {
      _modalidadEntrega = modalidad;
      _costoEnvio = modalidad == 'DOMICILIO' ? 5.00 : 0.00;
    });
  }

  void _mostrarQrPago() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pago por QR Simple', style: TextStyle(color: AppTheme.primaryButton, fontWeight: FontWeight.bold)),
        content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Escanea el código QR con tu aplicación bancaria para completar el pago:', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: 'https://images.unsplash.com/photo-1622630998477-20aa696ecb05?w=400',
              height: 200,
              width: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text('Total a pagar: Bs ${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar', style: TextStyle(color: AppTheme.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
          onPressed: () {
            Navigator.pop(ctx);
            setState(() {
              _items.clear();
            });
            Notificaciones.mostrar(context, '¡Pago exitoso! Pedido enviado al emprendedor.');
          },
          child: const Text('Simular Pago Exitoso', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito (Puesto: Doña Rosa)', style: TextStyle(color: AppTheme.white)),
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
                                  imageUrl: item.fotoUrl,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text('Bs ${item.precio.toStringAsFixed(2)} c/u', style: const TextStyle(color: AppTheme.primaryButton, fontWeight: FontWeight.bold)),
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
                        texto: 'Proceder al Pago (QR Simple)',
                        onPressed: _mostrarQrPago,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
