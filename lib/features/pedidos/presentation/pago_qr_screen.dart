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

class PagoQrScreen extends StatefulWidget {
  final Pedido pedido;

  const PagoQrScreen({super.key, required this.pedido});

  @override
  State<PagoQrScreen> createState() => _PagoQrScreenState();
}

class _PagoQrScreenState extends State<PagoQrScreen> {
  late Pedido _pedidoActual;
  Timer? _timer;
  Duration _restante = Duration.zero;
  bool _enviandoPago = false;
  RealtimeChannel? _canalPedido;
  final PedidosRepository _pedidosRepository = PedidosRepository();

  @override
  void initState() {
    super.initState();
    _pedidoActual = widget.pedido;
    _restante = _pedidoActual.tiempoRestante;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final nuevaRestante = _pedidoActual.tiempoRestante;
      if (mounted) {
        setState(() {
          _restante = nuevaRestante;
        });
      }

      if (_restante <= Duration.zero &&
          _pedidoActual.estado == 'ESPERANDO_PAGO') {
        _timer?.cancel();
        await _pedidosRepository.liberarPedidosExpirados();
        if (mounted) {
          setState(() {
            _pedidoActual = _pedidoActual.copyWith(
              estado: 'CANCELADO_POR_TIEMPO',
            );
          });
        }
      }
    });

    _canalPedido = Supabase.instance.client
        .channel('pago_qr_${widget.pedido.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pedidos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.pedido.id,
          ),
          callback: (payload) async {
            try {
              final actualizado = await _pedidosRepository.obtenerPedidoPorId(
                widget.pedido.id,
              );
              if (mounted) {
                setState(() {
                  _pedidoActual = actualizado;
                  _restante = _pedidoActual.tiempoRestante;
                });
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_canalPedido != null) {
      Supabase.instance.client.removeChannel(_canalPedido!);
    }
    super.dispose();
  }

  void _ampliarQr(BuildContext context, String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Código QR - ${_pedidoActual.negocioNombre ?? "Puesto Barrial"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CachedNetworkImage(
                imageUrl: qrUrl,
                width: 280,
                height: 280,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryButton,
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.qr_code, size: 100, color: AppTheme.grey),
              ),
              const SizedBox(height: 16),
              Text(
                'Monto: Bs ${_pedidoActual.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primaryButton,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryButton,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarPago() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Transferencia'),
        content: Text(
          '¿Ya realizaste la transferencia de Bs ${_pedidoActual.total.toStringAsFixed(2)} desde tu banco?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Aún no'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryButton,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, ya pagué',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _enviandoPago = true);

    try {
      await _pedidosRepository.marcarComoPagado(_pedidoActual.id);
      if (!mounted) return;

      Notificaciones.mostrar(context, 'Pago notificado al emprendedor');
      final auth = context.read<AuthProvider>();

      auth.seleccionarTabVecino(
        2, // Mis Compras
        pedidoId: _pedidoActual.id,
      );

      Navigator.of(context, rootNavigator: true).popUntil(
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      Notificaciones.mostrar(
        context,
        'Error al notificar pago: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _enviandoPago = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esExpirado = _pedidoActual.estado == 'CANCELADO_POR_TIEMPO';
    final bool esUrgente = _restante.inSeconds < 20 && !esExpirado;
    final String minutos = _restante.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String segundos = _restante.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String modalidad = _pedidoActual.modalidadEntrega == 'DELIVERY'
        ? 'Envío a domicilio'
        : 'Retiro en puerta';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pago por QR Simple',
          style: TextStyle(color: AppTheme.white),
        ),
        backgroundColor: AppTheme.primaryButton,
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                color: esExpirado
                    ? Colors.red.shade50
                    : (esUrgente ? Colors.red.shade100 : Colors.amber.shade50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: esExpirado || esUrgente
                        ? Colors.red.shade400
                        : Colors.amber.shade400,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 36,
                        color: esExpirado || esUrgente
                            ? Colors.red.shade800
                            : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esExpirado
                                  ? '00:00 - Expirado'
                                  : '$minutos:$segundos min',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: esExpirado || esUrgente
                                    ? Colors.red.shade900
                                    : Colors.brown.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tiempo de reserva de stock (3 min)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_pedidoActual.alertaPago != null &&
                  _pedidoActual.alertaPago!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pedidoActual.alertaPago!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        _pedidoActual.negocioNombre ?? 'Puesto Barrial',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primaryButton,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Modalidad: $modalidad',
                        style: const TextStyle(
                          color: AppTheme.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _pedidoActual.negocioQrUrl ?? '',
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            width: 220,
                            height: 220,
                            color: AppTheme.containers,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryButton,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 220,
                            height: 220,
                            color: AppTheme.containers,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  size: 60,
                                  color: AppTheme.primaryButton,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'QR no disponible',
                                  style: TextStyle(
                                    color: AppTheme.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_pedidoActual.negocioQrUrl != null &&
                          _pedidoActual.negocioQrUrl!.isNotEmpty)
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => _ampliarQr(
                              context,
                              _pedidoActual.negocioQrUrl!,
                            ),
                            icon: const Icon(Icons.open_in_full, size: 18),
                            label: const Text(
                              'Ampliar código QR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      const Divider(height: 28),
                      Text(
                        'Total a pagar: Bs ${_pedidoActual.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppTheme.primaryButton,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (esExpirado) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'El tiempo de 3 minutos expiró y tu stock fue liberado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BotonPrincipal(
                  texto: 'Volver a Explorar',
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ] else ...[
                SizedBox(
                  height: 54,
                  child: BotonPrincipal(
                    texto: 'Marcar como Pagado',
                    cargando: _enviandoPago,
                    onPressed: _enviandoPago ? null : _confirmarPago,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
