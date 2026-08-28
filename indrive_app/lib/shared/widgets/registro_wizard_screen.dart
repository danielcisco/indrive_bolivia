import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/providers.dart';
import '../domain/marcas_vehiculo.dart';
import 'agradecimiento_screen.dart';
import 'pantalla_instrucciones_foto.dart';
import 'selector_color_vehiculo.dart';
import 'selector_con_buscador.dart';

enum _Paso { personal, documento, licencia, vehiculo, soat }

/// Wizard de registro en varios pasos (Sprints 18-20) — reemplaza el
/// formulario único que tenía `PhoneLoginView`. Cliente recorre 2 pasos
/// (información personal + Cédula); Repartidor recorre 5 (suma licencia
/// de conducir, datos de vehículo, y SOAT opcional) — el pasajero nunca
/// carga datos de vehículo, coherente con el flujo real de inDrive.
///
/// [onCompletado] lo llama recién después de que el usuario cierra la
/// pantalla de agradecimiento — `PhoneLoginView` la usa para asignar el
/// rol y volver a la base, manteniendo esa lógica en un solo lugar.
class RegistroWizardScreen extends ConsumerStatefulWidget {
  const RegistroWizardScreen({
    super.key,
    required this.role,
    required this.onCompletado,
  });

  final String role;
  final Future<void> Function() onCompletado;

  @override
  ConsumerState<RegistroWizardScreen> createState() =>
      _RegistroWizardScreenState();
}

class _RegistroWizardScreenState extends ConsumerState<RegistroWizardScreen> {
  late final List<_Paso> _pasos = widget.role == 'repartidor'
      ? [_Paso.personal, _Paso.documento, _Paso.licencia, _Paso.vehiculo, _Paso.soat]
      : [_Paso.personal, _Paso.documento];

  int _indice = 0;
  bool _procesando = false;
  String? _error;

  // Paso 1: información personal.
  XFile? _fotoPersonal;
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _nickController = TextEditingController();
  DateTime? _fechaNacimiento;

  // Paso 2: documento de identidad.
  XFile? _fotoCedula;

  // Paso 3 (Repartidor): licencia de conducir.
  final _numeroLicenciaController = TextEditingController();
  DateTime? _fechaExpiracionLicencia;
  XFile? _licenciaFrente;
  XFile? _licenciaDorso;
  XFile? _selfieLicencia;

  // Paso 4 (Repartidor): vehículo.
  String? _tipoVehiculo;
  String? _marcaVehiculo;
  final _modeloController = TextEditingController();
  String? _colorVehiculo;
  final _placaController = TextEditingController();
  final _anioController = TextEditingController();
  XFile? _fotoVehiculo;
  XFile? _tarjetaCirculacion;

  // Paso 5 (Repartidor, opcional): SOAT.
  XFile? _soat;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _nickController.dispose();
    _numeroLicenciaController.dispose();
    _modeloController.dispose();
    _placaController.dispose();
    _anioController.dispose();
    super.dispose();
  }

  bool _esMayorDeEdad(DateTime nacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad >= 18;
  }

  String? _validarPaso(_Paso paso) {
    switch (paso) {
      case _Paso.personal:
        if (_fotoPersonal == null) return 'Sacate una foto personal.';
        if (_nombreController.text.trim().isEmpty) return 'Completa tu nombre.';
        if (_apellidoController.text.trim().isEmpty) {
          return 'Completa tu apellido.';
        }
        if (_nickController.text.trim().isEmpty) return 'Completa tu nick.';
        final nacimiento = _fechaNacimiento;
        if (nacimiento == null) return 'Elegí tu fecha de nacimiento.';
        if (!_esMayorDeEdad(nacimiento)) {
          return 'Tenés que ser mayor de 18 años para registrarte.';
        }
        return null;
      case _Paso.documento:
        if (_fotoCedula == null) return 'Sacá una foto de tu Cédula.';
        return null;
      case _Paso.licencia:
        if (_numeroLicenciaController.text.trim().isEmpty) {
          return 'Completa el número de tu licencia.';
        }
        if (_fechaExpiracionLicencia == null) {
          return 'Elegí la fecha de expiración de tu licencia.';
        }
        if (_licenciaFrente == null || _licenciaDorso == null || _selfieLicencia == null) {
          return 'Faltan fotos de tu licencia.';
        }
        return null;
      case _Paso.vehiculo:
        if (_tipoVehiculo == null) return 'Elegí el tipo de vehículo.';
        if (_marcaVehiculo == null) return 'Elegí la marca de tu vehículo.';
        if (_modeloController.text.trim().isEmpty) return 'Completa el modelo.';
        if (_colorVehiculo == null) return 'Elegí el color de tu vehículo.';
        if (_placaController.text.trim().isEmpty) return 'Completa la placa.';
        if (int.tryParse(_anioController.text.trim()) == null) {
          return 'Completa el año de fabricación.';
        }
        if (_fotoVehiculo == null || _tarjetaCirculacion == null) {
          return 'Faltan fotos del vehículo.';
        }
        return null;
      case _Paso.soat:
        return null; // Opcional, sin validación.
    }
  }

  Future<void> _avanzar() async {
    final error = _validarPaso(_pasos[_indice]);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    if (_indice < _pasos.length - 1) {
      setState(() => _indice++);
    } else {
      await _finalizar();
    }
  }

  void _retroceder() {
    if (_indice == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _indice--;
      _error = null;
    });
  }

  Future<void> _finalizar() async {
    setState(() => _procesando = true);
    try {
      // FirebaseAuth.instance.currentUser directo, no authUidProvider: a
      // esta altura (todavía dentro del registro, antes de llegar a
      // Home) ese provider nunca fue observado por nadie más, así que su
      // primer `ref.read()` lo encuentra en loading con `.value == null`
      // — tiraba "Sesión no encontrada" sin haber subido ni guardado
      // nada. Bug real reportado: el wizard fallaba siempre en el último
      // paso y, como no llegó a escribir nombre/nick, `AuthGate` volvía a
      // mostrar el wizard desde cero en el siguiente lanzamiento.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sesión no encontrada.');
      final repository = ref.read(usersRepositoryProvider);

      final fotoPersonalUrl = await repository.subirFotoPersonal(
        uid: uid,
        archivo: File(_fotoPersonal!.path),
      );
      final cedulaUrl = await repository.subirFotoCedula(
        uid: uid,
        archivo: File(_fotoCedula!.path),
      );
      await repository.actualizarPerfil(
        uid,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        nick: _nickController.text.trim(),
      );
      await repository.guardarDatosPersonales(
        uid,
        fechaNacimiento: _fechaNacimiento!,
        fotoPersonalUrl: fotoPersonalUrl,
      );
      await repository.guardarCedulaUrl(uid, cedulaUrl);

      if (widget.role == 'repartidor') {
        final licenciaFrenteUrl = await repository.subirFotoDocumento(
          carpeta: 'licencia',
          uid: uid,
          tipo: 'frente',
          archivo: File(_licenciaFrente!.path),
        );
        final licenciaDorsoUrl = await repository.subirFotoDocumento(
          carpeta: 'licencia',
          uid: uid,
          tipo: 'dorso',
          archivo: File(_licenciaDorso!.path),
        );
        final selfieLicenciaUrl = await repository.subirFotoDocumento(
          carpeta: 'licencia',
          uid: uid,
          tipo: 'selfie',
          archivo: File(_selfieLicencia!.path),
        );
        await repository.guardarDatosLicencia(
          uid,
          numeroLicencia: _numeroLicenciaController.text.trim(),
          fechaExpiracion: _fechaExpiracionLicencia!,
          licenciaFrenteUrl: licenciaFrenteUrl,
          licenciaDorsoUrl: licenciaDorsoUrl,
          selfieLicenciaUrl: selfieLicenciaUrl,
        );

        final fotoVehiculoUrl = await repository.subirFotoDocumento(
          carpeta: 'vehiculo',
          uid: uid,
          tipo: 'vehiculo',
          archivo: File(_fotoVehiculo!.path),
        );
        final tarjetaCirculacionUrl = await repository.subirFotoDocumento(
          carpeta: 'vehiculo',
          uid: uid,
          tipo: 'tarjeta',
          archivo: File(_tarjetaCirculacion!.path),
        );
        String? soatUrl;
        if (_soat != null) {
          soatUrl = await repository.subirFotoDocumento(
            carpeta: 'vehiculo',
            uid: uid,
            tipo: 'soat',
            archivo: File(_soat!.path),
          );
        }
        await repository.guardarDatosVehiculo(
          uid,
          tipoVehiculo: _tipoVehiculo!,
          marcaVehiculo: _marcaVehiculo!,
          modeloVehiculo: _modeloController.text.trim(),
          colorVehiculo: _colorVehiculo!,
          placaVehiculo: _placaController.text.trim(),
          anioVehiculo: int.parse(_anioController.text.trim()),
          fotoVehiculoUrl: fotoVehiculoUrl,
          tarjetaCirculacionUrl: tarjetaCirculacionUrl,
          soatUrl: soatUrl,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AgradecimientoScreen(
            mensaje:
                'Tu registro quedó guardado. Un administrador va a revisar '
                'tus documentos antes de aprobarte.',
          ),
        ),
      );
      await widget.onCompletado();
    } catch (error, stackTrace) {
      debugPrint('RegistroWizardScreen._finalizar falló: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _error = 'No pudimos guardar tu registro. Revisá tu '
              'conexión y volvé a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paso = _pasos[_indice];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _procesando ? null : _retroceder,
        ),
        title: Text('${_indice + 1} de ${_pasos.length}'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_indice + 1) / _pasos.length,
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: switch (paso) {
                _Paso.personal => _pasoPersonal(),
                _Paso.documento => _pasoDocumento(),
                _Paso.licencia => _pasoLicencia(),
                _Paso.vehiculo => _pasoVehiculo(),
                _Paso.soat => _pasoSoat(),
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _procesando ? null : _avanzar,
                child: Text(
                  _procesando
                      ? 'Guardando...'
                      : (_indice == _pasos.length - 1 ? 'Finalizar' : 'Siguiente'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloPaso(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(texto, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget _pasoPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloPaso('Información personal'),
        Center(
          child: _fotoPersonal == null
              ? OutlinedButton.icon(
                  onPressed: () async {
                    final foto = await mostrarInstruccionesYTomarFoto(
                      context,
                      titulo: 'Foto personal',
                      icono: Icons.face_retouching_natural,
                      recomendaciones: const [
                        'Que se te vea la cara con claridad.',
                        'Buena luz, sin gorra ni lentes de sol.',
                        'Sin filtros.',
                      ],
                    );
                    if (foto != null) setState(() => _fotoPersonal = foto);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Foto personal'),
                )
              : PreviewFotoTomada(
                  foto: _fotoPersonal!,
                  onRepetir: () => setState(() => _fotoPersonal = null),
                ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nombreController,
          decoration: const InputDecoration(labelText: 'Nombre'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apellidoController,
          decoration: const InputDecoration(labelText: 'Apellido'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nickController,
          decoration: const InputDecoration(labelText: 'Nick'),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final hoy = DateTime.now();
            final elegida = await showDatePicker(
              context: context,
              initialDate: DateTime(hoy.year - 25),
              firstDate: DateTime(1930),
              lastDate: hoy,
            );
            if (elegida != null) setState(() => _fechaNacimiento = elegida);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
            child: Text(
              _fechaNacimiento == null
                  ? 'dd/mm/aaaa'
                  : '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/'
                        '${_fechaNacimiento!.month.toString().padLeft(2, '0')}/'
                        '${_fechaNacimiento!.year}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _pasoDocumento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloPaso('Documento de identidad'),
        const Text(
          'Sacá una foto clara del frente de tu Cédula de Identidad. Un '
          'administrador la va a revisar antes de aprobar tu cuenta.',
        ),
        const SizedBox(height: 16),
        Center(
          child: _fotoCedula == null
              ? OutlinedButton.icon(
                  onPressed: () async {
                    final foto = await mostrarInstruccionesYTomarFoto(
                      context,
                      titulo: 'Cédula de Identidad',
                      icono: Icons.badge_outlined,
                      recomendaciones: const [
                        'Foto clara, sin capturas de pantalla ni fotocopias.',
                        'Sin filtros, todos los datos deben verse bien.',
                        'El documento completo dentro del cuadro.',
                      ],
                    );
                    if (foto != null) setState(() => _fotoCedula = foto);
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto de tu Cédula'),
                )
              : PreviewFotoTomada(
                  foto: _fotoCedula!,
                  onRepetir: () => setState(() => _fotoCedula = null),
                ),
        ),
      ],
    );
  }

  Widget _pasoLicencia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloPaso('Licencia de conducir'),
        _filaFoto(
          etiqueta: 'Licencia de conducir (frente)',
          foto: _licenciaFrente,
          onTomar: () => _tomarFotoLicencia('frente'),
        ),
        const SizedBox(height: 12),
        _filaFoto(
          etiqueta: 'Parte de atrás de la licencia',
          foto: _licenciaDorso,
          onTomar: () => _tomarFotoLicencia('dorso'),
        ),
        const SizedBox(height: 12),
        _filaFoto(
          etiqueta: 'Selfie con la licencia',
          foto: _selfieLicencia,
          onTomar: () => _tomarFotoLicencia('selfie'),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _numeroLicenciaController,
          decoration: const InputDecoration(labelText: 'Número de licencia'),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final hoy = DateTime.now();
            final elegida = await showDatePicker(
              context: context,
              initialDate: hoy,
              firstDate: hoy,
              lastDate: hoy.add(const Duration(days: 365 * 20)),
            );
            if (elegida != null) {
              setState(() => _fechaExpiracionLicencia = elegida);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Fecha de expiración'),
            child: Text(
              _fechaExpiracionLicencia == null
                  ? 'dd/mm/aaaa'
                  : '${_fechaExpiracionLicencia!.day.toString().padLeft(2, '0')}/'
                        '${_fechaExpiracionLicencia!.month.toString().padLeft(2, '0')}/'
                        '${_fechaExpiracionLicencia!.year}',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _tomarFotoLicencia(String tipo) async {
    final foto = await mostrarInstruccionesYTomarFoto(
      context,
      titulo: 'Licencia de conducir',
      icono: Icons.credit_card,
      recomendaciones: const [
        'Foto clara, sin capturas de pantalla ni fotocopias.',
        'Sin filtros, tu cara y todos los detalles deben verse bien.',
      ],
    );
    if (foto == null || !mounted) return;
    setState(() {
      switch (tipo) {
        case 'frente':
          _licenciaFrente = foto;
        case 'dorso':
          _licenciaDorso = foto;
        case 'selfie':
          _selfieLicencia = foto;
      }
    });
  }

  Widget _pasoVehiculo() {
    final marcas = _tipoVehiculo == 'auto' ? marcasAuto : marcasMoto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloPaso('Información del vehículo'),
        const Text('Tipo de vehículo'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Motocicleta'),
              selected: _tipoVehiculo == 'moto',
              onSelected: (_) => setState(() {
                _tipoVehiculo = 'moto';
                _marcaVehiculo = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Automóvil'),
              selected: _tipoVehiculo == 'auto',
              onSelected: (_) => setState(() {
                _tipoVehiculo = 'auto';
                _marcaVehiculo = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _filaFoto(
          etiqueta: 'Foto del vehículo',
          foto: _fotoVehiculo,
          onTomar: () => _tomarFotoVehiculo('vehiculo'),
        ),
        const SizedBox(height: 12),
        _filaFoto(
          etiqueta: 'Tarjeta de circulación',
          foto: _tarjetaCirculacion,
          onTomar: () => _tomarFotoVehiculo('tarjeta'),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () async {
            final elegida = await mostrarSelectorConBuscador(
              context,
              titulo: 'Marca del vehículo',
              opciones: marcas,
            );
            if (elegida != null) setState(() => _marcaVehiculo = elegida);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Marca del vehículo'),
            child: Text(_marcaVehiculo ?? 'Elegir marca'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _modeloController,
          decoration: const InputDecoration(labelText: 'Modelo del vehículo'),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final elegido = await mostrarSelectorColorVehiculo(context);
            if (elegido != null) setState(() => _colorVehiculo = elegido);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Color del vehículo'),
            child: Text(_colorVehiculo ?? 'Elegir color'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _placaController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Número de placas'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _anioController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Año de manufactura'),
        ),
      ],
    );
  }

  Future<void> _tomarFotoVehiculo(String tipo) async {
    final foto = await mostrarInstruccionesYTomarFoto(
      context,
      titulo: 'Vehículo',
      icono: Icons.two_wheeler,
      recomendaciones: const [
        'Foto clara, sin capturas de pantalla ni fotocopias.',
        'Que se vea el vehículo completo, o el documento entero.',
      ],
    );
    if (foto == null || !mounted) return;
    setState(() {
      if (tipo == 'vehiculo') {
        _fotoVehiculo = foto;
      } else {
        _tarjetaCirculacion = foto;
      }
    });
  }

  Widget _pasoSoat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloPaso('SOAT (opcional)'),
        const Text(
          'Solo aplica en Bolivia. Si todavía no lo tenés, podés saltar '
          'este paso y subirlo más adelante desde tu perfil.',
        ),
        const SizedBox(height: 16),
        _filaFoto(
          etiqueta: 'Foto del SOAT',
          foto: _soat,
          onTomar: () async {
            final foto = await mostrarInstruccionesYTomarFoto(
              context,
              titulo: 'SOAT',
              icono: Icons.shield_outlined,
              recomendaciones: const [
                'Foto clara, sin capturas de pantalla ni fotocopias.',
                'Que se vean todos los datos del documento.',
              ],
            );
            if (foto != null) setState(() => _soat = foto);
          },
        ),
      ],
    );
  }

  Widget _filaFoto({
    required String etiqueta,
    required XFile? foto,
    required VoidCallback onTomar,
  }) {
    return Row(
      children: [
        Expanded(child: Text(etiqueta)),
        if (foto != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(foto.path), width: 48, height: 48, fit: BoxFit.cover),
          ),
        IconButton(
          onPressed: onTomar,
          icon: Icon(foto == null ? Icons.add_a_photo_outlined : Icons.refresh),
        ),
      ],
    );
  }
}
