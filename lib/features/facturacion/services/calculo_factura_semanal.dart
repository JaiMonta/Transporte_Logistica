import '../../fletes/models/extra.dart';

/// Rango de una semana (lunes a domingo).
class SemanaRange {
  const SemanaRange({required this.inicio, required this.fin});

  /// Lunes de la semana.
  final DateTime inicio;

  /// Domingo de la semana.
  final DateTime fin;

  /// Semana (lunes→domingo) que contiene [fecha].
  factory SemanaRange.deFecha(DateTime fecha) {
    final d = DateTime(fecha.year, fecha.month, fecha.day);
    final lunes = d.subtract(Duration(days: d.weekday - DateTime.monday));
    final domingo = lunes.add(const Duration(days: 6));
    return SemanaRange(inicio: lunes, fin: domingo);
  }

  bool contiene(DateTime fecha) {
    final d = DateTime(fecha.year, fecha.month, fecha.day);
    return !d.isBefore(inicio) && !d.isAfter(fin);
  }

  /// ¿El período terminó hace más de [dias] a partir de [hoy]?
  bool vencida({required DateTime hoy, int dias = 7}) =>
      hoy.difference(fin).inDays > dias;
}

/// Datos mínimos de un manifiesto para facturar.
class ManifiestoFacturable {
  const ManifiestoFacturable({
    required this.manifiestoId,
    required this.usuarioId,
    required this.fleteBase,
    this.extras = const [],
  });

  final String manifiestoId;
  final String? usuarioId;
  final double fleteBase;
  final List<Extra> extras;
}

/// Ítem calculado de factura (antes de persistir).
class ItemFacturaCalculado {
  const ItemFacturaCalculado({
    required this.manifiestoId,
    required this.usuarioId,
    required this.concepto,
    required this.monto,
    this.tipo,
    this.descripcion,
    this.base,
    this.porcentaje,
    this.orden = 0,
  });

  final String manifiestoId;
  final String? usuarioId;
  final String concepto;
  final double monto;
  final TipoExtra? tipo;
  final String? descripcion;
  final double? base;
  final double? porcentaje;
  final int orden;
}

/// Totales de una factura calculada.
class ResumenFactura {
  const ResumenFactura({
    required this.items,
    required this.subtotalFlete,
    required this.subtotalExtras,
    required this.total,
    required this.porChofer,
  });

  final List<ItemFacturaCalculado> items;
  final double subtotalFlete;
  final double subtotalExtras;
  final double total;
  final Map<String, double> porChofer;
}

/// Cálculo de la factura semanal (puro y testeable).
class CalculoFacturaSemanal {
  const CalculoFacturaSemanal._();

  /// Construye los ítems y totales a partir de los manifiestos facturables.
  ///
  /// Solo se incluyen los extras en estado `aprobado`.
  static ResumenFactura calcular(List<ManifiestoFacturable> manifiestos) {
    final items = <ItemFacturaCalculado>[];
    var subtotalFlete = 0.0;
    var subtotalExtras = 0.0;
    final porChofer = <String, double>{};

    for (final m in manifiestos) {
      // Ítem de flete base.
      items.add(ItemFacturaCalculado(
        manifiestoId: m.manifiestoId,
        usuarioId: m.usuarioId,
        concepto: 'flete',
        descripcion: 'Flete base',
        monto: m.fleteBase,
        base: m.fleteBase,
        orden: 0,
      ));
      subtotalFlete += m.fleteBase;

      // Extras aprobados.
      for (final e in m.extras) {
        if (e.estado != EstadoExtra.aprobado) continue;
        items.add(ItemFacturaCalculado(
          manifiestoId: m.manifiestoId,
          usuarioId: m.usuarioId,
          concepto: e.tipo.valor,
          tipo: e.tipo,
          descripcion: e.descripcion,
          monto: e.monto,
          base: e.base,
          porcentaje: e.porcentaje,
          orden: 1,
        ));
        subtotalExtras += e.monto;
      }
    }

    for (final it in items) {
      final k = it.usuarioId ?? 'sin-chofer';
      porChofer[k] = (porChofer[k] ?? 0) + it.monto;
    }

    return ResumenFactura(
      items: items,
      subtotalFlete: subtotalFlete,
      subtotalExtras: subtotalExtras,
      total: subtotalFlete + subtotalExtras,
      porChofer: porChofer,
    );
  }
}
