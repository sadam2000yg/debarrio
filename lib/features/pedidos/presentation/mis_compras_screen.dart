import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';
import 'calificar_pedido_sheet.dart';
import 'pago_qr_screen.dart';

class MisComprasScreen extends StatefulWidget {
  final String? pedidoDestacadoId;

  const MisComprasScreen({super.key, this.pedidoDestacadoId});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  final PedidosRepository _repository = PedidosRepository();
  bool _cargando = true;
  List<Pedido> _pedidos = [];
  String? _error;
  Timer? _timer;
  RealtimeChannel? _canalRealtime;
  bool _liberandoExpirados = false;

  @override
  void initState() {
    super.initState();
    _inicializarYBuscar();
  }

  Future<void> _inicializarYBuscar() async {
    await _cargarPedidos();
    _iniciarTimer();
    _suscribirRealtime();
  }

  Future<void> _cargarPedidos() async {
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.userProfile?.id ?? Supabase.instance.client.auth.currentUser?.id;

      if (uid == null || uid.isEmpty) {
        if (mounted) {
          setState(() {
            _cargando = false;
            _pedidos = [];
          });
        }
        return;
      }

      await _repository.liberarPedidosExpirados();
      final list = await _repository.listarPedidosComprador(uid);

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

      final bool hayExpirado = _pedidos.any((p) =>
          (p.estado == 'ESPERANDO_PAGO' || p.estado == 'PAGO_EN_REVISION') &&
          p.tiempoRestante <= Duration.zero);

      if (hayExpirado && !_liberandoExpirados) {
        _liberandoExpirados = true;
        try {
          await _repository.liberarPedidosExpirados();
          await _cargarPedidos();
        } finally {
          _liberandoExpirados = false;
        }
      } else if (_pedidos.any((p) => p.estado == 'ESPERANDO_PAGO' || p.estado == 'PAGO_EN_REVISION')) {
        setState(() {});
      }
    });
  }

  void _suscribirRealtime() {
    final uid = context.read<AuthProvider>().userProfile?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    _canalRealtime = Supabase.instance.client
        .channel('mis_compras_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedidos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'comprador_id',
            value: uid,
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
    if (_canalRealtime != null) {
      Supabase.instance.client.removeChannel(_canalRealtime!);
    }
    super.dispose();
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
        label = 'Verificando pago QR';
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
        label = 'Cancelado por tiempo (3 min)';
        colorBg = Colors.red.shade100;
        colorTxt = Colors.red.shade900;
        break;
      case 'EN_DISPUTA':
        label = 'En disputa';
        colorBg = Colors.purple.shade100;
        colorTxt = Colors.purple.shade900;
        break;
      case 'EN_DEVOLUCION':
        label = 'En devolución';
        colorBg = Colors.blueGrey.shade100;
        colorTxt = Colors.blueGrey.shade900;
        break;
      default:
        label = estado;
        colorBg = AppTheme.containers;
        colorTxt = AppTheme.textPrimary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: colorTxt, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildProgressBar(String estado) {
    int pasoActual = 0;
    switch (estado) {
      case 'ESPERANDO_PAGO':
      case 'PAGO_EN_REVISION':
        pasoActual = 1;
        break;
      case 'EN_PREPARACION':
        pasoActual = 2;
        break;
      case 'LISTO':
        pasoActual = 3;
        break;
      case 'ENTREGADO':
        pasoActual = 4;
        break;
      default:
        return const SizedBox.shrink();
    }

    final pasos = ['Pago', 'Preparando', 'Listo', 'Entregado'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.containers,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(pasos.length, (i) {
          final int numPaso = i + 1;
          final bool completado = numPaso <= pasoActual;
          final bool esPasoActual = numPaso == pasoActual;

          final Color colorCirculo = completado ? AppTheme.primaryButton : Colors.grey.shade400;
          final Color colorTexto = completado ? AppTheme.primaryButton : AppTheme.grey;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: colorCirculo,
                        child: Icon(
                          completado ? Icons.check : Icons.circle,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          pasos[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: esPasoActual ? FontWeight.bold : FontWeight.w500,
                            color: colorTexto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < pasos.length - 1)
                  Container(
                    width: 12,
                    height: 2,
                    color: numPaso < pasoActual ? AppTheme.primaryButton : Colors.grey.shade300,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Compras y Pedidos', style: TextStyle(color: AppTheme.white)),
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
                        Text('Error al cargar pedidos: $_error', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
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
                              'Aún no realizas pedidos en tu barrio',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Explora los puestos de tus vecinos y realiza tu primer pedido.',
                              style: TextStyle(color: AppTheme.grey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pedidos.length,
                      itemBuilder: (context, index) {
                        final pedido = _pedidos[index];
                        final bool esDestacado = widget.pedidoDestacadoId != null && pedido.id == widget.pedidoDestacadoId;
                        final String modalidad = pedido.modalidadEntrega == 'DELIVERY' ? 'Envío a domicilio' : 'Retiro en puerta';
                        final String fecha = pedido.createdAt != null
                            ? '${pedido.createdAt!.day.toString().padLeft(2, '0')}/${pedido.createdAt!.month.toString().padLeft(2, '0')}/${pedido.createdAt!.year} ${pedido.createdAt!.hour.toString().padLeft(2, '0')}:${pedido.createdAt!.minute.toString().padLeft(2, '0')}'
                            : '';
                        final Duration restante = pedido.tiempoRestante;
                        final bool requierePago = pedido.estado == 'ESPERANDO_PAGO' && restante > Duration.zero;
                        final bool tieneAlertaRechazo = pedido.estado == 'ESPERANDO_PAGO' && pedido.alertaPago != null && pedido.alertaPago!.isNotEmpty;

                        return Card(
                          elevation: esDestacado ? 4 : 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: esDestacado ? const BorderSide(color: AppTheme.primaryButton, width: 2) : BorderSide.none,
                          ),
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
                                        pedido.negocioNombre ?? 'Puesto Barrial',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton),
                                      ),
                                    ),
                                    _buildEstadoBadge(pedido.estado),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Modalidad: $modalidad', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                                    if (fecha.isNotEmpty) Text(fecha, style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                                  ],
                                ),
                                _buildProgressBar(pedido.estado),
                                if (pedido.estado == 'LISTO') ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.shade600, width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            pedido.modalidadEntrega == 'DELIVERY'
                                                ? '¡Tu pedido está LISTO! El emprendedor está coordinando tu entrega a domicilio.'
                                                : '¡Tu pedido está LISTO! Ya puedes pasar a recogerlo por el puesto.',
                                            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (tieneAlertaRechazo) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.shade400, width: 1.5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.error_outline, color: Colors.red, size: 22),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'El vendedor aún no recibió tu pago, por favor verifica y confirma el pago',
                                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (pedido.alertaPago != null && pedido.alertaPago!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            pedido.alertaPago!,
                                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                                if (pedido.estado == 'CANCELADO_POR_TIEMPO') ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'La orden expiró automáticamente y el stock fue liberado',
                                    style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                                  ),
                                ],
                                const Divider(height: 20),
                                ...pedido.detalles.map((d) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text('${d.cantidad}x ${d.nombreProducto}', style: const TextStyle(fontSize: 13)),
                                      ),
                                      Text('Bs ${d.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                )),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total: Bs ${pedido.total.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    if (requierePago)
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: tieneAlertaRechazo ? Colors.red.shade800 : Colors.amber.shade800,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PagoQrScreen(pedido: pedido),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 18),
                                          label: Text(
                                            tieneAlertaRechazo
                                                ? 'Verificar QR y Confirmar Pago'
                                                : 'Ver QR y Pagar (${restante.inMinutes}:${(restante.inSeconds % 60).toString().padLeft(2, '0')})',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      )
                                    else if (pedido.estado == 'ENTREGADO' && !pedido.calificado)
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryButton,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                              ),
                                              builder: (ctx) => CalificarPedidoSheet(
                                                pedido: pedido,
                                                onResenaGuardada: _cargarPedidos,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.star_rate, color: Colors.amber, size: 18),
                                          label: const Text('Dejar Reseña', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                      )
                                    else if (pedido.calificado)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Reseña enviada ★',
                                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
