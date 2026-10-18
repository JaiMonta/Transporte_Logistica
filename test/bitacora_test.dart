import 'package:app_logistica/features/bitacora/models/bitacora.dart';
import 'package:app_logistica/features/bitacora/services/calculo_bitacora.dart';
import 'package:app_logistica/features/bitacora/services/export_bitacora.dart';
import 'package:app_logistica/features/entregas/models/entrega.dart';
import 'package:app_logistica/features/fletes/models/tabulador_flete.dart';
import 'package:flutter_test/flutter_test.dart';

TabuladorFlete _tab(String loc, String region, double km, double p10) =>
    TabuladorFlete(
      id: loc,
      localidad: loc,
      region: region,
      km: km,
      precio10: p10,
    );

Map<String, TabuladorFlete> _tabulador() => {
  'MARACAY': _tab('MARACAY', 'Aragua', 10, 84),
  'VALENCIA': _tab('VALENCIA', 'Carabobo', 49, 200),
  'CARACAS': _tab('CARACAS', 'Miranda', 120, 300),
};

void main() {
  group('CalculoBitacora.regionDe', () {
    test('devuelve la región del tabulador', () {
      expect(CalculoBitacora.regionDe('valencia', _tabulador()), 'Carabobo');
    });

    test('null si la localidad es vacía o desconocida', () {
      expect(CalculoBitacora.regionDe(null, _tabulador()), isNull);
      expect(CalculoBitacora.regionDe('', _tabulador()), isNull);
      expect(CalculoBitacora.regionDe('SIN LOCALIDAD', _tabulador()), isNull);
    });
  });

  group('CalculoBitacora.fleteBaseDeEntregas', () {
    test('usa la entrega marcada es_mas_lejana', () {
      final entregas = [
        const EntregaBitacora(cliente: 'A', destino: 'MARACAY'),
        const EntregaBitacora(
          cliente: 'B',
          destino: 'VALENCIA',
          esMasLejana: true,
        ),
      ];
      final flete = CalculoBitacora.fleteBaseDeEntregas(
        entregas: entregas,
        capacidadKg: 10000,
        tabulador: _tabulador(),
      );
      expect(flete, 200);
    });

    test('sin marca usa la de mayor km', () {
      final entregas = [
        const EntregaBitacora(cliente: 'A', destino: 'MARACAY'),
        const EntregaBitacora(cliente: 'B', destino: 'CARACAS'),
      ];
      final flete = CalculoBitacora.fleteBaseDeEntregas(
        entregas: entregas,
        capacidadKg: 10000,
        tabulador: _tabulador(),
      );
      expect(flete, 300);
    });

    test('sin localidad en el tabulador cae al flete guardado', () {
      final entregas = [const EntregaBitacora(cliente: 'A', destino: 'OTRA')];
      final flete = CalculoBitacora.fleteBaseDeEntregas(
        entregas: entregas,
        capacidadKg: 10000,
        tabulador: _tabulador(),
        costoFleteGuardado: 40,
      );
      expect(flete, 40);
    });
  });

  group('CalculoBitacora.agrupar', () {
    test('agrupa por día ascendente y suma totales', () {
      final m1 = ManifiestoBitacora(
        id: 'm1',
        fecha: DateTime(2024, 12, 3),
        fleteBase: 306,
        entregas: [const EntregaBitacora(cliente: 'A')],
      );
      final m2 = ManifiestoBitacora(
        id: 'm2',
        fecha: DateTime(2024, 12, 3),
        fleteBase: 84,
        entregas: [
          const EntregaBitacora(cliente: 'B'),
          const EntregaBitacora(cliente: 'C'),
        ],
      );
      final m3 = ManifiestoBitacora(
        id: 'm3',
        fecha: DateTime(2024, 12, 5),
        fleteBase: 100,
        entregas: [const EntregaBitacora(cliente: 'D')],
      );
      final r = CalculoBitacora.agrupar(
        desde: DateTime(2024, 12, 2),
        hasta: DateTime(2024, 12, 6),
        manifiestos: [m3, m1, m2],
      );
      expect(r.dias.length, 2);
      expect(r.dias.first.fecha, DateTime(2024, 12, 3));
      expect(r.dias.first.manifiestos.length, 2);
      expect(r.dias.first.totalFlete, 390);
      expect(r.totalManifiestos, 3);
      expect(r.totalEntregas, 4);
      expect(r.totalFlete, 490);
    });
  });

  group('ExportBitacora', () {
    BitacoraResumen resumen() => CalculoBitacora.agrupar(
      desde: DateTime(2024, 12, 2),
      hasta: DateTime(2024, 12, 6),
      manifiestos: [
        ManifiestoBitacora(
          id: 'm1',
          fecha: DateTime(2024, 12, 3),
          choferNombre: 'JOSE MERIDA',
          guias: const ['51022', '51023'],
          capacidadKg: 12000,
          fleteBase: 306,
          entregas: [
            const EntregaBitacora(
              cliente: 'CATANIA; LA BELISA',
              destino: 'PTO CABELLO',
              region: 'Carabobo',
              estado: EstadoEntrega.entregado,
            ),
          ],
        ),
      ],
    );

    test('filas aplana una fila por entrega', () {
      final filas = ExportBitacora.filas(resumen());
      expect(filas.length, 1);
      expect(filas.first.chofer, 'JOSE MERIDA');
      expect(filas.first.guias, '51022 / 51023');
      expect(filas.first.capacidad, '12.0 T');
    });

    test('CSV escapa el separador y las comillas', () {
      final csv = ExportBitacora.filasCsv(resumen());
      expect(csv, contains('N° Guía(s)'));
      expect(csv, contains('"CATANIA; LA BELISA"'));
      expect(csv, contains('Total flete (USD);306.00'));
    });
  });
}
