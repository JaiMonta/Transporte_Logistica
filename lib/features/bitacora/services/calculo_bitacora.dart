import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/services/calculo_flete.dart';
import '../models/bitacora.dart';

/// Cálculo y agrupación de la Bitácora (puro y testeable).
class CalculoBitacora {
  const CalculoBitacora._();

  /// Región de una localidad según el tabulador (o null).
  static String? regionDe(
    String? localidad,
    Map<String, TabuladorFlete> tabulador,
  ) {
    final fila = _fila(localidad, tabulador);
    return fila?.region;
  }

  /// Flete base del manifiesto: usa la **localidad más lejana** desde la sede
  /// (la marcada `esMasLejana`, o la de mayor km) × capacidad del camión.
  ///
  /// Si no hay localidad en el tabulador, devuelve [costoFleteGuardado].
  static double? fleteBaseDeEntregas({
    required List<EntregaBitacora> entregas,
    required double? capacidadKg,
    required Map<String, TabuladorFlete> tabulador,
    double? costoFleteGuardado,
  }) {
    TabuladorFlete? masLejana;
    for (final e in entregas) {
      if (!e.esMasLejana) continue;
      final fila = _fila(e.destino, tabulador);
      if (fila != null) {
        masLejana = fila;
        break;
      }
    }
    if (masLejana == null) {
      for (final e in entregas) {
        final fila = _fila(e.destino, tabulador);
        if (fila == null) continue;
        if (masLejana == null || (fila.km ?? 0) > (masLejana.km ?? 0)) {
          masLejana = fila;
        }
      }
    }
    if (masLejana != null) {
      final precio = CalculoFlete.precioFlete(
        tabulador: masLejana,
        capacidadKg: capacidadKg,
      );
      if (precio != null) return precio;
    }
    return costoFleteGuardado;
  }

  /// Agrupa los manifiestos por día (ascendente).
  static BitacoraResumen agrupar({
    required DateTime desde,
    required DateTime hasta,
    required List<ManifiestoBitacora> manifiestos,
  }) {
    final porDia = <int, List<ManifiestoBitacora>>{};
    final fechas = <int, DateTime>{};
    for (final m in manifiestos) {
      final d = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      final clave = d.year * 10000 + d.month * 100 + d.day;
      fechas[clave] = d;
      porDia.putIfAbsent(clave, () => []).add(m);
    }
    final claves = porDia.keys.toList()..sort();
    return BitacoraResumen(
      desde: desde,
      hasta: hasta,
      dias: [
        for (final k in claves)
          DiaBitacora(fecha: fechas[k]!, manifiestos: porDia[k]!),
      ],
    );
  }

  static TabuladorFlete? _fila(
    String? localidad,
    Map<String, TabuladorFlete> tabulador,
  ) {
    final loc = localidad?.trim().toUpperCase();
    if (loc == null || loc.isEmpty) return null;
    return tabulador[loc];
  }
}
