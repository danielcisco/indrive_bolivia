import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Sugerencia de lugar devuelta por el autocompletado.
class SugerenciaLugar {
  const SugerenciaLugar({required this.placeId, required this.texto});

  final String placeId;
  final String texto;
}

/// Buscador de direcciones (Places API New) para el picker de mapa del
/// Cliente. Llamadas REST directas — sin paquete de terceros — usando la
/// misma key Android que ya usa el SDK nativo de Maps (Sprint 4.1a). Una
/// llamada REST manual no adjunta automáticamente el contexto de la app
/// como sí lo hace el SDK, así que hay que declarar el paquete y el SHA-1
/// a mano vía headers para que la restricción de la key los acepte.
///
/// Prerrequisito manual (Google Cloud Console, proyecto
/// indrive-entregas-villazon): habilitar "Places API (New)" y agregarla a
/// la lista de APIs permitidas de esta misma key Android.
const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
const _androidPackage = 'bo.villazon.indriveentregas.cliente';
const _androidCert = 'da8984a68c7afa852790e4d3fc52c7c78e589ff1';

// Villazón, Potosí — mismo centro que usa MapPickerScreen como fallback.
const _centroVillazon = LatLng(-22.0864, -65.5946);
const _radioSesgoMetros = 50000.0;

Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  'X-Goog-Api-Key': _mapsApiKey,
  'X-Android-Package': _androidPackage,
  'X-Android-Cert': _androidCert,
};

/// Busca sugerencias de lugares para [query], sesgadas hacia Villazón.
Future<List<SugerenciaLugar>> buscarSugerencias(String query) async {
  if (_mapsApiKey.isEmpty) {
    throw StateError(
      'Falta MAPS_API_KEY: corre la app con '
      '--dart-define=MAPS_API_KEY=<tu-key> para buscar direcciones.',
    );
  }
  final respuesta = await http.post(
    Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
    headers: _headers,
    body: jsonEncode({
      'input': query,
      'regionCode': 'BO',
      'locationBias': {
        'circle': {
          'center': {
            'latitude': _centroVillazon.latitude,
            'longitude': _centroVillazon.longitude,
          },
          'radius': _radioSesgoMetros,
        },
      },
    }),
  );

  if (respuesta.statusCode != 200) {
    throw StateError('No se pudo buscar direcciones (${respuesta.statusCode}).');
  }

  final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
  final sugerencias = cuerpo['suggestions'] as List<dynamic>? ?? [];
  return sugerencias
      .map((s) => s['placePrediction'] as Map<String, dynamic>)
      .map(
        (p) => SugerenciaLugar(
          placeId: p['placeId'] as String,
          texto: (p['text'] as Map<String, dynamic>)['text'] as String,
        ),
      )
      .toList();
}

/// Obtiene las coordenadas del lugar [placeId] elegido por el usuario.
Future<LatLng> obtenerCoordenadas(String placeId) async {
  final respuesta = await http.get(
    Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
    headers: {..._headers, 'X-Goog-FieldMask': 'location'},
  );

  if (respuesta.statusCode != 200) {
    throw StateError(
      'No se pudo obtener la ubicación del lugar (${respuesta.statusCode}).',
    );
  }

  final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
  final ubicacion = cuerpo['location'] as Map<String, dynamic>;
  return LatLng(
    (ubicacion['latitude'] as num).toDouble(),
    (ubicacion['longitude'] as num).toDouble(),
  );
}
