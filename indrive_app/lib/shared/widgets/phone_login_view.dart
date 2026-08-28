import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/phone_auth_repository.dart';
import 'registro_wizard_screen.dart';
import 'soporte_whatsapp.dart';

/// Países que operan esta app (Sprint 17): Villazón es una ciudad de
/// frontera pegada a La Quiaca, Argentina — separadas por ~2km, así que
/// hay demanda real de números argentinos también, no solo bolivianos.
/// `smsRegionConfig.allowlistOnly` en el proyecto de Firebase Auth ya
/// permite ambos países (antes solo BO).
class _Pais {
  const _Pais({required this.bandera, required this.prefijo, required this.nombre});
  final String bandera;
  final String prefijo;
  final String nombre;
}

const _paises = [
  _Pais(bandera: '🇧🇴', prefijo: '+591', nombre: 'Bolivia'),
  _Pais(bandera: '🇦🇷', prefijo: '+54', nombre: 'Argentina'),
];

/// Teléfono -> código SMS -> wizard de registro si es cuenta nueva
/// (`RegistroWizardScreen`, Sprints 18-20) reutilizada por Cliente y
/// Repartidor: la única diferencia entre ambos es el [role] que se envía
/// a la Cloud Function tras el login.
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

  _Pais _pais = _paises.first;
  String? _verificationId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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
  /// está listo debajo se vea — `BienvenidaScreen`/esta pantalla/el wizard
  /// se alcanzan con `Navigator.push`, así que nada las saca solas del
  /// medio cuando el login termina.
  void _volverALaBase(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    await _repository.sendVerificationCode(
      phoneNumber: '${_pais.prefijo}${_phoneController.text.trim()}',
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
        // Primera vez que este teléfono se autentica: el wizard pide el
        // resto de los datos (Sprints 18-20) y recién al final asigna el
        // rol y vuelve a la base — no antes.
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RegistroWizardScreen(
                role: widget.role,
                onCompletado: () async {
                  await _asignarRolTolerante();
                  if (mounted) _volverALaBase(context);
                },
              ),
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final awaitingCode = _verificationId != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!awaitingCode) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_Pais>(
                      value: _pais,
                      onChanged: (pais) {
                        if (pais != null) setState(() => _pais = pais);
                      },
                      items: [
                        for (final pais in _paises)
                          DropdownMenuItem(
                            value: pais,
                            child: Text('${pais.bandera}  ${pais.prefijo}'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      hintText: '71234567',
                    ),
                  ),
                ),
              ],
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
