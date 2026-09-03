import 'package:flutter/material.dart';

import '../../core/auth/app_lock_service.dart';
import 'app_lock_screen.dart';

/// Envuelve el Home de Cliente/Repartidor con el bloqueo local (sprint
/// extra) — pide desbloqueo una vez por arranque del proceso (al crear
/// este State), no en cada vez que la app pasa a segundo plano. Además,
/// si Android mató el proceso mientras estaba en gracia (`AppLockService.
/// graciaTrasReinicio`, 5 min — muy común en Repartidor por el Foreground
/// Service de GPS + mapa en vivo), tampoco vuelve a pedir: ver
/// `AppLockService.desbloqueadoRecientemente`.
///
/// Decisión explícita a pedido del usuario: se prioriza no interrumpir
/// por cambiar de app un momento (mirar un SMS, WhatsApp) y volver, aun
/// si eso implicó un arranque en frío real. Dejar el celular sin usar más
/// de 5 minutos sí vuelve a pedir desbloqueo.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _service = AppLockService();
  bool _cargando = true;
  bool _desbloqueado = false;

  @override
  void initState() {
    super.initState();
    _evaluarEstadoInicial();
  }

  Future<void> _evaluarEstadoInicial() async {
    final tienePin = await _service.tienePinConfigurado();
    final yaOfrecido = await _service.yaSeOfrecioSetup();
    // Solo aplica si hay PIN configurado — sin bloqueo activo no hay nada
    // de qué dar gracia.
    final desbloqueadoRecientemente =
        tienePin && await _service.desbloqueadoRecientemente();
    if (!mounted) return;
    setState(() {
      // Sin PIN configurado y ya se ofreció antes (lo saltó): no hay
      // nada que bloquear, entra directo. Sin PIN y nunca se ofreció:
      // AppLockScreen se encarga de mostrar el setup antes de desbloquear.
      // Con PIN y desbloqueado hace menos de 5 minutos: no repetir el
      // desbloqueo por un arranque en frío causado por Android matando
      // el proceso (típico en Repartidor, ver AppLockService).
      _desbloqueado = desbloqueadoRecientemente || (!tienePin && yaOfrecido);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_desbloqueado) {
      return AppLockScreen(
        onDesbloqueado: () => setState(() => _desbloqueado = true),
      );
    }
    return widget.child;
  }
}
