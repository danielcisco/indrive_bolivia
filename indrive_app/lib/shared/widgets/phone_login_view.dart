import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/phone_auth_repository.dart';

/// UI de 2 pasos (teléfono -> código SMS) reutilizada por Cliente y
/// Repartidor: la única diferencia entre ambos es el [role] que se envía
/// a la Cloud Function tras el login.
class PhoneLoginView extends StatefulWidget {
  const PhoneLoginView({super.key, required this.role});

  final String role;

  @override
  State<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends State<PhoneLoginView> {
  final _repository = PhoneAuthRepository();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    await _repository.sendVerificationCode(
      phoneNumber: _phoneController.text.trim(),
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
          _errorMessage = error.message ?? 'No se pudo enviar el código.';
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
      await _repository.confirmCode(
        verificationId: verificationId,
        smsCode: _codeController.text.trim(),
      );
      await _repository.assignInitialRole(widget.role);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message ?? 'Código inválido.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final awaitingCode = _verificationId != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!awaitingCode) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (ej. +59171234567)',
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
