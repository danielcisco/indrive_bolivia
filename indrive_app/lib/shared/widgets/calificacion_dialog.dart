import 'package:flutter/material.dart';

/// Selector de 1-5 estrellas + comentario opcional, compartido por Cliente
/// y Repartidor (Sprint 6.1) — la única diferencia entre ambos usos es
/// quién es `autorId`/`paraId` al llamar `EnviosRepository.crearCalificacion`.
///
/// Devuelve `null` si el usuario cierra el diálogo sin calificar
/// (calificar es opcional, no bloquea nada del flujo de la entrega).
Future<({int estrellas, String? comentario})?> mostrarCalificacionDialog(
  BuildContext context, {
  required String tituloParaQuien,
}) {
  return showDialog<({int estrellas, String? comentario})>(
    context: context,
    builder: (context) => _CalificacionDialog(tituloParaQuien: tituloParaQuien),
  );
}

class _CalificacionDialog extends StatefulWidget {
  const _CalificacionDialog({required this.tituloParaQuien});

  final String tituloParaQuien;

  @override
  State<_CalificacionDialog> createState() => _CalificacionDialogState();
}

class _CalificacionDialogState extends State<_CalificacionDialog> {
  int _estrellas = 5;
  final _comentarioController = TextEditingController();

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Calificar a ${widget.tituloParaQuien}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final valor = index + 1;
              return IconButton(
                icon: Icon(
                  valor <= _estrellas ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => _estrellas = valor),
              );
            }),
          ),
          TextField(
            controller: _comentarioController,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Saltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            estrellas: _estrellas,
            comentario: _comentarioController.text.trim().isEmpty
                ? null
                : _comentarioController.text.trim(),
          )),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
