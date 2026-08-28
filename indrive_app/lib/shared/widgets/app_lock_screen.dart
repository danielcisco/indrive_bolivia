import 'package:flutter/material.dart';

import '../../core/auth/app_lock_service.dart';
import '../../core/auth/cerrar_sesion.dart';

/// Pantalla de bloqueo local (sprint extra) — cubre 2 casos según si ya
/// hay un PIN configurado en este dispositivo:
/// - No hay PIN todavía: ofrece configurarlo (+ huella si el hardware la
///   tiene), o saltarlo — no bloqueante, solo se ofrece una vez
///   (`AppLockService.yaSeOfrecioSetup`).
/// - Ya hay PIN: exige desbloquear (huella primero si está habilitada,
///   PIN siempre disponible como respaldo) antes de mostrar [onDesbloqueado].
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onDesbloqueado});

  final VoidCallback onDesbloqueado;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _service = AppLockService();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  bool _cargando = true;
  bool _tienePin = false;
  bool _biometriaDisponible = false;
  bool _pidiendoConfirmacion = false;
  String? _error;
  bool _autenticando = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final tienePin = await _service.tienePinConfigurado();
    final biometriaDisponible = await _service.biometriaDisponibleEnDispositivo();
    if (!mounted) return;
    setState(() {
      _tienePin = tienePin;
      _biometriaDisponible = biometriaDisponible;
      _cargando = false;
    });
    if (tienePin) await _intentarBiometriaAutomatica();
  }

  Future<void> _intentarBiometriaAutomatica() async {
    final habilitada = await _service.biometriaHabilitada();
    if (!habilitada || !mounted) return;
    setState(() => _autenticando = true);
    final ok = await _service.autenticarConBiometria();
    if (!mounted) return;
    setState(() => _autenticando = false);
    if (ok) widget.onDesbloqueado();
  }

  Future<void> _confirmarPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'El PIN debe tener 4 dígitos.');
      return;
    }
    final ok = await _service.verificarPin(pin);
    if (ok) {
      widget.onDesbloqueado();
    } else {
      setState(() {
        _error = 'PIN incorrecto.';
        _pinController.clear();
      });
    }
  }

  Future<void> _guardarNuevoPin() async {
    final pin = _pinController.text.trim();
    if (!_pidiendoConfirmacion) {
      if (pin.length != 4) {
        setState(() => _error = 'El PIN debe tener 4 dígitos.');
        return;
      }
      setState(() {
        _pidiendoConfirmacion = true;
        _error = null;
      });
      return;
    }
    final confirmacion = _pinConfirmController.text.trim();
    if (confirmacion != pin) {
      setState(() {
        _error = 'Los PIN no coinciden.';
        _pinConfirmController.clear();
      });
      return;
    }
    await _service.configurarPin(pin);
    await _service.marcarSetupOfrecido();
    if (_biometriaDisponible && mounted) {
      final habilitar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Usar tu huella también?'),
          content: const Text(
            'Vas a poder entrar más rápido con tu huella. El PIN sigue '
            'funcionando siempre como respaldo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, gracias'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, usar huella'),
            ),
          ],
        ),
      );
      if (habilitar == true) await _service.habilitarBiometria(true);
    }
    widget.onDesbloqueado();
  }

  Future<void> _saltarSetup() async {
    await _service.marcarSetupOfrecido();
    widget.onDesbloqueado();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _tienePin ? _contenidoDesbloqueo() : _contenidoSetup(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenidoDesbloqueo() {
    return [
      const Icon(Icons.lock_outline, size: 64),
      const SizedBox(height: 16),
      Text(
        'App bloqueada',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _pinController,
        obscureText: true,
        autofocus: true,
        maxLength: 4,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: const InputDecoration(counterText: '', labelText: 'PIN'),
        onSubmitted: (_) => _confirmarPin(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _autenticando ? null : _confirmarPin,
        child: const Text('Desbloquear'),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _autenticando ? null : _intentarBiometriaAutomatica,
        icon: const Icon(Icons.fingerprint),
        label: Text(_autenticando ? 'Verificando...' : 'Usar huella'),
      ),
      const SizedBox(height: 24),
      TextButton(
        onPressed: cerrarSesionYBorrarBloqueo,
        child: const Text('¿Olvidaste tu PIN? Cerrar sesión'),
      ),
    ];
  }

  List<Widget> _contenidoSetup() {
    return [
      const Icon(Icons.lock_outline, size: 64),
      const SizedBox(height: 16),
      Text(
        _pidiendoConfirmacion ? 'Repetí tu PIN' : 'Protegé tu cuenta',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        _pidiendoConfirmacion
            ? 'Ingresalo de nuevo para confirmar.'
            : 'Elegí un PIN de 4 dígitos para entrar rápido la próxima '
                  'vez, sin depender del código por SMS.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _pidiendoConfirmacion ? _pinConfirmController : _pinController,
        obscureText: true,
        autofocus: true,
        maxLength: 4,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(
          counterText: '',
          labelText: _pidiendoConfirmacion ? 'Repetir PIN' : 'Nuevo PIN',
        ),
        onSubmitted: (_) => _guardarNuevoPin(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _guardarNuevoPin,
        child: Text(_pidiendoConfirmacion ? 'Confirmar' : 'Continuar'),
      ),
      if (!_pidiendoConfirmacion) ...[
        const SizedBox(height: 8),
        TextButton(onPressed: _saltarSetup, child: const Text('Ahora no')),
      ],
    ];
  }
}
