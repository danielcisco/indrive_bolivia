import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Cuenta regresiva hasta [expiraEn] (sprint extra — Grupo A). Usa
/// `DateTime.now()` del dispositivo únicamente para animar el conteo
/// visual contra el vencimiento que ya llegó del servidor — no define ni
/// escribe ningún vencimiento, así que no choca con la regla no
/// negociable de CLAUDE.md sobre "nunca DateTime.now() del cliente para
/// vencimientos" (esa regla es sobre qué momento es la autoridad, no
/// sobre cómo se anima en pantalla).
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({super.key, required this.expiraEn});

  final Timestamp? expiraEn;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _ticker;
  Duration _restante = Duration.zero;

  @override
  void initState() {
    super.initState();
    _actualizar();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _actualizar());
  }

  @override
  void didUpdateWidget(covariant CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiraEn != widget.expiraEn) _actualizar();
  }

  void _actualizar() {
    final expiraEn = widget.expiraEn;
    final restante = expiraEn == null
        ? Duration.zero
        : expiraEn.toDate().difference(DateTime.now());
    if (mounted) setState(() => _restante = restante);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expiraEn == null) {
      return const Text('Calculando tiempo restante...');
    }
    if (_restante.isNegative) {
      return Text(
        'Vencido',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    final minutos = _restante.inMinutes.remainder(60).toString().padLeft(
      2,
      '0',
    );
    final segundos = _restante.inSeconds.remainder(60).toString().padLeft(
      2,
      '0',
    );
    return Text('Tiempo restante: $minutos:$segundos');
  }
}
