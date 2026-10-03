import 'package:app_logistica/features/facturacion/services/calculo_factura_semanal.dart';
import 'package:app_logistica/features/fletes/models/extra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SemanaRange', () {
    test('deFecha devuelve lunes a domingo', () {
      // 2026-10-07 es miércoles.
      final s = SemanaRange.deFecha(DateTime(2026, 10, 7));
      expect(s.inicio.weekday, DateTime.monday);
      expect(s.fin.weekday, DateTime.sunday);
      expect(s.inicio, DateTime(2026, 10, 5));
      expect(s.fin, DateTime(2026, 10, 11));
    });

    test('contiene', () {
      final s = SemanaRange.deFecha(DateTime(2026, 10, 7));
      expect(s.contiene(DateTime(2026, 10, 5)), isTrue);
      expect(s.contiene(DateTime(2026, 10, 11)), isTrue);
      expect(s.contiene(DateTime(2026, 10, 12)), isFalse);
      expect(s.contiene(DateTime(2026, 10, 4)), isFalse);
    });

    test('vencida tras 7 días', () {
      final s = SemanaRange.deFecha(DateTime(2026, 10, 7));
      expect(s.vencida(hoy: DateTime(2026, 10, 20)), isTrue);
      expect(s.vencida(hoy: DateTime(2026, 10, 12)), isFalse);
    });
  });

  group('CalculoFacturaSemanal', () {
    test('suma flete base y extras aprobados, ignora no aprobados', () {
      final resumen = CalculoFacturaSemanal.calcular([
        ManifiestoFacturable(
          manifiestoId: 'm1',
          usuarioId: 'u1',
          fleteBase: 191.77,
          extras: const [
            Extra(
              id: 'e1',
              manifiestoId: 'm1',
              tipo: TipoExtra.caleta,
              monto: 30,
              estado: EstadoExtra.aprobado,
            ),
            Extra(
              id: 'e2',
              manifiestoId: 'm1',
              tipo: TipoExtra.desvio,
              monto: 12,
              estado: EstadoExtra.sugerido,
            ),
          ],
        ),
      ]);
      expect(resumen.subtotalFlete, 191.77);
      expect(resumen.subtotalExtras, 30);
      expect(resumen.total, closeTo(221.77, 0.001));
      expect(resumen.items.length, 2); // flete + caleta
      expect(resumen.porChofer['u1'], closeTo(221.77, 0.001));
    });

    test('agrupa total por chofer', () {
      final resumen = CalculoFacturaSemanal.calcular([
        const ManifiestoFacturable(
            manifiestoId: 'm1', usuarioId: 'u1', fleteBase: 100),
        const ManifiestoFacturable(
            manifiestoId: 'm2', usuarioId: 'u2', fleteBase: 200),
        const ManifiestoFacturable(
            manifiestoId: 'm3', usuarioId: 'u1', fleteBase: 50),
      ]);
      expect(resumen.porChofer['u1'], 150);
      expect(resumen.porChofer['u2'], 200);
      expect(resumen.total, 350);
    });

    test('sin manifiestos da ceros', () {
      final resumen = CalculoFacturaSemanal.calcular(const []);
      expect(resumen.total, 0);
      expect(resumen.items, isEmpty);
    });
  });
}
