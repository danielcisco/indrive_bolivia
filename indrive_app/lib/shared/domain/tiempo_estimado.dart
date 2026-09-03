/// Tiempo estimado de entrega para "Crear envío" — mismo criterio que
/// `precio_sugerido.dart`: valores de referencia para Villazón, no una
/// promesa exacta (tráfico, clima y la ruta real pueden variar el
/// resultado). Informativo, junto al precio sugerido.
class TiempoEstimado {
  const TiempoEstimado({required this.moto, required this.auto});
  final Duration moto;
  final Duration auto;
}

const _velocidadPromedioMotoKmh = 25;
const _velocidadPromedioAutoKmh = 20;
const _minutosPreparacion = 5; // arranque + recogida, no solo el viaje

/// [distanciaMetros] entra como `double` por el mismo motivo que en
/// `calcularPrecioSugerido` (así la devuelve `Geolocator.distanceBetween`)
/// pero se usa una sola vez acá — el resultado es `Duration`, no un valor
/// monetario, así que la regla de "nunca `double` para dinero" de
/// CLAUDE.md ni siquiera aplica, pero se mantiene el mismo cuidado de no
/// arrastrar el `double` más allá de este cálculo puntual.
TiempoEstimado calcularTiempoEstimado({required double distanciaMetros}) {
  final distanciaKm = distanciaMetros / 1000;
  Duration paraVelocidad(int kmh) => Duration(
    minutes: _minutosPreparacion + (distanciaKm / kmh * 60).round(),
  );
  return TiempoEstimado(
    moto: paraVelocidad(_velocidadPromedioMotoKmh),
    auto: paraVelocidad(_velocidadPromedioAutoKmh),
  );
}

String formatearDuracion(Duration d) {
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}
