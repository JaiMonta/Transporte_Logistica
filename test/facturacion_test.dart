import 'package:app_logistica/features/facturacion/services/calculo_facturacion_empresas.dart';
import 'package:app_logistica/features/facturacion/services/semana_range.dart';
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

  group('CalculoFacturacionEmpresas.repartir', () {
    test('camión lleno: cada producto su kg', () {
      final r = CalculoFacturacionEmpresas.repartir(
        monto: 100,
        pesos: [60, 40],
        capacidad: 100,
      );
      expect(r[0], closeTo(60, 0.001));
      expect(r[1], closeTo(40, 0.001));
    });

    test('camión no lleno: el de menor peso absorbe el resto', () {
      final r = CalculoFacturacionEmpresas.repartir(
        monto: 100,
        pesos: [60, 40],
        capacidad: 200,
      );
      expect(r[0], closeTo(30, 0.001));
      expect(r[1], closeTo(70, 0.001));
      expect(r[0] + r[1], closeTo(100, 0.001));
    });

    test('sin capacidad: todo al de mayor peso', () {
      final r = CalculoFacturacionEmpresas.repartir(
        monto: 100,
        pesos: [60, 40],
        capacidad: null,
      );
      expect(r[0], closeTo(100, 0.001));
      expect(r[1], 0);
    });
  });

  group('CalculoFacturacionEmpresas.calcular', () {
    test('un solo producto: todo a su empresa', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        ManifiestoFacturable(
          manifiestoId: 'm1',
          fleteBase: 100,
          capacidadKg: 1000,
          pesos: const [
            PesoProducto(
              productoId: 'p1',
              productoNombre: 'Pasta',
              kg: 800,
              empresaId: 'e1',
              empresaNombre: 'Empresa Uno',
            ),
          ],
          extras: const [
            ConceptoExtra(concepto: 'caleta', monto: 20, tipo: TipoExtra.caleta),
          ],
        ),
      ]);
      expect(facturas.length, 1);
      expect(facturas.first.empresaId, 'e1');
      expect(facturas.first.subtotalFlete, closeTo(100, 0.001));
      expect(facturas.first.subtotalExtras, closeTo(20, 0.001));
      expect(facturas.first.total, closeTo(120, 0.001));
    });

    test('prorratea flete y extras entre empresas (camión lleno)', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        ManifiestoFacturable(
          manifiestoId: 'm1',
          fleteBase: 100,
          capacidadKg: 100,
          pesos: const [
            PesoProducto(
              productoId: 'p1',
              productoNombre: 'Pasta',
              kg: 60,
              empresaId: 'e1',
              empresaNombre: 'Empresa Uno',
            ),
            PesoProducto(
              productoId: 'p2',
              productoNombre: 'Confite',
              kg: 40,
              empresaId: 'e2',
              empresaNombre: 'Empresa Dos',
            ),
          ],
          extras: const [
            ConceptoExtra(concepto: 'caleta', monto: 50, tipo: TipoExtra.caleta),
          ],
        ),
      ]);
      final e1 = facturas.firstWhere((f) => f.empresaId == 'e1');
      final e2 = facturas.firstWhere((f) => f.empresaId == 'e2');
      expect(e1.subtotalFlete, closeTo(60, 0.001));
      expect(e2.subtotalFlete, closeTo(40, 0.001));
      // Extras repartidos con las mismas fracciones (0.6 / 0.4).
      expect(e1.subtotalExtras, closeTo(30, 0.001));
      expect(e2.subtotalExtras, closeTo(20, 0.001));
    });

    test('camión no lleno: el de menor peso absorbe el resto', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        ManifiestoFacturable(
          manifiestoId: 'm1',
          fleteBase: 100,
          capacidadKg: 200,
          pesos: const [
            PesoProducto(
              productoId: 'p1',
              productoNombre: 'Pasta',
              kg: 60,
              empresaId: 'e1',
            ),
            PesoProducto(
              productoId: 'p2',
              productoNombre: 'Confite',
              kg: 40,
              empresaId: 'e2',
            ),
          ],
        ),
      ]);
      final e1 = facturas.firstWhere((f) => f.empresaId == 'e1');
      final e2 = facturas.firstWhere((f) => f.empresaId == 'e2');
      expect(e1.subtotalFlete, closeTo(30, 0.001));
      expect(e2.subtotalFlete, closeTo(70, 0.001));
    });

    test('extras se prorratean por kg sobre el total de carga', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        ManifiestoFacturable(
          manifiestoId: 'm1',
          fleteBase: 100,
          capacidadKg: 200,
          pesos: const [
            PesoProducto(
                productoId: 'p1', productoNombre: 'Pasta', kg: 60, empresaId: 'e1'),
            PesoProducto(
                productoId: 'p2', productoNombre: 'Confite', kg: 40, empresaId: 'e2'),
          ],
          extras: const [
            ConceptoExtra(concepto: 'flete_secundario', monto: 50, tipo: TipoExtra.caleta),
          ],
        ),
      ]);
      final e1 = facturas.firstWhere((f) => f.empresaId == 'e1');
      final e2 = facturas.firstWhere((f) => f.empresaId == 'e2');
      // Flete por capacidad (menor peso absorbe): 30 / 70.
      expect(e1.subtotalFlete, closeTo(30, 0.001));
      expect(e2.subtotalFlete, closeTo(70, 0.001));
      // Extras por kg sobre el total (60/100 y 40/100): 30 / 20.
      expect(e1.subtotalExtras, closeTo(30, 0.001));
      expect(e2.subtotalExtras, closeTo(20, 0.001));
    });

    test('reproduce el Excel: manifiesto con Harina (Guanare)', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        ManifiestoFacturable(
          manifiestoId: 'guanare',
          fleteBase: 630,
          capacidadKg: 10000,
          pesos: const [
            PesoProducto(
                productoId: 'p1',
                productoNombre: 'Pasta',
                kg: 8490,
                empresaId: 'pastas'),
            PesoProducto(
                productoId: 'p2',
                productoNombre: 'Confite',
                kg: 434.76,
                empresaId: 'nucita'),
            PesoProducto(
                productoId: 'p3',
                productoNombre: 'Harina',
                kg: 600,
                empresaId: 'molvenca'),
          ],
          extras: const [
            ConceptoExtra(
                concepto: 'flete_secundario', monto: 30, tipo: TipoExtra.caleta),
          ],
        ),
      ]);
      final pastas = facturas.firstWhere((f) => f.empresaId == 'pastas');
      final nucita = facturas.firstWhere((f) => f.empresaId == 'nucita');
      final molvenca = facturas.firstWhere((f) => f.empresaId == 'molvenca');
      expect(pastas.subtotalFlete, closeTo(534.87, 0.01));
      expect(pastas.subtotalExtras, closeTo(26.74, 0.01));
      expect(nucita.subtotalFlete, closeTo(57.33, 0.01));
      expect(nucita.subtotalExtras, closeTo(1.37, 0.01));
      expect(molvenca.subtotalFlete, closeTo(37.80, 0.01));
      expect(molvenca.subtotalExtras, closeTo(1.89, 0.01));
    });

    test('tres productos agrupa por empresa y suma manifiestos', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        ManifiestoFacturable(
          manifiestoId: 'm1',
          fleteBase: 100,
          capacidadKg: 100,
          pesos: const [
            PesoProducto(
                productoId: 'p1', productoNombre: 'Pasta', kg: 50, empresaId: 'e1'),
            PesoProducto(
                productoId: 'p2', productoNombre: 'Confite', kg: 30, empresaId: 'e2'),
            PesoProducto(
                productoId: 'p3', productoNombre: 'Harina', kg: 20, empresaId: 'e2'),
          ],
        ),
        ManifiestoFacturable(
          manifiestoId: 'm2',
          fleteBase: 100,
          capacidadKg: 100,
          pesos: const [
            PesoProducto(
                productoId: 'p1', productoNombre: 'Pasta', kg: 100, empresaId: 'e1'),
          ],
        ),
      ]);
      final e1 = facturas.firstWhere((f) => f.empresaId == 'e1');
      final e2 = facturas.firstWhere((f) => f.empresaId == 'e2');
      expect(e1.total, closeTo(150, 0.001)); // 50 + 100
      expect(e2.total, closeTo(50, 0.001)); // 30 + 20
    });

    test('sin pesos capturados: todo queda sin empresa', () {
      final facturas = CalculoFacturacionEmpresas.calcular([
        const ManifiestoFacturable(
          manifiestoId: 'm1',
          fleteBase: 100,
          capacidadKg: 100,
        ),
      ]);
      expect(facturas.length, 1);
      expect(facturas.first.empresaId, isNull);
      expect(facturas.first.total, closeTo(100, 0.001));
    });

    test('sin manifiestos da lista vacía', () {
      expect(CalculoFacturacionEmpresas.calcular(const []), isEmpty);
    });
  });
}
