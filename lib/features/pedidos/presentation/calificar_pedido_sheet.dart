import 'package:flutter/material.dart';

import 'package:d_barrio/core/utils/moderacion.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
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
  int _calificacion = 5;
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _publicarResena() async {
    final errorModeracion = Moderacion.validarComentario(
      _comentarioController.text,
    );
    if (errorModeracion != null) {
      Notificaciones.mostrar(context, errorModeracion, error: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      final repository = PedidosRepository();
      await repository.crearResenaVerificada(
        pedidoId: widget.pedido.id,
        calificacion: _calificacion,
        comentario: _comentarioController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        Notificaciones.mostrar(context, '¡Reseña publicada con éxito!');
        widget.onResenaGuardada();
      }
    } catch (e) {
      if (mounted) {
        Notificaciones.mostrar(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Calificar Pedido',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '¿Qué te pareció el servicio de ${widget.pedido.negocioNombre ?? 'este puesto'}?',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNumber = index + 1;
                      final isSelected = starNumber <= _calificacion;
                      return SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              _calificacion = starNumber;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _comentarioController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Comentario u opinión',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El comentario es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: BotonPrincipal(
                    texto: 'Publicar Reseña',
                    cargando: _enviando,
                    onPressed: _enviando ? () {} : _publicarResena,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
