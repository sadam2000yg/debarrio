import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/pedido.dart';

const String todasLasModalidades = 'TODAS';
const String todosLosEstados = 'TODOS';

const Map<String, String> modalidadesPedido = {
  todasLasModalidades: 'Todas las modalidades',
  'DELIVERY': 'A domicilio',
  'RETIRO': 'Retiro en puerta',
};

const Map<String, String> estadosPedido = {
  todosLosEstados: 'Todos los estados',
  'ESPERANDO_PAGO': 'Esperando pago',
  'PAGO_EN_REVISION': 'Pago por verificar',
  'EN_PREPARACION': 'En preparación',
  'LISTO': 'Listo',
  'ENTREGADO': 'Entregado',
  'CANCELADO_POR_TIEMPO': 'Cancelado por tiempo',
  'EN_DISPUTA': 'En disputa',
};

List<Pedido> filtrarPedidos({
  required Iterable<Pedido> pedidos,
  required String busqueda,
  required DateTimeRange? rangoFecha,
  required String modalidad,
  required String estado,
}) {
  final query = _normalizarTexto(busqueda);
  final fechaInicio = rangoFecha == null
      ? null
      : DateUtils.dateOnly(rangoFecha.start);
  final fechaFinExclusiva = rangoFecha == null
      ? null
      : DateUtils.dateOnly(rangoFecha.end).add(const Duration(days: 1));

  return pedidos
      .where((pedido) {
        if (modalidad != todasLasModalidades &&
            pedido.modalidadEntrega != modalidad) {
          return false;
        }
        if (estado != todosLosEstados && pedido.estado != estado) return false;

        if (fechaInicio != null && fechaFinExclusiva != null) {
          final fechaPedido = pedido.createdAt == null
              ? null
              : DateUtils.dateOnly(pedido.createdAt!.toLocal());
          if (fechaPedido == null ||
              fechaPedido.isBefore(fechaInicio) ||
              !fechaPedido.isBefore(fechaFinExclusiva)) {
            return false;
          }
        }

        if (query.isEmpty) return true;

        final searchableText = _normalizarTexto(
          [
            pedido.id,
            pedido.compradorNombre,
            pedido.negocioNombre,
            pedido.referenciaEntrega,
            pedido.alertaPago,
            pedido.modalidadEntrega,
            modalidadesPedido[pedido.modalidadEntrega],
            pedido.estado,
            estadosPedido[pedido.estado],
            ...pedido.detalles.map((detalle) => detalle.nombreProducto),
          ].whereType<String>().join(' '),
        );

        return searchableText.contains(query);
      })
      .toList(growable: false);
}

String _normalizarTexto(String texto) {
  return texto
      .toLowerCase()
      .replaceAll(RegExp('[áàâäã]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôöõ]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class FiltrosHistorialPedidos extends StatelessWidget {
  final TextEditingController controladorBusqueda;
  final DateTimeRange? rangoFecha;
  final String modalidad;
  final String estado;
  final ValueChanged<String> onBusquedaChanged;
  final ValueChanged<DateTimeRange?> onRangoFechaChanged;
  final ValueChanged<String> onModalidadChanged;
  final ValueChanged<String> onEstadoChanged;
  final VoidCallback onLimpiar;
  final bool hayFiltrosActivos;

  const FiltrosHistorialPedidos({
    super.key,
    required this.controladorBusqueda,
    required this.rangoFecha,
    required this.modalidad,
    required this.estado,
    required this.onBusquedaChanged,
    required this.onRangoFechaChanged,
    required this.onModalidadChanged,
    required this.onEstadoChanged,
    required this.onLimpiar,
    required this.hayFiltrosActivos,
  });

  String _fechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  Future<void> _seleccionarFechas(BuildContext context) async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: rangoFecha,
      helpText: 'Filtrar pedidos por fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (rango != null) onRangoFechaChanged(rango);
  }

  Widget _buildSelector({
    required String label,
    required String value,
    required Map<String, String> opciones,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 175,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: AppTheme.containers,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        items: opciones.entries
            .map(
              (opcion) => DropdownMenuItem<String>(
                value: opcion.key,
                child: Text(
                  opcion.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoRango = rangoFecha == null
        ? 'Cualquier fecha'
        : '${_fechaCorta(rangoFecha!.start)} – '
              '${_fechaCorta(rangoFecha!.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controladorBusqueda,
          onChanged: onBusquedaChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar nombre, producto, pedido o referencia',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controladorBusqueda.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      controladorBusqueda.clear();
                      onBusquedaChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: AppTheme.containers,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _seleccionarFechas(context),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(textoRango),
            ),
            _buildSelector(
              label: 'Modalidad',
              value: modalidad,
              opciones: modalidadesPedido,
              onChanged: onModalidadChanged,
            ),
            _buildSelector(
              label: 'Estado',
              value: estado,
              opciones: estadosPedido,
              onChanged: onEstadoChanged,
            ),
            if (hayFiltrosActivos)
              TextButton.icon(
                onPressed: onLimpiar,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpiar'),
              ),
          ],
        ),
      ],
    );
  }
}
