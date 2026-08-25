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

  /// Parsea un monto en bolivianos escrito por el usuario (ej. "15.5",
  /// "15,50") a centavos, sin pasar nunca por `double` — evita el riesgo
  /// de imprecisión de punto flotante incluso en la conversión del input.
  factory Money.parseBobString(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      throw const FormatException('Monto vacío');
    }
    final parts = normalized.split('.');
    if (parts.length > 2) {
      throw FormatException('Formato de monto inválido: $input');
    }
    final integerPart = parts.first.isEmpty ? '0' : parts.first;
    final fractionPart = (parts.length == 2 ? parts[1] : '').padRight(2, '0');
    if (fractionPart.length > 2) {
      throw FormatException('Máximo 2 decimales: $input');
    }
    final centavos = int.parse(integerPart) * 100 + int.parse(fractionPart);
    return Money.centavos(centavos);
  }

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
