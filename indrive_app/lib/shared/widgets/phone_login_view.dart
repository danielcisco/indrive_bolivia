import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/phone_auth_repository.dart';
import '../data/providers.dart';
import 'soporte_whatsapp.dart';

/// Único código de país que opera esta app (Villazón, Potosí, Bolivia) —
/// fijo, no seleccionable, para no pedirle al usuario que lo escriba cada
/// vez ni arrastrar un selector de países que no hace falta.
const _prefijoBolivia = '+591';

/// UI de 3 pasos (teléfono -> código SMS -> nombre/nick solo si es
/// registro nuevo) reutilizada por Cliente y Repartidor: la única
/// diferencia entre ambos es el [role] que se envía a la Cloud Function
/// tras el login.
class PhoneLoginView extends ConsumerStatefulWidget {
  const PhoneLoginView({super.key, required this.role});

  final String role;

  @override
  ConsumerState<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends ConsumerState<PhoneLoginView> {
  final _repository = PhoneAuthRepository();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _nickController = TextEditingController();

  String? _verificationId;
  bool _esRegistroNuevo = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  XFile? _fotoCarnet;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _nickController.dispose();
    super.dispose();
  }

  /// `assignInitialRole` rechaza la llamada si el uid ya tiene rol — pasa
  /// si el usuario alcanzó a tocar "Continuar" dos veces (la primera ya
  /// había funcionado) o si reintenta tras un error de red a mitad de
  /// camino. En ese caso el resultado final es el que queríamos de todas
  /// formas (rol asignado), así que no es un error real para el usuario.
  Future<void> _asignarRolTolerante() async {
    try {
      await _repository.assignInitialRole(widget.role);
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'already-exists') rethrow;
    }
  }

  /// Vuelve a la ruta base (donde vive `AuthGate`) para que el Home que ya
  /// está listo debajo se vea — `BienvenidaScreen`/esta pantalla se
  /// alcanzan con `Navigator.push`, así que nada las saca solas del medio
  /// cuando el login termina.
  void _volverALaBase(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _tomarFotoCarnet() async {
    // imageQuality/maxWidth más altos que una foto de paquete: acá lo que
    // importa es que el Admin pueda leer el número de Cédula ampliando la
    // imagen, no solo confirmar que algo llegó entero (Sprint 9).
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1920,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (foto != null && mounted) setState(() => _fotoCarnet = foto);
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    await _repository.sendVerificationCode(
      phoneNumber: '$_prefijoBolivia${_phoneController.text.trim()}',
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSubmitting = false;
        });
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = error.code == 'invalid-phone-number'
              ? 'Ese número no parece válido. Revisalo e intentá de nuevo.'
              : 'No pudimos enviar el código. Revisá tu conexión y volvé '
                    'a intentar.';
        });
      },
    );
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;
    if (verificationId == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final credencial = await _repository.confirmCode(
        verificationId: verificationId,
        smsCode: _codeController.text.trim(),
      );
      if (credencial.additionalUserInfo?.isNewUser == true) {
        // Primera vez que este teléfono se autentica: pide nombre/nick acá
        // mismo (paso 3) antes de asignar el rol, en vez de una pantalla
        // aparte después — así solo se pregunta al momento de registrarse.
        if (mounted) setState(() => _esRegistroNuevo = true);
      } else {
        await _asignarRolTolerante();
        if (mounted) _volverALaBase(context);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = switch (error.code) {
            'invalid-verification-code' =>
              'El código no es correcto. Revisalo e intentá de nuevo.',
            'session-expired' => 'El código venció. Volvé a pedir uno.',
            _ => 'No pudimos verificar el código. Probá de nuevo.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completarRegistro() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final nick = _nickController.text.trim();
    final foto = _fotoCarnet;
    if (nombre.isEmpty || apellido.isEmpty || nick.isEmpty || foto == null) {
      setState(
        () => _errorMessage =
            'Completa nombre, apellido, nick y la foto de tu carnet.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final repository = ref.read(usersRepositoryProvider);
      final url = await repository.subirFotoCedula(
        uid: uid,
        archivo: File(foto.path),
      );
      await repository.actualizarPerfil(
        uid,
        nombre: nombre,
        apellido: apellido,
        nick: nick,
      );
      await repository.guardarCedulaUrl(uid, url);
      await _asignarRolTolerante();
      if (mounted) _volverALaBase(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'No pudimos guardar tus datos. Revisá tu '
              'conexión y volvé a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final awaitingCode = _verificationId != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_esRegistroNuevo) ...[
            const Text(
              'Contanos cómo te llamás y sacá una foto de tu Cédula de '
              'Identidad — así el Cliente y el Repartidor pueden '
              'identificarse entre sí.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombres'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apellidoController,
              decoration: const InputDecoration(labelText: 'Apellidos'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nickController,
              decoration: const InputDecoration(labelText: 'Nick'),
            ),
            const SizedBox(height: 16),
            if (_fotoCarnet != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_fotoCarnet!.path), height: 180),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _tomarFotoCarnet,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _fotoCarnet == null ? 'Tomar foto de tu Cédula' : 'Repetir foto',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_isSubmitting || _fotoCarnet == null)
                    ? null
                    : _completarRegistro,
                icon: const Icon(Icons.check_outlined),
                label: Text(_isSubmitting ? 'Guardando...' : 'Continuar'),
              ),
            ),
          ] else if (!awaitingCode) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '71234567',
                prefixText: '$_prefijoBolivia ',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _sendCode,
                icon: const Icon(Icons.sms_outlined),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar código'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Código SMS'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _confirmCode,
                icon: const Icon(Icons.check_outlined),
                label: Text(_isSubmitting ? 'Confirmando...' : 'Confirmar'),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => abrirSoporteWhatsapp(
                ref: ref,
                app: widget.role == 'cliente' ? 'Cliente' : 'Repartidor',
                motivo: 'no puedo iniciar sesión ni registrarme',
              ),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('¿Sigue fallando? Contactar soporte'),
            ),
          ],
        ],
      ),
    );
  }
}
