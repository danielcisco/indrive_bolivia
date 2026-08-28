/// Marcas comunes en el mercado boliviano informal de motos y autos
/// (Sprint 20) — listas hardcodeadas en vez de una base de datos real de
/// marca/modelo: alcanza para un selector con buscador, sin depender de
/// una API externa para algo que cambia poco. "Otra" siempre queda
/// disponible como texto libre para lo que no esté en la lista.
const marcasMoto = <String>[
  'Bajaj',
  'Honda',
  'Yamaha',
  'Suzuki',
  'TVS',
  'Zongshen',
  'Jialing',
  'Lifan',
  'Keeway',
  'Yingang',
  'Kenton',
  'Yumbo',
  'Yamasaki',
  'Yiben',
  'Kawasaki',
  'Wangye',
  'Motomel',
  'Senke',
  'Loncin',
  'Haojue',
  'KTM',
  'Vespa',
  'Otra',
];

const marcasAuto = <String>[
  'Toyota',
  'Nissan',
  'Chevrolet',
  'Suzuki',
  'Hyundai',
  'Kia',
  'Volkswagen',
  'Ford',
  'Mitsubishi',
  'Mazda',
  'Subaru',
  'Honda',
  'Renault',
  'Peugeot',
  'Fiat',
  'Jeep',
  'Great Wall',
  'Chery',
  'JAC',
  'BYD',
  'Otra',
];

/// Colores de vehículo (Sprint 20) — nombre + color real para el swatch
/// del selector.
const coloresVehiculo = <(String, int)>[
  ('Negro', 0xFF1A1A1A),
  ('Blanco', 0xFFF5F5F5),
  ('Azul', 0xFF1565C0),
  ('Rojo', 0xFFD32F2F),
  ('Gris', 0xFF9E9E9E),
  ('Plateado', 0xFFC0C0C0),
  ('Verde', 0xFF388E3C),
  ('Amarillo', 0xFFFBC02D),
  ('Naranja', 0xFFF57C00),
  ('Vino', 0xFF7B1F3A),
  ('Dorado', 0xFFBFA046),
  ('Café', 0xFF6D4C41),
];
