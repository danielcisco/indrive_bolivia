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

// Tarifa por tramos de distancia (ajuste de precios, sprint Villazón) — el
// taxi/radio taxi local cobra un monto fijo (Bs 6 en la ciudad, Bs 8 a
// lugares lejanos) sin importar la distancia real. Villazón es una ciudad
// chica y angosta (frontera con La Quiaca): la inmensa mayoría de los
// mandados son cortos, de pocas cuadras, y muy pocos cruzan la ciudad
// entera. Un único Bs/km lineal trataba igual el primer kilómetro (el que
// decide si el cliente usa el servicio) que el quinto, y el auto ya
// arrancaba en el precio "lejos" del taxi antes de sumar un solo metro.
// Estos tramos arrancan por debajo del taxi para distancias cortas y
// recién suben fuerte cuando el envío realmente cruza la ciudad.
const _umbralCercaM = 600.0; // ~5-6 cuadras
const _umbralMediaM = 1500.0;
const _umbralLejosM = 3000.0; // Villazón se cruza de punta a punta en este orden

class _TarifaPorTramos {
  const _TarifaPorTramos({
    required this.baseCercaCentavos,
    required this.porKmMediaCentavos,
    required this.porKmLejosCentavos,
    required this.porKmPeriferiaCentavos,
  });

  final int baseCercaCentavos; // tramo 0 – 600 m, flat
  final int porKmMediaCentavos; // tramo 600 m – 1.5 km
  final int porKmLejosCentavos; // tramo 1.5 – 3 km
  final int porKmPeriferiaCentavos; // más de 3 km (periferia/accesos)

  int calcular(double distanciaMetros) {
    var costo = baseCercaCentavos;
    if (distanciaMetros <= _umbralCercaM) return costo;

    final finMedia = distanciaMetros < _umbralMediaM
        ? distanciaMetros
        : _umbralMediaM;
    costo += ((finMedia - _umbralCercaM) / 1000 * porKmMediaCentavos).round();
    if (distanciaMetros <= _umbralMediaM) return costo;

    final finLejos = distanciaMetros < _umbralLejosM
        ? distanciaMetros
        : _umbralLejosM;
    costo += ((finLejos - _umbralMediaM) / 1000 * porKmLejosCentavos).round();
    if (distanciaMetros <= _umbralLejosM) return costo;

    costo +=
        ((distanciaMetros - _umbralLejosM) / 1000 * porKmPeriferiaCentavos)
            .round();
    return costo;
  }
}

const _tarifaMoto = _TarifaPorTramos(
  baseCercaCentavos: 400, // Bs 4.00 — más barato que el taxi para mandados cortos
  porKmMediaCentavos: 120, // Bs 1.20/km
  porKmLejosCentavos: 160, // Bs 1.60/km
  porKmPeriferiaCentavos: 200, // Bs 2.00/km
);

const _tarifaAuto = _TarifaPorTramos(
  baseCercaCentavos: 600, // Bs 6.00
  porKmMediaCentavos: 180, // Bs 1.80/km
  porKmLejosCentavos: 220, // Bs 2.20/km
  porKmPeriferiaCentavos: 260, // Bs 2.60/km
);

const _recargoFragilCentavos = 150; // Bs 1.50

int _recargoCategoriaCentavos(CategoriaPaquete categoria) => switch (categoria) {
  CategoriaPaquete.documentos => 0,
  CategoriaPaquete.paqueteChico => 0,
  CategoriaPaquete.paqueteMediano => 100, // Bs 1.00
  CategoriaPaquete.encomiendaMercado => 250, // Bs 2.50
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
  final recargo =
      _recargoCategoriaCentavos(categoria) +
      (esFragil ? _recargoFragilCentavos : 0);
  return SugerenciaPrecio(
    moto: Money.centavos(_tarifaMoto.calcular(distanciaMetros) + recargo),
    auto: Money.centavos(_tarifaAuto.calcular(distanciaMetros) + recargo),
  );
}
