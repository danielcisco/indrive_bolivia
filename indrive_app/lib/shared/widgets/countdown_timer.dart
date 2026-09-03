import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/colores_semanticos.dart';

/// Cuenta regresiva hasta [expiraEn] (sprint extra — Grupo A). Usa
/// `DateTime.now()` del dispositivo únicamente para animar el conteo
/// visual contra el vencimiento que ya llegó del servidor — no define ni
/// escribe ningún vencimiento, así que no choca con la regla no
/// negociable de CLAUDE.md sobre "nunca DateTime.now() del cliente para
/// vencimientos" (esa regla es sobre qué momento es la autoridad, no
/// sobre cómo se anima en pantalla).
///
/// Anillo circular en vez de solo texto (sprint de rediseño) — mismo
/// único parámetro público (`expiraEn`), así que ningún call site cambia.
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({super.key, required this.expiraEn});

  final Timestamp? expiraEn;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _ticker;
  Duration _restante = Duration.zero;

  /// Se fija en la primera lectura — no depende de ningún dato nuevo del
  /// servidor, solo de cuánto faltaba la primera vez que este widget vio
  /// [expiraEn]. Es la referencia para calcular la fracción del anillo
  /// (no hay forma de saber la duración total de la subasta desde acá
  /// más que "lo que faltaba cuando se montó").
  Duration? _duracionInicial;

  @override
  void initState() {
    super.initState();
    _actualizar();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _actualizar());
  }

  @override
  void didUpdateWidget(covariant CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiraEn != widget.expiraEn) {
      _duracionInicial = null;
      _actualizar();
    }
  }

  void _actualizar() {
    final expiraEn = widget.expiraEn;
    final restante = expiraEn == null
        ? Duration.zero
        : expiraEn.toDate().difference(DateTime.now());
    _duracionInicial ??= restante.isNegative ? null : restante;
    if (mounted) setState(() => _restante = restante);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Escala de urgencia antes de vencer, no solo después (Sprint 16) — un
  // texto que se mantiene neutro hasta último momento no avisa a tiempo
  // de que la subasta está por cerrarse.
  static const _umbralAmbar = Duration(minutes: 5);
  static const _umbralRojo = Duration(minutes: 1);

  @override
  Widget build(BuildContext context) {
    if (widget.expiraEn == null) {
      return const Text('Calculando tiempo restante...');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final vencido = _restante.isNegative;
    final Color colorAro = vencido
        ? colorScheme.error
        : _restante <= _umbralRojo
        ? colorScheme.error
        : _restante <= _umbralAmbar
        ? ColoresSemanticos.advertencia(context).$1
        : colorScheme.primary;

    final duracionInicial = _duracionInicial;
    final fraccion = vencido || duracionInicial == null || duracionInicial.inSeconds == 0
        ? 0.0
        : (_restante.inSeconds / duracionInicial.inSeconds).clamp(0.0, 1.0);

    final minutos = _restante.inMinutes.remainder(60).abs().toString().padLeft(
      2,
      '0',
    );
    final segundos = _restante.inSeconds.remainder(60).abs().toString().padLeft(
      2,
      '0',
    );

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: vencido ? 1 : fraccion,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorAro),
            ),
          ),
          if (vencido)
            Text(
              'Vencido',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$minutos:$segundos',
                  style: TextStyle(
                    color: colorAro,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'restante',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
