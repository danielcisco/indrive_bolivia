import 'package:flutter/material.dart';

/// Quién está siendo calificado — determina qué set de frases sugeridas
/// se usa (ver [_sugerenciasPara]), porque los criterios no son los
/// mismos: la calidad del servicio de un repartidor no es lo mismo que
/// la puntualidad de un cliente al recibir el paquete.
enum CalificadoRol { cliente, repartidor }

/// Selector de 1-5 estrellas + comentario opcional, compartido por Cliente
/// y Repartidor (Sprint 6.1) — la única diferencia entre ambos usos es
/// quién es `autorId`/`paraId` al llamar `EnviosRepository.crearCalificacion`,
/// y ahora también qué frases sugiere ([calificadoRol]).
///
/// Devuelve `null` si el usuario cierra el diálogo sin calificar
/// (calificar es opcional, no bloquea nada del flujo de la entrega).
Future<({int estrellas, String? comentario})?> mostrarCalificacionDialog(
  BuildContext context, {
  required String tituloParaQuien,
  required CalificadoRol calificadoRol,
}) {
  return showDialog<({int estrellas, String? comentario})>(
    context: context,
    builder: (context) => _CalificacionDialog(
      tituloParaQuien: tituloParaQuien,
      calificadoRol: calificadoRol,
    ),
  );
}

class _CalificacionDialog extends StatefulWidget {
  const _CalificacionDialog({
    required this.tituloParaQuien,
    required this.calificadoRol,
  });

  final String tituloParaQuien;
  final CalificadoRol calificadoRol;

  @override
  State<_CalificacionDialog> createState() => _CalificacionDialogState();
}

/// Texto sugerido según la cantidad de estrellas y a quién se califica —
/// punto de partida, no un comentario cerrado: el usuario lo puede borrar
/// o reescribir. Se vuelve a aplicar cada vez que cambian las estrellas
/// SOLO mientras el texto siga siendo una de estas sugerencias (o esté
/// vacío) — apenas el usuario escribe algo propio, cambiar la
/// calificación ya no lo pisa.
Map<int, String> _sugerenciasPara(CalificadoRol rol) => switch (rol) {
  CalificadoRol.repartidor => const {
    1: 'Tuvo problemas con la entrega',
    2: 'Tuvo problemas con la entrega',
    3: 'Cumplió sin inconvenientes',
    4: 'Rápido y muy atento',
    5: 'Rápido y muy atento',
  },
  CalificadoRol.cliente => const {
    1: 'Me hizo esperar bastante en la puerta',
    2: 'Me hizo esperar bastante en la puerta',
    3: 'Todo normal, sin demoras',
    4: 'Estaba listo, todo rápido',
    5: 'Estaba listo, todo rápido',
  },
};

class _CalificacionDialogState extends State<_CalificacionDialog> {
  int _estrellas = 5;
  late final Map<int, String> _sugerencias = _sugerenciasPara(
    widget.calificadoRol,
  );
  late final _comentarioController = TextEditingController(
    text: _sugerencias[_estrellas],
  );

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  void _cambiarEstrellas(int valor) {
    final textoActual = _comentarioController.text;
    final esSugerenciaOVacio =
        textoActual.isEmpty || _sugerencias.values.contains(textoActual);
    setState(() {
      _estrellas = valor;
      if (esSugerenciaOVacio) {
        _comentarioController.text = _sugerencias[valor]!;
      }
    });
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
                  color: Theme.of(context).colorScheme.secondary,
                ),
                tooltip: '$valor estrella${valor == 1 ? '' : 's'}',
                onPressed: () => _cambiarEstrellas(valor),
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
