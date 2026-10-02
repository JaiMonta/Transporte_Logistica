/// Tier de capacidad (toneladas) del tabulador de fletes.
enum TierCapacidad {
  t1_2(1.2, '1,2 T'),
  t2_5(2.5, '2,5 T'),
  t3_5(3.5, '3,5 T'),
  t5(5, '5 T'),
  t6(6, '6 T'),
  t7_5(7.5, '7,5 T'),
  t10(10, '10 T'),
  t12(12, '12 T'),
  t15(15, '15 T'),
  t30(30, '30 T');

  const TierCapacidad(this.toneladas, this.etiqueta);

  final double toneladas;
  final String etiqueta;
}

/// Fila del tabulador de fletes (una localidad con sus precios por tier).
class TabuladorFlete {
  const TabuladorFlete({
    required this.id,
    required this.localidad,
    this.region,
    this.km,
    this.precio1_2,
    this.precio2_5,
    this.precio3_5,
    this.precio5,
    this.precio6,
    this.precio7_5,
    this.precio10,
    this.precio12,
    this.precio15,
    this.precio30,
  });

  final String id;
  final String localidad;
  final String? region;
  final double? km;
  final double? precio1_2;
  final double? precio2_5;
  final double? precio3_5;
  final double? precio5;
  final double? precio6;
  final double? precio7_5;
  final double? precio10;
  final double? precio12;
  final double? precio15;
  final double? precio30;

  String get localidadVisible =>
      localidad.trim().isNotEmpty ? localidad.trim() : 'Sin localidad';

  /// Precio (USD) para un tier de capacidad, o null si no está definido.
  double? precioPara(TierCapacidad tier) => switch (tier) {
        TierCapacidad.t1_2 => precio1_2,
        TierCapacidad.t2_5 => precio2_5,
        TierCapacidad.t3_5 => precio3_5,
        TierCapacidad.t5 => precio5,
        TierCapacidad.t6 => precio6,
        TierCapacidad.t7_5 => precio7_5,
        TierCapacidad.t10 => precio10,
        TierCapacidad.t12 => precio12,
        TierCapacidad.t15 => precio15,
        TierCapacidad.t30 => precio30,
      };

  /// Cuerpo para insert/update (admin).
  Map<String, dynamic> aCuerpo() => {
        'region': region,
        'localidad': localidad.trim(),
        'km': km,
        'precio_1_2': precio1_2,
        'precio_2_5': precio2_5,
        'precio_3_5': precio3_5,
        'precio_5': precio5,
        'precio_6': precio6,
        'precio_7_5': precio7_5,
        'precio_10': precio10,
        'precio_12': precio12,
        'precio_15': precio15,
        'precio_30': precio30,
      };

  factory TabuladorFlete.fromMap(Map<String, dynamic> m) => TabuladorFlete(
        id: m['id'] as String,
        localidad: (m['localidad'] as String?) ?? '',
        region: m['region'] as String?,
        km: _d(m['km']),
        precio1_2: _d(m['precio_1_2']),
        precio2_5: _d(m['precio_2_5']),
        precio3_5: _d(m['precio_3_5']),
        precio5: _d(m['precio_5']),
        precio6: _d(m['precio_6']),
        precio7_5: _d(m['precio_7_5']),
        precio10: _d(m['precio_10']),
        precio12: _d(m['precio_12']),
        precio15: _d(m['precio_15']),
        precio30: _d(m['precio_30']),
      );

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
