import 'entities/envio.dart';
import 'value_objects/money.dart';

/// Sugerencia de precio para "Crear envío" (sprint extra) — valores de
/// referencia para la operación de Villazón, pensados para ajustarse con
/// el tiempo, no una tarifa oficial. Es solo informativo: el cliente
/// sigue escribiendo su propio monto ofertado, esto le da un punto de
/// partida ("si es moto: Bs X, si es auto: Bs Y") en vez de tirar un
/// número al azar.
class SugerenciaPrecio {
  const SugerenciaPrecio({required this.moto, required this.auto});
  final Money moto;
  final Money auto;
}

const _tarifaBaseMotoCentavos = 500; // Bs 5.00
const _tarifaBaseAutoCentavos = 800; // Bs 8.00
const _porKmMotoCentavos = 150; // Bs 1.50/km
const _porKmAutoCentavos = 250; // Bs 2.50/km
const _recargoFragilCentavos = 300; // Bs 3.00

int _recargoCategoriaCentavos(CategoriaPaquete categoria) => switch (categoria) {
  CategoriaPaquete.documentos => 0,
  CategoriaPaquete.paqueteChico => 0,
  CategoriaPaquete.paqueteMediano => 200, // Bs 2.00
  CategoriaPaquete.encomiendaMercado => 500, // Bs 5.00
};

/// [distanciaMetros] entra como `double` (así la devuelve
/// `Geolocator.distanceBetween`, no hay forma de evitarlo) pero nunca se
/// guarda ni se acumula — se usa una sola vez acá, se redondea al
/// centavo entero más cercano y de ahí en más todo vuelve a ser `Money`
/// sobre centavos enteros, como exige CLAUDE.md.
SugerenciaPrecio calcularPrecioSugerido({
  required double distanciaMetros,
  required CategoriaPaquete categoria,
  required bool esFragil,
}) {
  final distanciaKm = distanciaMetros / 1000;
  final recargo =
      _recargoCategoriaCentavos(categoria) +
      (esFragil ? _recargoFragilCentavos : 0);
  final moto =
      _tarifaBaseMotoCentavos +
      (distanciaKm * _porKmMotoCentavos).round() +
      recargo;
  final auto =
      _tarifaBaseAutoCentavos +
      (distanciaKm * _porKmAutoCentavos).round() +
      recargo;
  return SugerenciaPrecio(
    moto: Money.centavos(moto),
    auto: Money.centavos(auto),
  );
}
