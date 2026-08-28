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

/// Un campo individual dentro de un [_Paso] ("formulario") — el wizard
/// avanza de a un campo por vez con "Siguiente"; recién al llenar el
/// último campo del formulario el botón pasa a decir "Continuar" (o
/// "Finalizar" en el último formulario).
class _Campo {
  const _Campo({required this.builder, required this.validar});
  final Widget Function() builder;
  final String? Function() validar;
}

/// Wizard de registro en varios pasos (Sprints 18-20) — reemplaza el
/// formulario único que tenía `PhoneLoginView`. Cliente recorre 2 pasos
/// (información personal + Cédula); Repartidor recorre 5 (suma licencia
/// de conducir, datos de vehículo, y SOAT opcional) — el pasajero nunca
/// carga datos de vehículo, coherente con el flujo real de inDrive.
///
/// Cada paso muestra sus campos de a uno (sprint extra: antes mostraba
/// todos los campos del paso juntos en una sola pantalla) — "Siguiente"
/// avanza al próximo campo del mismo paso; al llenar el último campo pasa
/// a "Continuar" (o "Finalizar" en el último paso).
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
      ? [
          _Paso.personal,
          _Paso.documento,
          _Paso.licencia,
          _Paso.vehiculo,
          _Paso.soat,
        ]
      : [_Paso.personal, _Paso.documento];

  int _indice = 0;
  int _indiceCampo = 0;
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

  String _nombrePaso(_Paso paso) => switch (paso) {
    _Paso.personal => 'Información personal',
    _Paso.documento => 'Documento de identidad',
    _Paso.licencia => 'Licencia de conducir',
    _Paso.vehiculo => 'Información del vehículo',
    _Paso.soat => 'SOAT (opcional)',
  };

  /// Recalculado en cada build (no cacheado): los campos de vehículo
  /// dependen de `_tipoVehiculo`, que puede cambiar entre una llamada y
  /// la otra.
  List<_Campo> _camposDe(_Paso paso) {
    switch (paso) {
      case _Paso.personal:
        return [
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Tu foto',
              tituloInstrucciones: 'Foto personal',
              icono: Icons.face_retouching_natural,
              recomendaciones: const [
                'Que se te vea la cara con claridad.',
                'Buena luz, sin gorra ni lentes de sol.',
                'Sin filtros.',
              ],
              foto: _fotoPersonal,
              onCambiar: (f) => setState(() => _fotoPersonal = f),
            ),
            validar: () =>
                _fotoPersonal == null ? 'Sacate una foto personal.' : null,
          ),
          _Campo(
            builder: () => _campoTexto(
              etiquetaCampo: 'Nombre',
              controller: _nombreController,
              capitalizacion: TextCapitalization.words,
            ),
            validar: () => _nombreController.text.trim().isEmpty
                ? 'Completa tu nombre.'
                : null,
          ),
          _Campo(
            builder: () => _campoTexto(
              etiquetaCampo: 'Apellido',
              controller: _apellidoController,
              capitalizacion: TextCapitalization.words,
            ),
            validar: () => _apellidoController.text.trim().isEmpty
                ? 'Completa tu apellido.'
                : null,
          ),
          _Campo(
            builder: () =>
                _campoTexto(etiquetaCampo: 'Nick', controller: _nickController),
            validar: () => _nickController.text.trim().isEmpty
                ? 'Completa tu nick.'
                : null,
          ),
          _Campo(
            builder: () => _campoFecha(
              etiquetaCampo: 'Fecha de nacimiento',
              valor: _fechaNacimiento,
              inicial: DateTime(DateTime.now().year - 25),
              primeraFecha: DateTime(1930),
              ultimaFecha: DateTime.now(),
              onCambiar: (f) => setState(() => _fechaNacimiento = f),
            ),
            validar: () {
              final nacimiento = _fechaNacimiento;
              if (nacimiento == null) return 'Elegí tu fecha de nacimiento.';
              if (!_esMayorDeEdad(nacimiento)) {
                return 'Tenés que ser mayor de 18 años para registrarte.';
              }
              return null;
            },
          ),
        ];
      case _Paso.documento:
        return [
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Cédula de Identidad',
              descripcion:
                  'Sacá una foto clara del frente de tu Cédula de Identidad. '
                  'Un administrador la va a revisar antes de aprobar tu '
                  'cuenta.',
              tituloInstrucciones: 'Cédula de Identidad',
              icono: Icons.badge_outlined,
              recomendaciones: const [
                'Foto clara, sin capturas de pantalla ni fotocopias.',
                'Sin filtros, todos los datos deben verse bien.',
                'El documento completo dentro del cuadro.',
              ],
              foto: _fotoCedula,
              onCambiar: (f) => setState(() => _fotoCedula = f),
            ),
            validar: () =>
                _fotoCedula == null ? 'Sacá una foto de tu Cédula.' : null,
          ),
        ];
      case _Paso.licencia:
        const recomendacionesLicencia = [
          'Foto clara, sin capturas de pantalla ni fotocopias.',
          'Sin filtros, tu cara y todos los detalles deben verse bien.',
        ];
        return [
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Licencia de conducir (frente)',
              tituloInstrucciones: 'Licencia de conducir',
              icono: Icons.credit_card,
              recomendaciones: recomendacionesLicencia,
              foto: _licenciaFrente,
              onCambiar: (f) => setState(() => _licenciaFrente = f),
            ),
            validar: () => _licenciaFrente == null
                ? 'Sacá una foto del frente de tu licencia.'
                : null,
          ),
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Parte de atrás de la licencia',
              tituloInstrucciones: 'Licencia de conducir',
              icono: Icons.credit_card,
              recomendaciones: recomendacionesLicencia,
              foto: _licenciaDorso,
              onCambiar: (f) => setState(() => _licenciaDorso = f),
            ),
            validar: () => _licenciaDorso == null
                ? 'Sacá una foto del dorso de tu licencia.'
                : null,
          ),
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Selfie con tu licencia',
              tituloInstrucciones: 'Licencia de conducir',
              icono: Icons.credit_card,
              recomendaciones: recomendacionesLicencia,
              foto: _selfieLicencia,
              onCambiar: (f) => setState(() => _selfieLicencia = f),
            ),
            validar: () => _selfieLicencia == null
                ? 'Sacate una selfie con tu licencia.'
                : null,
          ),
          _Campo(
            builder: () => _campoTexto(
              etiquetaCampo: 'Número de licencia',
              controller: _numeroLicenciaController,
            ),
            validar: () => _numeroLicenciaController.text.trim().isEmpty
                ? 'Completa el número de tu licencia.'
                : null,
          ),
          _Campo(
            builder: () => _campoFecha(
              etiquetaCampo: 'Fecha de expiración',
              valor: _fechaExpiracionLicencia,
              inicial: DateTime.now(),
              primeraFecha: DateTime.now(),
              ultimaFecha: DateTime.now().add(const Duration(days: 365 * 20)),
              onCambiar: (f) => setState(() => _fechaExpiracionLicencia = f),
            ),
            validar: () => _fechaExpiracionLicencia == null
                ? 'Elegí la fecha de expiración de tu licencia.'
                : null,
          ),
        ];
      case _Paso.vehiculo:
        const recomendacionesVehiculo = [
          'Foto clara, sin capturas de pantalla ni fotocopias.',
          'Que se vea el vehículo completo, o el documento entero.',
        ];
        final marcas = _tipoVehiculo == 'auto' ? marcasAuto : marcasMoto;
        return [
          _Campo(
            builder: _campoTipoVehiculo,
            validar: () =>
                _tipoVehiculo == null ? 'Elegí el tipo de vehículo.' : null,
          ),
          _Campo(
            builder: () => _campoSelector(
              etiquetaCampo: 'Marca del vehículo',
              valor: _marcaVehiculo,
              onElegir: () async {
                final elegida = await mostrarSelectorConBuscador(
                  context,
                  titulo: 'Marca del vehículo',
                  opciones: marcas,
                );
                if (elegida != null) setState(() => _marcaVehiculo = elegida);
              },
            ),
            validar: () => _marcaVehiculo == null
                ? 'Elegí la marca de tu vehículo.'
                : null,
          ),
          _Campo(
            builder: () => _campoTexto(
              etiquetaCampo: 'Modelo del vehículo',
              controller: _modeloController,
            ),
            validar: () => _modeloController.text.trim().isEmpty
                ? 'Completa el modelo.'
                : null,
          ),
          _Campo(
            builder: () => _campoSelector(
              etiquetaCampo: 'Color del vehículo',
              valor: _colorVehiculo,
              onElegir: () async {
                final elegido = await mostrarSelectorColorVehiculo(context);
                if (elegido != null) setState(() => _colorVehiculo = elegido);
              },
            ),
            validar: () => _colorVehiculo == null
                ? 'Elegí el color de tu vehículo.'
                : null,
          ),
          _Campo(
            builder: () => _campoTexto(
              etiquetaCampo: 'Número de placas',
              controller: _placaController,
              capitalizacion: TextCapitalization.characters,
            ),
            validar: () => _placaController.text.trim().isEmpty
                ? 'Completa la placa.'
                : null,
          ),
          _Campo(
            builder: () => _campoTexto(
              etiquetaCampo: 'Año de manufactura',
              controller: _anioController,
              teclado: TextInputType.number,
            ),
            validar: () => int.tryParse(_anioController.text.trim()) == null
                ? 'Completa el año de fabricación.'
                : null,
          ),
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Foto del vehículo',
              tituloInstrucciones: 'Vehículo',
              icono: Icons.two_wheeler,
              recomendaciones: recomendacionesVehiculo,
              foto: _fotoVehiculo,
              onCambiar: (f) => setState(() => _fotoVehiculo = f),
            ),
            validar: () =>
                _fotoVehiculo == null ? 'Sacá una foto de tu vehículo.' : null,
          ),
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Tarjeta de circulación',
              tituloInstrucciones: 'Vehículo',
              icono: Icons.two_wheeler,
              recomendaciones: recomendacionesVehiculo,
              foto: _tarjetaCirculacion,
              onCambiar: (f) => setState(() => _tarjetaCirculacion = f),
            ),
            validar: () => _tarjetaCirculacion == null
                ? 'Sacá una foto de tu tarjeta de circulación.'
                : null,
          ),
        ];
      case _Paso.soat:
        return [
          _Campo(
            builder: () => _campoFoto(
              etiquetaCampo: 'Foto del SOAT',
              descripcion:
                  'Solo aplica en Bolivia. Si todavía no lo tenés, podés '
                  'saltar este paso y subirlo más adelante desde tu perfil.',
              tituloInstrucciones: 'SOAT',
              icono: Icons.shield_outlined,
              recomendaciones: const [
                'Foto clara, sin capturas de pantalla ni fotocopias.',
                'Que se vean todos los datos del documento.',
              ],
              foto: _soat,
              onCambiar: (f) => setState(() => _soat = f),
            ),
            validar: () => null, // Opcional, sin validación.
          ),
        ];
    }
  }

  Future<void> _avanzar() async {
    final campos = _camposDe(_pasos[_indice]);
    final error = campos[_indiceCampo].validar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    if (_indiceCampo < campos.length - 1) {
      setState(() => _indiceCampo++);
      return;
    }
    if (_indice < _pasos.length - 1) {
      setState(() {
        _indice++;
        _indiceCampo = 0;
      });
      return;
    }
    await _finalizar();
  }

  void _retroceder() {
    if (_indiceCampo > 0) {
      setState(() {
        _indiceCampo--;
        _error = null;
      });
      return;
    }
    if (_indice == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _indice--;
      _indiceCampo = _camposDe(_pasos[_indice]).length - 1;
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
          () => _error =
              'No pudimos guardar tu registro. Revisá tu '
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
    final campos = _camposDe(paso);
    final esUltimoCampoDelPaso = _indiceCampo == campos.length - 1;
    final esUltimoPaso = _indice == _pasos.length - 1;
    final etiquetaBoton = _procesando
        ? 'Guardando...'
        : !esUltimoCampoDelPaso
        ? 'Siguiente'
        : (esUltimoPaso ? 'Finalizar' : 'Continuar');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _procesando ? null : _retroceder,
        ),
        title: Text(_nombrePaso(paso)),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_indiceCampo + 1) / campos.length,
            minHeight: 4,
          ),
          Expanded(
            // Transición suave entre campos (sprint extra: "más fluido")
            // — antes el cambio de campo era un corte seco.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                key: ValueKey('$_indice-$_indiceCampo'),
                padding: const EdgeInsets.all(24),
                child: campos[_indiceCampo].builder(),
              ),
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
                child: Text(etiquetaBoton),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(texto, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget _campoTexto({
    required String etiquetaCampo,
    required TextEditingController controller,
    TextCapitalization capitalizacion = TextCapitalization.none,
    TextInputType? teclado,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo(etiquetaCampo),
        TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: etiquetaCampo),
          textCapitalization: capitalizacion,
          keyboardType: teclado,
        ),
      ],
    );
  }

  Widget _campoFecha({
    required String etiquetaCampo,
    required DateTime? valor,
    required DateTime inicial,
    required DateTime primeraFecha,
    required DateTime ultimaFecha,
    required ValueChanged<DateTime> onCambiar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo(etiquetaCampo),
        InkWell(
          onTap: () async {
            final elegida = await showDatePicker(
              context: context,
              initialDate: valor ?? inicial,
              firstDate: primeraFecha,
              lastDate: ultimaFecha,
            );
            if (elegida != null) onCambiar(elegida);
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: etiquetaCampo),
            child: Text(
              valor == null
                  ? 'dd/mm/aaaa'
                  : '${valor.day.toString().padLeft(2, '0')}/'
                        '${valor.month.toString().padLeft(2, '0')}/'
                        '${valor.year}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoSelector({
    required String etiquetaCampo,
    required String? valor,
    required VoidCallback onElegir,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo(etiquetaCampo),
        InkWell(
          onTap: onElegir,
          child: InputDecorator(
            decoration: InputDecoration(labelText: etiquetaCampo),
            child: Text(valor ?? 'Elegir'),
          ),
        ),
      ],
    );
  }

  Widget _campoTipoVehiculo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Tipo de vehículo'),
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
      ],
    );
  }

  Widget _campoFoto({
    required String etiquetaCampo,
    required String tituloInstrucciones,
    required IconData icono,
    required List<String> recomendaciones,
    required XFile? foto,
    required ValueChanged<XFile?> onCambiar,
    String? descripcion,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo(etiquetaCampo),
        if (descripcion != null) ...[
          Text(descripcion),
          const SizedBox(height: 16),
        ],
        Center(
          child: foto == null
              ? OutlinedButton.icon(
                  onPressed: () async {
                    final nueva = await mostrarInstruccionesYTomarFoto(
                      context,
                      titulo: tituloInstrucciones,
                      icono: icono,
                      recomendaciones: recomendaciones,
                    );
                    if (nueva != null) onCambiar(nueva);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Tomar foto'),
                )
              : PreviewFotoTomada(foto: foto, onRepetir: () => onCambiar(null)),
        ),
      ],
    );
  }
}
