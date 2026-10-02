import '../models/tabulador_flete.dart';

/// Cálculo del flete base (puro y testeable).
class CalculoFlete {
  const CalculoFlete._();

  /// Tier de capacidad para una capacidad en kg.
  ///
  /// Usa el tier **inmediato superior** (p. ej. 8000 kg → 10 T). Si supera
  /// 30 T, usa 30 T. Devuelve null si la capacidad es nula o <= 0.
  static TierCapacidad? tierDeCapacidadKg(double? capacidadKg) {
    if (capacidadKg == null || capacidadKg <= 0) return null;
    final toneladas = capacidadKg / 1000;
    for (final tier in TierCapacidad.values) {
      if (toneladas <= tier.toneladas + 1e-9) return tier;
    }
    return TierCapacidad.t30;
  }

  /// Precio de flete (USD) para una localidad y capacidad, o null.
  static double? precioFlete({
    required TabuladorFlete? tabulador,
    required double? capacidadKg,
  }) {
    if (tabulador == null) return null;
    final tier = tierDeCapacidadKg(capacidadKg);
    if (tier == null) return null;
    return tabulador.precioPara(tier);
  }
}
