import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';
import 'carrito_provider.dart';
import 'pago_qr_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _referenciaController = TextEditingController();
  final PedidosRepository _pedidosRepository = PedidosRepository();

  String _modalidadSeleccionada = 'RETIRO';
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final carrito = context.read<CarritoProvider>();
      if (carrito.negocioActual != null) {
        final options = carrito.negocioActual!.deliveryOptions;
        final hasRetiro = options.contains('RECOJO_LOCAL') || options.contains('RETIRO');
        final hasDelivery = options.contains('DELIVERY_PROPIO') || options.contains('DELIVERY');

        if (hasDelivery && !hasRetiro) {
          setState(() {
            _modalidadSeleccionada = 'DELIVERY';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _confirmarYReservar(CarritoProvider carrito) async {
    if (_modalidadSeleccionada == 'DELIVERY' && !_formKey.currentState!.validate()) {
      return;
    }

    final negocio = carrito.negocioActual;
    if (negocio == null) return;

    setState(() => _procesando = true);

    Pedido? pedido;
    String? errorMsg;

    try {
      final double costoEnvio = _modalidadSeleccionada == 'DELIVERY' ? negocio.shippingCost / 100.0 : 0.0;
      final itemsList = carrito.items.map((item) => {
        'producto_id': item.producto.id,
        'cantidad': item.cantidad,
        'precio_unitario': item.producto.precio,
      }).toList();

      pedido = await _pedidosRepository.crearPedidoAcid(
        negocioId: negocio.id,
        modalidadEntrega: _modalidadSeleccionada,
        referenciaEntrega: _modalidadSeleccionada == 'DELIVERY' ? _referenciaController.text.trim() : null,
        costoEnvio: costoEnvio,
        items: itemsList,
      );

      carrito.limpiarCarrito();
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }

    if (!mounted) return;

    if (errorMsg != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reserva no disponible / Producto ocupado'),
          content: Text(errorMsg!),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (pedido != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PagoQrScreen(pedido: pedido!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CarritoProvider>(
      builder: (context, carrito, child) {
        if (carrito.estaVacio || carrito.negocioActual == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Checkout', style: TextStyle(color: AppTheme.white)),
              backgroundColor: AppTheme.primaryButton,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.remove_shopping_cart, size: 80, color: AppTheme.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay productos en el carrito',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    BotonPrincipal(
                      texto: 'Volver a Explorar',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final negocio = carrito.negocioActual!;
        final options = negocio.deliveryOptions;
        final hasRetiro = options.contains('RECOJO_LOCAL') || options.contains('RETIRO');
        final hasDelivery = options.contains('DELIVERY_PROPIO') || options.contains('DELIVERY');

        final double costoEnvio = _modalidadSeleccionada == 'DELIVERY' ? negocio.shippingCost / 100.0 : 0.0;
        final double subtotal = carrito.subtotalProductos;
        final double total = subtotal + costoEnvio;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Checkout y Reserva', style: TextStyle(color: AppTheme.white)),
            backgroundColor: AppTheme.primaryButton,
            iconTheme: const IconThemeData(color: AppTheme.white),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              negocio.nombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton),
                            ),
                            const SizedBox(height: 4),
                            Text(negocio.descripcion, style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Modalidad de Entrega', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (hasRetiro)
                      InkWell(
                        onTap: () => setState(() => _modalidadSeleccionada = 'RETIRO'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                _modalidadSeleccionada == 'RETIRO' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: AppTheme.primaryButton,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text('Retiro en puerta — Bs 0.00', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    if (hasDelivery)
                      InkWell(
                        onTap: () => setState(() => _modalidadSeleccionada = 'DELIVERY'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                _modalidadSeleccionada == 'DELIVERY' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: AppTheme.primaryButton,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text('Envío a domicilio — Bs ${(negocio.shippingCost / 100.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    if (_modalidadSeleccionada == 'DELIVERY') ...[
                      const SizedBox(height: 16),
                      CampoTexto(
                        controller: _referenciaController,
                        label: 'Referencia exacta de entrega',
                        hint: 'Calle, N° de puerta, color de fachada, etc.',
                        validator: (v) => Validadores.validarTextoRequerido(v, 'Referencia de entrega'),
                        prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryButton),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Resumen del Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton)),
                            const Divider(),
                            ...carrito.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text('${item.cantidad}x ${item.producto.nombre}', style: const TextStyle(fontSize: 14)),
                                  ),
                                  Text('Bs ${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            )),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal productos', style: TextStyle(color: AppTheme.textPrimary)),
                                Text('Bs ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Costo de envío', style: TextStyle(color: AppTheme.textPrimary)),
                                Text('Bs ${costoEnvio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total a pagar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text('Bs ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.timer, color: Colors.amber, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Al confirmar, tu stock quedará reservado por 1 minuto para realizar el pago por QR Simple.',
                              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.brown, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 54,
                      child: BotonPrincipal(
                        texto: 'Confirmar y reservar stock (1 min)',
                        cargando: _procesando,
                        onPressed: _procesando ? null : () => _confirmarYReservar(carrito),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
