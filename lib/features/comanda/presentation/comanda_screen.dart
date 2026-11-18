import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class ComandaItemMock {
  final String idPedido;
  final String clienteNombre;
  final String resumen;
  final double total;
  String estado; // 'Pendiente', 'En Preparación', 'Listo'
  final String modalidad;

  ComandaItemMock({
    required this.idPedido,
    required this.clienteNombre,
    required this.resumen,
    required this.total,
    required this.estado,
    required this.modalidad,
  });
}

class ComandaScreen extends StatefulWidget {
  const ComandaScreen({super.key});

  @override
  State<ComandaScreen> createState() => _ComandaScreenState();
}

class _ComandaScreenState extends State<ComandaScreen> {
  final List<ComandaItemMock> _pedidos = [
    ComandaItemMock(
      idPedido: '#201',
      clienteNombre: 'Carlos Mamani',
      resumen: '2x Pan Casero Integral, 1x Queso Criollo',
      total: 31.00,
      estado: 'Pendiente',
      modalidad: 'Entrega a domicilio',
    ),
    ComandaItemMock(
      idPedido: '#200',
      clienteNombre: 'Lucia Villca',
      resumen: '3x Tomates Frescos Seleccionados',
      total: 25.50,
      estado: 'En Preparación',
      modalidad: 'Retiro en puerta',
    ),
  ];

  void _cambiarEstado(ComandaItemMock pedido, String nuevoEstado) {
    setState(() {
      pedido.estado = nuevoEstado;
    });
    Notificaciones.mostrar(context, 'Pedido ${pedido.idPedido} actualizado a: $nuevoEstado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comanda de Pedidos en Vivo', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: _pedidos.isEmpty
          ? const Center(child: Text('No hay pedidos activos en este momento.', style: TextStyle(color: AppTheme.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pedidos.length,
              itemBuilder: (context, index) {
                final p = _pedidos[index];
                Color estadoColor = Colors.orange;
                if (p.estado == 'En Preparación') estadoColor = Colors.blue;
                if (p.estado == 'Listo') estadoColor = Colors.green;

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
                            Text('Pedido ${p.idPedido}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton)),
                            Chip(
                              label: Text(p.estado, style: TextStyle(color: estadoColor.computeLuminance() > 0.5 ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                              backgroundColor: estadoColor.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Cliente: ${p.clienteNombre}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Productos: ${p.resumen}', style: const TextStyle(color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Modalidad: ${p.modalidad}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: Bs ${p.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Row(
                              children: [
                                if (p.estado == 'Pendiente')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(90, 36)),
                                    onPressed: () => _cambiarEstado(p, 'En Preparación'),
                                    child: const Text('Preparar', style: TextStyle(fontSize: 12, color: Colors.white)),
                                  ),
                                if (p.estado == 'En Preparación')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(90, 36)),
                                    onPressed: () => _cambiarEstado(p, 'Listo'),
                                    child: const Text('Marcar Listo', style: TextStyle(fontSize: 12, color: Colors.white)),
                                  ),
                                if (p.estado == 'Listo')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton, minimumSize: const Size(90, 36)),
                                    onPressed: () {
                                      setState(() {
                                        _pedidos.removeAt(index);
                                      });
                                      Notificaciones.mostrar(context, 'Pedido ${p.idPedido} entregado con éxito.');
                                    },
                                    child: const Text('Entregar', style: TextStyle(fontSize: 12, color: Colors.white)),
                                  ),
                              ],
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
