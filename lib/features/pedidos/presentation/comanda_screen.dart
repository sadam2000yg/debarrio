import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';

class ComandaScreen extends StatefulWidget {
  const ComandaScreen({super.key});

  @override
  State<ComandaScreen> createState() => _ComandaScreenState();
}

class _ComandaScreenState extends State<ComandaScreen> {
  final PedidosRepository _repository = PedidosRepository();
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String? _error;
  final Set<String> _procesandoIds = {};
  Timer? _timer;
  RealtimeChannel? _canalComanda;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarComanda();
    });
  }

  void _inicializarComanda() {
    final negocioId = context.read<AuthProvider>().negocio?.id;
    if (negocioId != null && negocioId.isNotEmpty) {
      _cargarPedidos();
      _iniciarTimer();
      _suscribirRealtime(negocioId);
    } else {
      setState(() {
        _cargando = false;
        _pedidos = [];
      });
    }
  }

  Future<void> _cargarPedidos() async {
    final negocioId = context.read<AuthProvider>().negocio?.id;
    if (negocioId == null || negocioId.isEmpty) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _pedidos = [];
        });
      }
      return;
    }

    try {
      await _repository.liberarPedidosExpirados();
      final list = await _repository.listarPedidosNegocio(negocioId);
      if (mounted) {
        setState(() {
          _pedidos = list;
          _cargando = false;
          _error = null;
        });
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

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      bool huboExpirados = false;
      for (final p in _pedidos) {
        if ((p.estado == 'ESPERANDO_PAGO' || p.estado == 'PAGO_EN_REVISION') && p.tiempoRestante <= Duration.zero) {
          huboExpirados = true;
          break;
        }
      }

      if (huboExpirados) {
        await _repository.liberarPedidosExpirados();
        await _cargarPedidos();
      } else {
        setState(() {});
      }
    });
  }

  void _suscribirRealtime(String negocioId) {
    _canalComanda?.unsubscribe();
    _canalComanda = Supabase.instance.client
        .channel('comanda_$negocioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedidos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'negocio_id',
            value: negocioId,
          ),
          callback: (_) {
            _cargarPedidos();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_canalComanda != null) {
      Supabase.instance.client.removeChannel(_canalComanda!);
    }
    super.dispose();
  }

  Future<void> _responderPago({required String pedidoId, required bool confirmado}) async {
    setState(() {
      _procesandoIds.add(pedidoId);
    });

    try {
      await _repository.responderPagoVendedor(pedidoId: pedidoId, confirmado: confirmado);
      await _cargarPedidos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmado
                ? 'Pago confirmado — Pedido en preparación'
                : 'Se alertó al comprador para verificar su pago',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Notificaciones.mostrar(context, 'Error al responder pago: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _procesandoIds.remove(pedidoId);
        });
      }
    }
  }

  Future<void> _avanzarEstado(Pedido pedido) async {
    setState(() {
      _procesandoIds.add(pedido.id);
    });

    try {
      final nuevoEstado = await _repository.avanzarEstadoPedido(pedido.id);
      await _cargarPedidos();
      if (!mounted) return;

      final mensaje = nuevoEstado == 'LISTO'
          ? 'Pedido marcado como LISTO — Vecino notificado'
          : 'Pedido ENTREGADO con éxito';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } catch (e) {
      if (!mounted) return;
      Notificaciones.mostrar(context, 'Error al avanzar estado: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _procesandoIds.remove(pedido.id);
        });
      }
    }
  }

  Widget _buildEstadoBadge(String estado) {
    String label;
    Color colorBg;
    Color colorTxt;

    switch (estado) {
      case 'ESPERANDO_PAGO':
        label = 'Esperando pago';
        colorBg = Colors.orange.shade100;
        colorTxt = Colors.orange.shade900;
        break;
      case 'PAGO_EN_REVISION':
        label = 'Verificar Pago QR';
        colorBg = Colors.amber.shade100;
        colorTxt = Colors.amber.shade900;
        break;
      case 'EN_PREPARACION':
        label = 'En preparación';
        colorBg = Colors.blue.shade100;
        colorTxt = Colors.blue.shade900;
        break;
      case 'LISTO':
        label = 'Listo para entrega';
        colorBg = Colors.indigo.shade100;
        colorTxt = Colors.indigo.shade900;
        break;
      case 'ENTREGADO':
        label = 'Entregado';
        colorBg = Colors.green.shade100;
        colorTxt = Colors.green.shade900;
        break;
      case 'CANCELADO_POR_TIEMPO':
        label = 'Cancelado por tiempo';
        colorBg = Colors.red.shade100;
        colorTxt = Colors.red.shade900;
        break;
      default:
        label = estado;
        colorBg = AppTheme.containers;
        colorTxt = AppTheme.textPrimary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colorBg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: colorTxt, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final negocio = context.watch<AuthProvider>().negocio;

    if (negocio == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Comanda del Puesto', style: TextStyle(color: AppTheme.white)),
          backgroundColor: AppTheme.primaryButton,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Registra tu negocio para recibir comandas de tus vecinos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final pagosPorVerificar = _pedidos.where((p) => p.estado == 'PAGO_EN_REVISION').toList();
    final pedidosActivos = _pedidos.where((p) => p.estado == 'EN_PREPARACION' || p.estado == 'LISTO').toList();
    final historialYEsperando = _pedidos.where((p) => p.estado == 'ESPERANDO_PAGO' || p.estado == 'ENTREGADO' || p.estado == 'CANCELADO_POR_TIEMPO' || p.estado == 'EN_DISPUTA').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Comanda — ${negocio.nombre}', style: const TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryButton))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: AppTheme.error),
                        const SizedBox(height: 16),
                        Text('Error al cargar comanda: $_error', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
                          onPressed: () {
                            setState(() => _cargando = true);
                            _cargarPedidos();
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _pedidos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 80, color: AppTheme.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No tienes pedidos pendientes en tu comanda',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Los nuevos pedidos de tus vecinos aparecerán aquí en tiempo real.',
                              style: TextStyle(color: AppTheme.grey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (pagosPorVerificar.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.qr_code_scanner, color: Colors.amber, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Sección 1 — Pagos QR por verificar (${pagosPorVerificar.length})',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.brown.shade900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...pagosPorVerificar.map((pedido) {
                              final Duration restante = pedido.tiempoRestante;
                              final bool esUrgente = restante.inSeconds < 45;
                              final String minStr = restante.inMinutes.remainder(60).toString().padLeft(2, '0');
                              final String secStr = restante.inSeconds.remainder(60).toString().padLeft(2, '0');
                              final bool estaProcesando = _procesandoIds.contains(pedido.id);

                              return Card(
                                key: ValueKey(pedido.id),
                                elevation: 3,
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: esUrgente ? Colors.red.shade400 : Colors.amber.shade400, width: 2),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: AppTheme.containers,
                                                backgroundImage: pedido.compradorSelfieUrl != null && pedido.compradorSelfieUrl!.isNotEmpty
                                                    ? CachedNetworkImageProvider(pedido.compradorSelfieUrl!) as ImageProvider
                                                    : null,
                                                child: pedido.compradorSelfieUrl == null || pedido.compradorSelfieUrl!.isEmpty
                                                    ? const Icon(Icons.person, size: 20, color: AppTheme.primaryButton)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                pedido.compradorNombre ?? 'Vecino verificado',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: esUrgente ? Colors.red.shade100 : Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.timer_outlined, size: 14, color: esUrgente ? Colors.red.shade900 : Colors.amber.shade900),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$minStr:$secStr min',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: esUrgente ? Colors.red.shade900 : Colors.amber.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Modalidad: ${pedido.modalidadEntrega == 'DELIVERY' ? "Envío a domicilio" : "Retiro en puerta"}',
                                        style: const TextStyle(color: AppTheme.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      if (pedido.referenciaEntrega != null && pedido.referenciaEntrega!.isNotEmpty)
                                        Text('Referencia: ${pedido.referenciaEntrega}', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                      const Divider(height: 20),
                                      ...pedido.detalles.map((d) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text('${d.cantidad}x ${d.nombreProducto}', style: const TextStyle(fontSize: 14))),
                                            Text('Bs ${d.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      )),
                                      const Divider(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Verificar en tu banco:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                                            Text(
                                              'Bs ${pedido.total.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 48,
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: const BorderSide(color: Colors.red),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: estaProcesando ? null : () => _responderPago(pedidoId: pedido.id, confirmado: false),
                                                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                                label: const Text('No realizado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SizedBox(
                                              height: 48,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.primaryButton,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: estaProcesando ? null : () => _responderPago(pedidoId: pedido.id, confirmado: true),
                                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                                label: const Text('Confirmado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          if (pedidosActivos.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.delivery_dining, color: AppTheme.primaryButton, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Sección 2 — Pedidos activos en preparación / listos (${pedidosActivos.length})',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...pedidosActivos.map((pedido) {
                              final String modalidad = pedido.modalidadEntrega == 'DELIVERY' ? 'Envío a domicilio' : 'Retiro en puerta';
                              final bool estaProcesando = _procesandoIds.contains(pedido.id);

                              return Card(
                                key: ValueKey(pedido.id),
                                elevation: 3,
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: pedido.estado == 'EN_PREPARACION' ? Colors.blue.shade400 : Colors.indigo.shade400,
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: AppTheme.containers,
                                                backgroundImage: pedido.compradorSelfieUrl != null && pedido.compradorSelfieUrl!.isNotEmpty
                                                    ? CachedNetworkImageProvider(pedido.compradorSelfieUrl!) as ImageProvider
                                                    : null,
                                                child: pedido.compradorSelfieUrl == null || pedido.compradorSelfieUrl!.isEmpty
                                                    ? const Icon(Icons.person, size: 20, color: AppTheme.primaryButton)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                pedido.compradorNombre ?? 'Vecino verificado',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          _buildEstadoBadge(pedido.estado),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Modalidad: $modalidad',
                                        style: const TextStyle(color: AppTheme.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      if (pedido.referenciaEntrega != null && pedido.referenciaEntrega!.isNotEmpty)
                                        Text('Referencia: ${pedido.referenciaEntrega}', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                      const Divider(height: 20),
                                      ...pedido.detalles.map((d) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text('${d.cantidad}x ${d.nombreProducto}', style: const TextStyle(fontSize: 14))),
                                            Text('Bs ${d.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      )),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text(
                                            'Bs ${pedido.total.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (pedido.estado == 'EN_PREPARACION')
                                        SizedBox(
                                          height: 48,
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryButton,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: estaProcesando ? null : () => _avanzarEstado(pedido),
                                            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                            label: const Text('Marcar como Listo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          ),
                                        ),
                                      if (pedido.estado == 'LISTO')
                                        SizedBox(
                                          height: 48,
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade800,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: estaProcesando ? null : () => _avanzarEstado(pedido),
                                            icon: const Icon(Icons.handshake_outlined, color: Colors.white, size: 20),
                                            label: const Text('Confirmar Entrega', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          if (historialYEsperando.isNotEmpty) ...[
                            Text(
                              'Sección 3 — Historial reciente / Esperando pago (${historialYEsperando.length})',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.grey),
                            ),
                            const SizedBox(height: 12),
                            ...historialYEsperando.map((pedido) {
                              final String modalidad = pedido.modalidadEntrega == 'DELIVERY' ? 'Envío a domicilio' : 'Retiro en puerta';
                              return Card(
                                key: ValueKey(pedido.id),
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            pedido.compradorNombre ?? 'Vecino verificado',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          _buildEstadoBadge(pedido.estado),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Modalidad: $modalidad', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      ...pedido.detalles.map((d) => Text('${d.cantidad}x ${d.nombreProducto}', style: const TextStyle(fontSize: 13))),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Bs ${pedido.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryButton)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
