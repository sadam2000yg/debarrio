import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/producto.dart';
import 'catalogo_provider.dart';
import 'form_producto_screen.dart';

class MiCatalogoScreen extends StatefulWidget {
  const MiCatalogoScreen({super.key});

  @override
  State<MiCatalogoScreen> createState() => _MiCatalogoScreenState();
}

class _MiCatalogoScreenState extends State<MiCatalogoScreen> {
  String _filtroTipo = 'TODOS';

  void _mostrarDialogoReiniciarStock(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir día (Restaurar stock diario)'),
        content: const Text(
          '¿Estás seguro de reiniciar el stock diario para todos los productos perecederos y abrir la jornada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryButton),
            onPressed: () async {
              final catalogo = ctx.read<CatalogoProvider>();
              Navigator.pop(ctx);
              final success = await catalogo.reiniciarStockDiario();
              if (!ctx.mounted) return;
              if (success) {
                Notificaciones.mostrar(ctx, '¡Jornada abierta y stock diario restaurado!');
              } else {
                Notificaciones.mostrar(ctx, catalogo.error ?? 'Error al reiniciar stock', error: true);
              }
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    List<Producto> productos = catalogo.productos;

    if (_filtroTipo != 'TODOS') {
      productos = productos.where((p) => p.tipoInventario == _filtroTipo).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Catálogo', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => _mostrarDialogoReiniciarStock(context),
              icon: const Icon(Icons.wb_sunny, color: Colors.white),
              label: const Text('Abrir día (Restaurar stock diario)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('TODOS', 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('RECURRENTE', 'Recurrentes'),
                const SizedBox(width: 8),
                _buildFilterChip('DIARIO_PERECEDERO', 'Perecederos'),
                const SizedBox(width: 8),
                _buildFilterChip('UNICO', 'Únicos'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: catalogo.cargando && catalogo.productos.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryButton))
                : productos.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay productos en esta categoría.',
                          style: TextStyle(color: AppTheme.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: productos.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final prod = productos[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: prod.fotoUrl,
                                      height: 80,
                                      width: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 80,
                                        width: 80,
                                        color: AppTheme.containers,
                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        height: 80,
                                        width: 80,
                                        color: AppTheme.containers,
                                        child: const Icon(Icons.fastfood, color: AppTheme.primaryButton),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.nombre,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          prod.precioFormateado,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryButton, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: prod.estaDisponible ? Colors.green.shade100 : Colors.red.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                prod.etiquetaDisponibilidad,
                                                style: TextStyle(
                                                  color: prod.estaDisponible ? Colors.green.shade800 : Colors.red.shade800,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('Stock: ${prod.stockDisponible}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Switch(
                                        value: prod.activo,
                                        activeThumbColor: AppTheme.primaryButton,
                                        onChanged: (val) {
                                          catalogo.alternarActivoProducto(prod.id, val);
                                        },
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: AppTheme.primaryButton, size: 20),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => FormProductoScreen(producto: prod)),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Eliminar Producto'),
                                                  content: Text('¿Estás seguro de dar de baja (eliminación lógica) el producto "${prod.nombre}"?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancelar', style: TextStyle(color: AppTheme.grey)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      onPressed: () async {
                                                        final catalogo = ctx.read<CatalogoProvider>();
                                                        Navigator.pop(ctx);
                                                        final success = await catalogo.eliminarProductoLogico(prod.id);
                                                        if (!ctx.mounted) return;
                                                        if (success) {
                                                          Notificaciones.mostrar(ctx, 'Producto dado de baja con éxito');
                                                        } else {
                                                          Notificaciones.mostrar(ctx, catalogo.error ?? 'Error al eliminar producto', error: true);
                                                        }
                                                      },
                                                      child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryButton,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormProductoScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final seleccionado = _filtroTipo == value;
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      selectedColor: AppTheme.primaryButton,
      labelStyle: TextStyle(color: seleccionado ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filtroTipo = value;
          });
        }
      },
    );
  }
}
