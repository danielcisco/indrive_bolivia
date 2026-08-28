import 'package:flutter/material.dart';

import '../../core/auth/app_lock_service.dart';
import 'app_lock_screen.dart';

/// Envuelve el Home de Cliente/Repartidor con el bloqueo local (sprint
/// extra) — vuelve a pedir desbloqueo cada vez que la app pasa a
/// segundo plano de verdad (`paused`), no en cada `inactive` transitorio
/// (ej. un diálogo del sistema tapando la app un instante), que sería
/// molesto de más.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _service = AppLockService();
  bool _cargando = true;
  bool _desbloqueado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _evaluarEstadoInicial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _evaluarEstadoInicial() async {
    final tienePin = await _service.tienePinConfigurado();
    final yaOfrecido = await _service.yaSeOfrecioSetup();
    if (!mounted) return;
    setState(() {
      // Sin PIN configurado y ya se ofreció antes (lo saltó): no hay
      // nada que bloquear, entra directo. Sin PIN y nunca se ofreció:
      // AppLockScreen se encarga de mostrar el setup antes de desbloquear.
      _desbloqueado = !tienePin && yaOfrecido;
      _cargando = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _service.tienePinConfigurado().then((tienePin) {
      if (tienePin && mounted) setState(() => _desbloqueado = false);
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
