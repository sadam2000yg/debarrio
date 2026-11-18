import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PedidoMock {
  final String id;
  final String negocioNombre;
  final double total;
  final String estado; // 'Pendiente', 'En Preparación', 'Listo', 'Entregado'
  final String fecha;
  final String modalidad;

  PedidoMock({
    required this.id,
    required this.negocioNombre,
    required this.total,
    required this.estado,
    required this.fecha,
    required this.modalidad,
  });
}

class MisComprasScreen extends StatelessWidget {
  const MisComprasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<PedidoMock> pedidos = [
      PedidoMock(
        id: '#1042',
        negocioNombre: 'Doña Rosa - Abarrotes y Lácteos',
        total: 33.00,
        estado: 'En Preparación',
        fecha: 'Hoy, 10:30 AM',
        modalidad: 'Entrega a domicilio',
      ),
      PedidoMock(
        id: '#1038',
        negocioNombre: 'Panadería El Trigo de Oro',
        total: 13.00,
        estado: 'Entregado',
        fecha: 'Ayer, 04:15 PM',
        modalidad: 'Retiro en puerta',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Compras y Pedidos', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pedidos.length,
        itemBuilder: (context, index) {
          final p = pedidos[index];
          bool isEntregado = p.estado == 'Entregado';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pedido ${p.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton)),
                      Chip(
                        label: Text(p.estado, style: TextStyle(color: isEntregado ? Colors.green.shade800 : Colors.orange.shade800, fontWeight: FontWeight.bold)),
                        backgroundColor: isEntregado ? Colors.green.shade100 : Colors.orange.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(p.negocioNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Modalidad: ${p.modalidad}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                  Text('Fecha: ${p.fecha}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total: Bs ${p.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Detalle del Pedido ${p.id}'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Negocio: ${p.negocioNombre}'),
                                  const SizedBox(height: 8),
                                  Text('Estado actual: ${p.estado}'),
                                  const SizedBox(height: 8),
                                  Text('Modalidad: ${p.modalidad}'),
                                  const SizedBox(height: 8),
                                  Text('Total pagado: Bs ${p.total.toStringAsFixed(2)}'),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                              ],
                            ),
                          );
                        },
                        child: const Text('Ver Detalle'),
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
