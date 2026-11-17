import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import 'explorar_provider.dart';
import 'escaparate_negocio_screen.dart';

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({super.key});

  String _formatearDistancia(double? metros) {
    if (metros == null) return '';
    if (metros < 1000) {
      return '${metros.toStringAsFixed(0)} m';
    } else {
      return '${(metros / 1000).toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final explorar = context.watch<ExplorarProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar D\'BARRIO', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.containers,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.radar, color: AppTheme.primaryButton, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Radio: 1 km a tu alrededor',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => explorar.actualizarMiZonaManual(),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Actualizar mi zona', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => explorar.setBusqueda(v),
              decoration: InputDecoration(
                hintText: 'Buscar puestos o productos...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryButton),
                filled: true,
                fillColor: AppTheme.containers,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryChip(context, 'TODOS', 'Todos'),
                const SizedBox(width: 8),
                _buildCategoryChip(context, 'Comida', 'Comida'),
                const SizedBox(width: 8),
                _buildCategoryChip(context, 'Abarrotes', 'Abarrotes'),
                const SizedBox(width: 8),
                _buildCategoryChip(context, 'Artesanías', 'Artesanías'),
                const SizedBox(width: 8),
                _buildCategoryChip(context, 'Servicios', 'Servicios'),
              ],
            ),
          ),
          Expanded(
            child: explorar.cargando && explorar.negociosCercanos.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryButton))
                : explorar.negociosCercanos.isEmpty
                    ? const Center(
                        child: Text(
                          'No se encontraron puestos cercanos en 1 km.',
                          style: TextStyle(color: AppTheme.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: explorar.negociosCercanos.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final negocio = explorar.negociosCercanos[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EscaparateNegocioScreen(negocioId: negocio.id)),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: negocio.storePhotoUrl,
                                        height: 85,
                                        width: 85,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          height: 85,
                                          width: 85,
                                          color: AppTheme.containers,
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          height: 85,
                                          width: 85,
                                          color: AppTheme.containers,
                                          child: const Icon(Icons.storefront, color: AppTheme.primaryButton),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  negocio.nombre,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: negocio.abierto ? Colors.green.shade100 : Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  negocio.abierto ? 'Abierto' : 'Cerrado',
                                                  style: TextStyle(
                                                    color: negocio.abierto ? Colors.green.shade800 : Colors.red.shade800,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            negocio.descripcion,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: AppTheme.grey, fontSize: 13),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              if (negocio.distanciaMetros != null)
                                                Row(
                                                  children: [
                                                    const Icon(Icons.near_me, size: 14, color: AppTheme.primaryButton),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatearDistancia(negocio.distanciaMetros),
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryButton),
                                                    ),
                                                  ],
                                                ),
                                              if (negocio.calificacionPromedio != null)
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      negocio.calificacionPromedio!.toStringAsFixed(1),
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, String value, String label) {
    final explorar = context.watch<ExplorarProvider>();
    final seleccionado = explorar.categoriaSeleccionada == value;
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      selectedColor: AppTheme.primaryButton,
      labelStyle: TextStyle(color: seleccionado ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold),
      onSelected: (selected) {
        if (selected) {
          explorar.setCategoria(value);
        }
      },
    );
  }
}
