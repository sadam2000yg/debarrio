import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class MisComprasScreen extends StatefulWidget {
  final String? pedidoDestacadoId;

  const MisComprasScreen({super.key, this.pedidoDestacadoId});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _pedidos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarMisPedidos();
  }

  Future<void> _cargarMisPedidos() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _cargando = false;
        });
        return;
      }

      final response = await supabase
          .from('pedidos')
          .select('*, negocios(nombre)')
          .eq('cliente_id', user.id)
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
              ? Center(child: Text('Error al cargar pedidos: $_error', style: const TextStyle(color: AppTheme.error)))
              : _pedidos.isEmpty
                  ? const Center(child: Text('No tienes compras registradas aún.', style: TextStyle(color: AppTheme.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pedidos.length,
                      itemBuilder: (context, index) {
                        final p = _pedidos[index];
                        final String estado = p['estado']?.toString() ?? 'Pendiente';
                        final bool isEntregado = estado == 'Entregado';
                        final negocioMap = p['negocios'] as Map<String, dynamic>?;
                        final negocioNombre = negocioMap?['nombre']?.toString() ?? 'Puesto';
                        final total = (p['total'] as num?)?.toDouble() ?? 0.0;
                        final modalidad = p['modalidad']?.toString() == 'DOMICILIO' || p['modalidad_entrega']?.toString() == 'DELIVERY' ? 'Entrega a domicilio' : 'Retiro en puerta';
                        final fecha = p['created_at']?.toString().substring(0, 10) ?? '';
                        final bool esDestacado = widget.pedidoDestacadoId != null && p['id'].toString() == widget.pedidoDestacadoId;

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
                                    Text('Pedido #${p['id'].toString().substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton)),
                                    Chip(
                                      label: Text(estado, style: TextStyle(color: isEntregado ? Colors.green.shade800 : Colors.orange.shade800, fontWeight: FontWeight.bold)),
                                      backgroundColor: isEntregado ? Colors.green.shade100 : Colors.orange.shade100,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(negocioNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('Modalidad: $modalidad', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                                Text('Fecha: $fecha', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total: Bs ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    OutlinedButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Detalle del Pedido'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Negocio: $negocioNombre'),
                                                const SizedBox(height: 8),
                                                Text('Estado actual: $estado'),
                                                const SizedBox(height: 8),
                                                Text('Modalidad: $modalidad'),
                                                const SizedBox(height: 8),
                                                Text('Total pagado: Bs ${total.toStringAsFixed(2)}'),
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
