import 'dart:math' as math;

/// Estado de la jornada de combustible.
enum EstadoCombustible {
  iniciada,
  enRecorrido,
  cerrada,
  validada;

  static EstadoCombustible desde(String? valor) =>
      EstadoCombustible.values.firstWhere(
        (e) => e.name == valor,
        orElse: () => EstadoCombustible.iniciada,
      );

  String get valor => name;

  String get etiqueta => switch (this) {
        EstadoCombustible.iniciada => 'Iniciada',
        EstadoCombustible.enRecorrido => 'En recorrido',
        EstadoCombustible.cerrada => 'Cerrada',
        EstadoCombustible.validada => 'Validada',
      };
}

/// Recarga de combustible de una jornada.
class CombustibleRecarga {
  const CombustibleRecarga({
    required this.id,
    required this.jornadaId,
    required this.litros,
    this.monto,
    this.bucket,
    this.path,
    this.registradaEn,
  });

  final String id;
  final String jornadaId;
  final double litros;
  final double? monto;
  final String? bucket;
  final String? path;
  final DateTime? registradaEn;

  factory CombustibleRecarga.fromMap(Map<String, dynamic> m) =>
      CombustibleRecarga(
        id: m['id'] as String,
        jornadaId: m['jornada_id'] as String,
        litros: _d(m['litros']) ?? 0,
        monto: _d(m['monto']),
        bucket: m['bucket'] as String?,
        path: m['path'] as String?,
        registradaEn: _f(m['registrada_en']),
      );

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _f(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}

/// Jornada de combustible por manifiesto (tabla `combustible_jornadas`).
class CombustibleJornada {
  const CombustibleJornada({
    required this.id,
    required this.manifiestoId,
    required this.usuarioId,
    this.litrosIniciales,
    this.litrosInicialesValidados,
    this.odometroInicial,
    this.odometroFinal,
    this.litrosFinales,
    this.litrosFinalesValidados,
    this.kmRecorridos,
    this.consumoTeoricoLt,
    this.consumoRealLt,
    this.rendimientoLtKm,
    this.estado = EstadoCombustible.iniciada,
    this.iniciadaEn,
    this.cerradaEn,
    this.notas,
    this.recargas = const [],
  });

  final String id;
  final String manifiestoId;
  final String usuarioId;
  final double? litrosIniciales;
  final double? litrosInicialesValidados;
  final double? odometroInicial;
  final double? odometroFinal;
  final double? litrosFinales;
  final double? litrosFinalesValidados;
  final double? kmRecorridos;
  final double? consumoTeoricoLt;
  final double? consumoRealLt;
  final double? rendimientoLtKm;
  final EstadoCombustible estado;
  final DateTime? iniciadaEn;
  final DateTime? cerradaEn;
  final String? notas;
  final List<CombustibleRecarga> recargas;

  /// Litros iniciales a usar (validados si existen, si no los reportados).
  double? get inicialEfectivo =>
      litrosInicialesValidados ?? litrosIniciales;

  double? get finalEfectivo => litrosFinalesValidados ?? litrosFinales;

  double get totalRecargasLt =>
      recargas.fold(0.0, (a, r) => a + r.litros);

  factory CombustibleJornada.fromMap(Map<String, dynamic> m) {
    final recargasMap = m['combustible_recargas'];
    final recargas = <CombustibleRecarga>[];
    if (recargasMap is List) {
      for (final r in recargasMap) {
        if (r is Map) {
          recargas
              .add(CombustibleRecarga.fromMap(Map<String, dynamic>.from(r)));
        }
      }
    }
    return CombustibleJornada(
      id: m['id'] as String,
      manifiestoId: m['manifiesto_id'] as String,
      usuarioId: m['usuario_id'] as String,
      litrosIniciales: _d(m['litros_iniciales']),
      litrosInicialesValidados: _d(m['litros_iniciales_validados']),
      odometroInicial: _d(m['odometro_inicial']),
      odometroFinal: _d(m['odometro_final']),
      litrosFinales: _d(m['litros_finales']),
      litrosFinalesValidados: _d(m['litros_finales_validados']),
      kmRecorridos: _d(m['km_recorridos']),
      consumoTeoricoLt: _d(m['consumo_teorico_lt']),
      consumoRealLt: _d(m['consumo_real_lt']),
      rendimientoLtKm: _d(m['rendimiento_lt_km']),
      estado: EstadoCombustible.desde(m['estado'] as String?),
      iniciadaEn: _f(m['iniciada_en']),
      cerradaEn: _f(m['cerrada_en']),
      notas: m['notas'] as String?,
      recargas: recargas,
    );
  }

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _f(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}

/// CÃ¡lculo de kilÃ³metros y consumo (puro y testeable).
class CalculoCombustible {
  const CalculoCombustible._();

  /// Rendimiento por defecto en litros por kilÃ³metro.
  static const double rendimientoPorDefecto = 0.32;

  /// Distancia en km entre dos coordenadas (fÃ³rmula de Haversine).
  static double distanciaKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const radioTierra = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radioTierra * c;
  }

  /// Suma de distancias entre puntos consecutivos.
  static double kmDeRuta(List<({double lat, double lng})> puntos) {
    if (puntos.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < puntos.length; i++) {
      total += distanciaKm(
        puntos[i - 1].lat,
        puntos[i - 1].lng,
        puntos[i].lat,
        puntos[i].lng,
      );
    }
    return total;
  }

  /// Consumo teÃ³rico: km Ã— rendimiento.
  static double consumoTeorico(
    double km, {
    double rendimiento = rendimientoPorDefecto,
  }) =>
      km * rendimiento;

  /// Consumo real: litros iniciales + recargas âˆ’ litros finales.
  static double consumoReal({
    required double litrosIniciales,
    required double recargas,
    required double litrosFinales,
  }) =>
      litrosIniciales + recargas - litrosFinales;

  static double _rad(double grados) => grados * math.pi / 180;
}
