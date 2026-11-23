import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido.dart';

class CalificarPedidoSheet extends StatefulWidget {
  final Pedido pedido;
  final VoidCallback onResenaGuardada;

  const CalificarPedidoSheet({
    super.key,
    required this.pedido,
    required this.onResenaGuardada,
  });

  @override
  State<CalificarPedidoSheet> createState() => _CalificarPedidoSheetState();
}

class _CalificarPedidoSheetState extends State<CalificarPedidoSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _comentarioController = TextEditingController();
  final PedidosRepository _repository = PedidosRepository();

  int _calificacion = 5;
  bool _guardando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _guardarResena() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      await _repository.crearResenaVerificada(
        pedidoId: widget.pedido.id,
        calificacion: _calificacion,
        comentario: _comentarioController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por calificar tu compra!')),
      );
      widget.onResenaGuardada();
    } catch (e) {
      if (mounted) {
        Notificaciones.mostrar(context, 'Error al publicar reseña: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Calificar tu compra',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryButton),
                  textAlign: TextAlign.center,
                ),
                if (widget.pedido.negocioNombre != null && widget.pedido.negocioNombre!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.pedido.negocioNombre!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final int estrella = index + 1;
                    return SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          estrella <= _calificacion ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            _calificacion = estrella;
                          });
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                CampoTexto(
                  controller: _comentarioController,
                  label: 'Comentario sobre tu compra',
                  hint: 'Cuéntanos tu experiencia con los productos y la atención...',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Comentario'),
                  prefixIcon: const Icon(Icons.rate_review, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: BotonPrincipal(
                    texto: 'Publicar Reseña',
                    cargando: _guardando,
                    onPressed: _guardando ? null : _guardarResena,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
