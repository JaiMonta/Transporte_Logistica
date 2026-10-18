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
