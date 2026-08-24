/// Representa un monto en Bolivianos (BOB) como entero de centavos.
///
/// Prohibido manejar dinero como `double` (errores de redondeo de punto
/// flotante en transacciones reales). `bob` solo existe para mostrar en
/// pantalla — nunca se usa para cálculos, esos siempre operan sobre
/// [centavos].
class Money implements Comparable<Money> {
  const Money.centavos(this.centavos)
    : assert(centavos >= 0, 'Money no admite montos negativos');

  factory Money.zero() => const Money.centavos(0);

  final int centavos;

  double get bob => centavos / 100;

  String format() => 'Bs. ${bob.toStringAsFixed(2)}';

  Money operator +(Money other) => Money.centavos(centavos + other.centavos);

  Money operator -(Money other) => Money.centavos(centavos - other.centavos);

  bool operator >(Money other) => centavos > other.centavos;

  bool operator >=(Money other) => centavos >= other.centavos;

  bool operator <(Money other) => centavos < other.centavos;

  bool operator <=(Money other) => centavos <= other.centavos;

  @override
  int compareTo(Money other) => centavos.compareTo(other.centavos);

  @override
  bool operator ==(Object other) =>
      other is Money && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;

  @override
  String toString() => format();
}
