import 'dart:math' as math;

import '../models/extra.dart';

/// Parámetros configurables del motor de extras (con valores por defecto).
class ParametrosExtras {
  const ParametrosExtras({
    this.radioRepartoKm = 10,
    this.desvioUsdHasta3t = 6,
    this.desvioUsdHasta6t = 12,
    this.desvioPctMayor6t = 20,
    this.retornoPctParcial = 15,
    this.retornoPctCompleta = 60,
    this.finSemanaPct = 5,
    this.pickingUsd = 119,
  });

  final double radioRepartoKm;
  final double desvioUsdHasta3t;
  final double desvioUsdHasta6t;
  final double desvioPctMayor6t;
  final double retornoPctParcial;
  final double retornoPctCompleta;
  final double finSemanaPct;
  final double pickingUsd;
}

/// Un punto para el clustering de repartos.
class PuntoEntrega {
  const PuntoEntrega({required this.id, this.lat, this.lng});

  final String id;
  final double? lat;
  final double? lng;

  bool get tieneUbicacion => lat != null && lng != null;
}

/// Cálculo puro de los extras de un manifiesto.
class CalculoExtras {
  const CalculoExtras._();

  /// Distancia en km entre dos coordenadas (Haversine).
  static double distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Número de repartos: agrupa clientes a <= [radioKm] entre sí (un grupo
  /// = 1 reparto); los clientes sin ubicación cuentan como repartos propios.
  static int repartos(List<PuntoEntrega> puntos, {double radioKm = 10}) {
    final conUbicacion = puntos.where((p) => p.tieneUbicacion).toList();
    final sinUbicacion = puntos.length - conUbicacion.length;

    final visitados = <int>{};
    var grupos = 0;
    for (var i = 0; i < conUbicacion.length; i++) {
      if (visitados.contains(i)) continue;
      grupos++;
      // BFS: agrupa los que estén dentro del radio del primer punto.
      final cola = <int>[i];
      visitados.add(i);
      while (cola.isNotEmpty) {
        final actual = cola.removeLast();
        for (var j = 0; j < conUbicacion.length; j++) {
          if (visitados.contains(j)) continue;
          final d = distanciaKm(
            conUbicacion[actual].lat!,
            conUbicacion[actual].lng!,
            conUbicacion[j].lat!,
            conUbicacion[j].lng!,
          );
          if (d <= radioKm) {
            visitados.add(j);
            cola.add(j);
          }
        }
      }
    }
    return grupos + sinUbicacion;
  }

  /// Monto del desvío por cantidad de entregas en "otra localidad" y capacidad.
  static double desvio(
    double? capacidadKg,
    double fleteBase,
    int cantidad, {
    ParametrosExtras p = const ParametrosExtras(),
  }) {
    if (cantidad <= 0) return 0;
    final toneladas = (capacidadKg ?? 0) / 1000;
    double unitario;
    if (toneladas > 6) {
      unitario = fleteBase * (p.desvioPctMayor6t / 100);
    } else if (toneladas > 3) {
      unitario = p.desvioUsdHasta6t;
    } else {
      unitario = p.desvioUsdHasta3t;
    }
    return unitario * cantidad;
  }

  /// Retorno por devolución.
  static double retorno(
    double fleteBase, {
    required bool completa,
    ParametrosExtras p = const ParametrosExtras(),
  }) =>
      fleteBase *
      ((completa ? p.retornoPctCompleta : p.retornoPctParcial) / 100);

  /// Recargo de fin de semana.
  static double finDeSemana(
    double fleteBase, {
    ParametrosExtras p = const ParametrosExtras(),
  }) =>
      fleteBase * (p.finSemanaPct / 100);

  /// Total de caleta: 2 × tarifa por manifiesto.
  static double caleta(double tarifaPorCapacidad) => tarifaPorCapacidad * 2;

  /// Localidad del tabulador más cercana a un punto (por coordenadas).
  ///
  /// Devuelve null si no hay localidades con coordenadas o el punto no tiene.
  static LocalidadPunto? localidadMasCercana(
    double? lat,
    double? lng,
    List<LocalidadPunto> localidades,
  ) {
    if (lat == null || lng == null) return null;
    LocalidadPunto? mejor;
    var mejorDist = double.infinity;
    for (final l in localidades) {
      if (!l.tieneUbicacion) continue;
      final d = distanciaKm(lat, lng, l.lat!, l.lng!);
      if (d < mejorDist) {
        mejorDist = d;
        mejor = l;
      }
    }
    return mejor;
  }

  /// Localidad más lejana al origen configurable, dada una lista de localidades
  /// de las entregas. Devuelve null si no hay ninguna con coordenadas.
  static LocalidadPunto? localidadMasLejana(
    List<LocalidadPunto> localidades, {
    required double origenLat,
    required double origenLng,
  }) {
    LocalidadPunto? mejor;
    var mejorDist = -1.0;
    for (final l in localidades) {
      if (!l.tieneUbicacion) continue;
      final d = distanciaKm(origenLat, origenLng, l.lat!, l.lng!);
      if (d > mejorDist) {
        mejorDist = d;
        mejor = l;
      }
    }
    return mejor;
  }

  static double _rad(double grados) => grados * math.pi / 180;
}

/// Localidad del tabulador con coordenadas (para proximidad/lejanía).
class LocalidadPunto {
  const LocalidadPunto({
    required this.id,
    required this.localidad,
    this.lat,
    this.lng,
  });

  final String id;
  final String localidad;
  final double? lat;
  final double? lng;

  bool get tieneUbicacion => lat != null && lng != null;
}

/// Borrador de extra calculado (antes de aprobación).
class ExtraCalculado {
  const ExtraCalculado({
    required this.tipo,
    required this.descripcion,
    required this.monto,
    this.base,
    this.porcentaje,
  });

  final TipoExtra tipo;
  final String descripcion;
  final double monto;
  final double? base;
  final double? porcentaje;
}
