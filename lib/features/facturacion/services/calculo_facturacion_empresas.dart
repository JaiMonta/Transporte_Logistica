import '../../fletes/models/extra.dart';

/// Peso de un producto dentro de un manifiesto (para el prorrateo).
class PesoProducto {
  const PesoProducto({
    required this.productoId,
    required this.productoNombre,
    required this.kg,
    this.empresaId,
    this.empresaNombre,
  });

  final String productoId;
  final String productoNombre;
  final double kg;
  final String? empresaId;
  final String? empresaNombre;
}

/// Concepto (extra) a prorratear por producto.
class ConceptoExtra {
  const ConceptoExtra({
    required this.concepto,
    required this.monto,
    this.tipo,
    this.descripcion,
    this.base,
    this.porcentaje,
  });

  final String concepto;
  final double monto;
  final TipoExtra? tipo;
  final String? descripcion;
  final double? base;
  final double? porcentaje;
}

/// Manifiesto listo para facturar (flete base, capacidad, pesos y extras).
class ManifiestoFacturable {
  const ManifiestoFacturable({
    required this.manifiestoId,
    required this.fleteBase,
    this.usuarioId,
    this.capacidadKg,
    this.pesos = const [],
    this.extras = const [],
  });

  final String manifiestoId;
  final String? usuarioId;
  final double fleteBase;
  final double? capacidadKg;
  final List<PesoProducto> pesos;
  final List<ConceptoExtra> extras;
}

/// Ítem de factura por empresa (ya prorrateado por producto).
class ItemFacturaEmpresa {
  const ItemFacturaEmpresa({
    required this.manifiestoId,
    required this.concepto,
    required this.monto,
    this.usuarioId,
    this.productoId,
    this.productoNombre,
    this.tipo,
    this.descripcion,
    this.base,
    this.porcentaje,
    this.kg = 0,
    this.usdPorKg,
    this.orden = 0,
  });

  final String manifiestoId;
  final String? usuarioId;
  final String? productoId;
  final String? productoNombre;
  final String concepto;
  final TipoExtra? tipo;
  final String? descripcion;
  final double? base;
  final double? porcentaje;
  final double monto;
  final double kg;
  final double? usdPorKg;
  final int orden;
}

/// Factura calculada de una empresa.
class FacturaEmpresaCalculada {
  const FacturaEmpresaCalculada({
    required this.empresaId,
    required this.empresaNombre,
    required this.items,
    required this.subtotalFlete,
    required this.subtotalExtras,
  });

  final String? empresaId;
  final String? empresaNombre;
  final List<ItemFacturaEmpresa> items;
  final double subtotalFlete;
  final double subtotalExtras;

  double get total => subtotalFlete + subtotalExtras;

  String get empresaVisible =>
      (empresaNombre?.trim().isNotEmpty ?? false)
          ? empresaNombre!.trim()
          : 'Sin empresa';
}

/// Cálculo de la facturación por empresa (puro y testeable).
///
/// * **Flete base**: `usd/kg = fleteBase ÷ capacidad`; cada producto toma
///   `usd/kg × kg` y el de **menor peso** absorbe el resto (`fleteBase − Σ`),
///   replicando la regla del Excel (`FLETE BASE − FLETE PASTAS`).
/// * **Extras** (caleta/flete secundario, reparto, desvío, …): se prorratean
///   por **kg sobre el total de carga** (`kg ÷ Σkg`), con el de menor peso
///   absorbiendo el resto (igual que el Excel, que usa `KG CARGA`).
/// * Si hay un solo producto con peso, todo el flete y los extras van a su
///   empresa.
class CalculoFacturacionEmpresas {
  const CalculoFacturacionEmpresas._();

  /// Tasa `USD/kg` a partir del flete base y la capacidad del camión.
  static double usdPorKg(double fleteBase, double? capacidad) {
    if (capacidad == null || capacidad <= 0) return 0;
    return fleteBase / capacidad;
  }

  /// Reparte [monto] entre los [pesos] según `usd/kg × kg`.
  ///
  /// El producto de **menor peso (> 0)** absorbe el resto. Devuelve una lista
  /// alineada con [pesos].
  static List<double> repartir({
    required double monto,
    required List<double> pesos,
    required double? capacidad,
  }) {
    final n = pesos.length;
    if (n == 0) return const [];

    final hayPeso = pesos.any((p) => p > 0);
    if (!hayPeso) {
      return [monto, for (var i = 1; i < n; i++) 0.0];
    }

    final usdKg = usdPorKg(monto, capacidad);
    if (usdKg <= 0) {
      // Sin capacidad no se puede prorratear: todo al de mayor peso.
      var idxMayor = 0;
      for (var i = 1; i < n; i++) {
        if (pesos[i] > pesos[idxMayor]) idxMayor = i;
      }
      return [for (var i = 0; i < n; i++) (i == idxMayor ? monto : 0.0)];
    }

    var idxMenor = -1;
    var menor = double.infinity;
    for (var i = 0; i < n; i++) {
      if (pesos[i] > 0 && pesos[i] < menor) {
        menor = pesos[i];
        idxMenor = i;
      }
    }

    final resultado = List<double>.filled(n, 0);
    var suma = 0.0;
    for (var i = 0; i < n; i++) {
      if (i == idxMenor || pesos[i] <= 0) continue;
      resultado[i] = usdKg * pesos[i];
      suma += resultado[i];
    }
    final resto = monto - suma;
    resultado[idxMenor] = resto < 0 ? 0 : resto;
    return resultado;
  }

  /// Calcula las facturas por empresa a partir de los manifiestos.
  static List<FacturaEmpresaCalculada> calcular(
    List<ManifiestoFacturable> manifiestos,
  ) {
    final acumulado = <String, _AcumEmpresa>{};

    for (final m in manifiestos) {
      // Sin pesos capturados: no se puede prorratear; todo queda "Sin empresa".
      final pesos = m.pesos.isNotEmpty
          ? m.pesos
          : const [
              PesoProducto(productoId: '', productoNombre: '', kg: 0),
            ];

      final kgs = [for (final p in pesos) p.kg];
      final totalKg = kgs.fold<double>(0, (a, b) => a + (b > 0 ? b : 0));
      final sharesFlete = repartir(
        monto: m.fleteBase,
        pesos: kgs,
        capacidad: m.capacidadKg,
      );

      final usdKg = usdPorKg(m.fleteBase, m.capacidadKg);

      void acumular({
        required int i,
        required String concepto,
        required double monto,
        required bool esFlete,
        TipoExtra? tipo,
        String? descripcion,
        double? base,
        double? porcentaje,
        double? usdPorKgItem,
      }) {
        if (monto == 0) return;
        final p = pesos[i];
        final key = p.empresaId ?? '';
        final acc = acumulado.putIfAbsent(
          key,
          () => _AcumEmpresa(
            empresaId: p.empresaId,
            empresaNombre: p.empresaNombre,
          ),
        );
        acc.items.add(ItemFacturaEmpresa(
          manifiestoId: m.manifiestoId,
          usuarioId: m.usuarioId,
          productoId: p.productoId.isEmpty ? null : p.productoId,
          productoNombre: p.productoNombre.isEmpty ? null : p.productoNombre,
          concepto: concepto,
          tipo: tipo,
          descripcion: descripcion,
          base: base,
          porcentaje: porcentaje,
          monto: monto,
          kg: p.kg,
          usdPorKg: usdPorKgItem,
          orden: esFlete ? 0 : 1,
        ));
        if (esFlete) {
          acc.subFlete += monto;
        } else {
          acc.subExtras += monto;
        }
      }

      // Flete base prorrateado por producto.
      for (var i = 0; i < pesos.length; i++) {
        acumular(
          i: i,
          concepto: 'flete',
          monto: sharesFlete[i],
          esFlete: true,
          descripcion: 'Flete base',
          base: m.fleteBase,
          usdPorKgItem: usdKg,
        );
      }

      // Extras prorrateados por kg sobre el total de carga (kg / Σkg), con el
      // producto de menor peso absorbiendo el resto (igual que el Excel).
      for (final c in m.extras) {
        final sharesExtra = repartir(
          monto: c.monto,
          pesos: kgs,
          capacidad: totalKg,
        );
        for (var i = 0; i < pesos.length; i++) {
          acumular(
            i: i,
            concepto: c.concepto,
            monto: sharesExtra[i],
            esFlete: false,
            tipo: c.tipo,
            descripcion: c.descripcion,
            base: c.base,
            porcentaje: c.porcentaje,
          );
        }
      }
    }

    final facturas = [
      for (final acc in acumulado.values) acc.aFactura(),
    ];
    facturas.sort((a, b) => a.empresaVisible.compareTo(b.empresaVisible));
    return facturas;
  }
}

class _AcumEmpresa {
  _AcumEmpresa({this.empresaId, this.empresaNombre});

  final String? empresaId;
  final String? empresaNombre;
  final List<ItemFacturaEmpresa> items = [];
  double subFlete = 0;
  double subExtras = 0;

  FacturaEmpresaCalculada aFactura() => FacturaEmpresaCalculada(
        empresaId: empresaId,
        empresaNombre: empresaNombre,
        items: items,
        subtotalFlete: subFlete,
        subtotalExtras: subExtras,
      );
}
