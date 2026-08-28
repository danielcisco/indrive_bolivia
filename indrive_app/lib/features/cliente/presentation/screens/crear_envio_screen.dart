import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:image_picker/image_picker.dart';

import '../../../../core/location/current_location.dart';
import '../../../../core/location/places_service.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/precio_sugerido.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/widgets/map_picker_screen.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/crear_envio_controller.dart';
import 'envio_detalle_screen.dart';

class CrearEnvioScreen extends ConsumerStatefulWidget {
  const CrearEnvioScreen({super.key});

  @override
  ConsumerState<CrearEnvioScreen> createState() => _CrearEnvioScreenState();
}

class _CrearEnvioScreenState extends ConsumerState<CrearEnvioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();

  GeoPoint? _origen;
  GeoPoint? _destino;
  String? _direccionOrigen;
  String? _direccionDestino;
  String? _errorUbicacion;
  CategoriaPaquete _categoria = CategoriaPaquete.documentos;
  bool _esFragil = false;
  XFile? _foto;

  /// Recalculada en cada build (función pura, sin costo real) una vez
  /// que hay origen y destino — mismo criterio que el resto de esta
  /// pantalla de no cachear derivados que son baratos de recalcular.
  SugerenciaPrecio? get _sugerencia {
    final origen = _origen;
    final destino = _destino;
    if (origen == null || destino == null) return null;
    final distanciaMetros = Geolocator.distanceBetween(
      origen.latitude,
      origen.longitude,
      destino.latitude,
      destino.longitude,
    );
    return calcularPrecioSugerido(
      distanciaMetros: distanciaMetros,
      categoria: _categoria,
      esFragil: _esFragil,
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  /// Intenta centrar el picker en el GPS actual; si falla (permiso
  /// denegado, GPS apagado), el picker igual abre centrado en Villazón —
  /// una lectura fallida no debe bloquear elegir la ubicación a mano.
  Future<LatLng?> _posicionInicialPara({GeoPoint? preferida}) async {
    if (preferida != null) {
      return LatLng(preferida.latitude, preferida.longitude);
    }
    try {
      final posicion = await obtenerUbicacionActual();
      return LatLng(posicion.latitude, posicion.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _elegirOrigen() async {
    setState(() => _errorUbicacion = null);
    final inicial = await _posicionInicialPara();
    if (!mounted) return;
    final resultado = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(title: 'Elegir origen', posicionInicial: inicial),
      ),
    );
    if (resultado != null && mounted) {
      setState(() {
        _origen = resultado;
        _direccionOrigen = null;
      });
      _resolverDireccion(resultado, esOrigen: true);
    }
  }

  Future<void> _elegirDestino() async {
    setState(() => _errorUbicacion = null);
    final inicial = await _posicionInicialPara(preferida: _origen);
    if (!mounted) return;
    final resultado = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'Elegir destino',
          posicionInicial: inicial,
        ),
      ),
    );
    if (resultado != null && mounted) {
      setState(() {
        _destino = resultado;
        _direccionDestino = null;
      });
      _resolverDireccion(resultado, esOrigen: false);
    }
  }

  /// Best-effort: si la geocodificación inversa falla, `_formatearPunto`
  /// cae a mostrar las coordenadas — nunca bloquea publicar el envío.
  Future<void> _resolverDireccion(GeoPoint punto, {required bool esOrigen}) async {
    final direccion = await obtenerDireccionAproximada(
      LatLng(punto.latitude, punto.longitude),
    );
    if (!mounted || direccion == null) return;
    setState(() {
      if (esOrigen) {
        _direccionOrigen = direccion;
      } else {
        _direccionDestino = direccion;
      }
    });
  }

  Future<void> _tomarFoto() async {
    // Opcional: no todas las categorías la necesitan (ej. documentos), no
    // bloquea la publicación si no hay foto.
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _enviar() async {
    final origen = _origen;
    final destino = _destino;
    if (!_formKey.currentState!.validate()) return;
    if (origen == null || destino == null) {
      setState(
        () => _errorUbicacion = 'Elige el origen y el destino en el mapa.',
      );
      return;
    }

    final monto = Money.parseBobString(_montoController.text);

    final idCreado = await ref
        .read(crearEnvioControllerProvider.notifier)
        .crear(
          descripcion: _descripcionController.text.trim(),
          origen: origen,
          destino: destino,
          montoOfertadoInicial: monto,
          categoria: _categoria,
          esFragil: _esFragil,
          foto: _foto != null ? File(_foto!.path) : null,
        );

    if (!mounted) return;
    final estado = ref.read(crearEnvioControllerProvider);
    if (estado.hasError) return;
    if (idCreado != null) {
      // Reemplaza esta pantalla por el detalle (no un push encima): así
      // "atrás" desde el detalle vuelve a "Mis envíos", no al formulario.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EnvioDetalleScreen(envioId: idCreado),
        ),
      );
    } else {
      // Se encoló offline — todavía no existe un documento al que
      // navegar, se mantiene el comportamiento de volver a la lista.
      Navigator.of(context).pop();
    }
  }

  String _formatearPunto(GeoPoint? punto, String? direccion) {
    if (punto == null) return 'sin definir';
    // Coordenadas como respaldo si la geocodificación inversa todavía no
    // resolvió o falló — nunca deja al usuario sin saber qué eligió.
    return direccion ??
        '${punto.latitude.toStringAsFixed(5)}, '
            '${punto.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(crearEnvioControllerProvider);
    ref.listen(crearEnvioControllerProvider, (previous, next) {
      if (next.hasError) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos publicar tu envío. Probá de nuevo.',
          app: 'Cliente',
          motivo: 'no puedo publicar un envío nuevo',
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Crear envío')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          // Sprint 16: retroalimentación en cuanto el usuario toca un campo
          // inválido, no solo al tocar "Publicar envío".
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              const Text(
                'Este servicio opera dentro de Villazón, Bolivia.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CategoriaPaquete>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final opcion in CategoriaPaquete.values)
                    DropdownMenuItem(
                      value: opcion,
                      child: Text(opcion.etiquetaConPeso),
                    ),
                ],
                onChanged: (opcion) {
                  if (opcion != null) setState(() => _categoria = opcion);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Envío frágil'),
                subtitle: const Text('El repartidor lo va a manejar con más cuidado.'),
                value: _esFragil,
                onChanged: (valor) => setState(() => _esFragil = valor ?? false),
              ),
              const SizedBox(height: 16),
              Text('Origen: ${_formatearPunto(_origen, _direccionOrigen)}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _elegirOrigen,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Elegir origen en el mapa'),
              ),
              const SizedBox(height: 16),
              Text('Destino: ${_formatearPunto(_destino, _direccionDestino)}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _elegirDestino,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Elegir destino en el mapa'),
              ),
              if (_errorUbicacion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorUbicacion!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_sugerencia case final sugerencia?) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio sugerido',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Referencia, no una tarifa fija — vos elegís cuánto '
                          'ofertar.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _montoController.text = sugerencia.moto
                                    .bob
                                    .toStringAsFixed(2),
                              ),
                              icon: const Icon(Icons.two_wheeler, size: 18),
                              label: Text('Moto: ${sugerencia.moto.format()}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => setState(
                                () => _montoController.text = sugerencia.auto
                                    .bob
                                    .toStringAsFixed(2),
                              ),
                              icon: const Icon(
                                Icons.directions_car,
                                size: 18,
                              ),
                              label: Text('Auto: ${sugerencia.auto.format()}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción del paquete',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto ofertado (Bs.)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Requerido';
                  try {
                    Money.parseBobString(value);
                    return null;
                  } on FormatException {
                    return 'Monto inválido';
                  }
                },
              ),
              const SizedBox(height: 24),
              const Text('Foto del paquete (opcional)'),
              const SizedBox(height: 8),
              if (_foto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_foto!.path), height: 160),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(_foto == null ? 'Tomar foto' : 'Repetir foto'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: estado.isLoading ? null : _enviar,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    estado.isLoading ? 'Enviando...' : 'Publicar envío',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
