import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/presentation/auth_provider.dart';

class ComandaScreen extends StatefulWidget {
  const ComandaScreen({super.key});

  @override
  State<ComandaScreen> createState() => _ComandaScreenState();
}

class _ComandaScreenState extends State<ComandaScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _pedidos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarComanda();
  }

  Future<void> _cargarComanda() async {
    try {
      final auth = context.read<AuthProvider>();
      final negocio = auth.negocio;
      if (negocio == null) {
        setState(() {
          _cargando = false;
        });
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('pedidos')
          .select('*, perfiles(nombre)')
          .eq('negocio_id', negocio.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pedidos = List<Map<String, dynamic>>.from(response);
          _cargando = false;
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

  Future<void> _cambiarEstado(Map<String, dynamic> pedido, String nuevoEstado) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('pedidos').update({'estado': nuevoEstado}).eq('id', pedido['id']);
      setState(() {
        pedido['estado'] = nuevoEstado;
      });
      if (mounted) {
        Notificaciones.mostrar(context, 'Pedido actualizado a: $nuevoEstado');
      }
    } catch (e) {
      if (mounted) {
        Notificaciones.mostrar(context, 'Error al actualizar estado: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final negocio = auth.negocio;

    if (negocio == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Comanda de Pedidos', style: TextStyle(color: AppTheme.white)),
          backgroundColor: AppTheme.primaryButton,
        ),
        body: const Center(child: Text('Debe registrar su negocio para ver la comanda.', style: TextStyle(color: AppTheme.grey))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comanda de Pedidos en Vivo', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryButton))
          : _error != null
              ? Center(child: Text('Error al cargar comanda: $_error', style: const TextStyle(color: AppTheme.error)))
              : _pedidos.isEmpty
                  ? const Center(child: Text('No hay pedidos activos en este momento.', style: TextStyle(color: AppTheme.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pedidos.length,
                      itemBuilder: (context, index) {
                        final p = _pedidos[index];
                        final String estado = p['estado']?.toString() ?? 'Pendiente';
                        Color estadoColor = Colors.orange;
                        if (estado == 'En Preparación') estadoColor = Colors.blue;
                        if (estado == 'Listo') estadoColor = Colors.green;
                        if (estado == 'Entregado') estadoColor = Colors.grey;

                        final perfilMap = p['perfiles'] as Map<String, dynamic>?;
                        final clienteNombre = perfilMap?['nombre']?.toString() ?? 'Cliente';
                        final total = (p['total'] as num?)?.toDouble() ?? 0.0;
                        final modalidad = p['modalidad']?.toString() == 'DOMICILIO' ? 'Entrega a domicilio' : 'Retiro en puerta';

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
                                    Text('Pedido #${p['id'].toString().substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton)),
                                    Chip(
                                      label: Text(estado, style: TextStyle(color: estadoColor.computeLuminance() > 0.5 ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                                      backgroundColor: estadoColor.withValues(alpha: 0.2),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Cliente: $clienteNombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('Modalidad: $modalidad', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total: Bs ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Row(
                                      children: [
                                        if (estado == 'Pendiente')
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(90, 36)),
                                            onPressed: () => _cambiarEstado(p, 'En Preparación'),
                                            child: const Text('Preparar', style: TextStyle(fontSize: 12, color: Colors.white)),
                                          ),
                                        if (estado == 'En Preparación')
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(90, 36)),
                                            onPressed: () => _cambiarEstado(p, 'Listo'),
                                            child: const Text('Marcar Listo', style: TextStyle(fontSize: 12, color: Colors.white)),
                                          ),
                                        if (estado == 'Listo')
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton, minimumSize: const Size(90, 36)),
                                            onPressed: () => _cambiarEstado(p, 'Entregado'),
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
