import 'package:app_logistica/features/manifiesto/models/manifiesto.dart';
import 'package:app_logistica/features/manifiesto/providers/manifiestos_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Manifiesto', () {
    test('fromMap interpreta columnas, join de cliente y perfil', () {
      final m = Manifiesto.fromMap({
        'id': 'm1',
        'numero_pro': 'MN-8921',
        'cliente_id': 'c1',
        'fecha': '2026-02-03',
        'capturado_por': 'u1',
        'bucket': 'manifiestos',
        'path': 'u1/bol/bol_1.jpg',
        'hash_sha256': 'abc',
        'ocr_pro': 'MN-8921',
        'ocr_confianza': 0.99,
        'cotejo': 'ok',
        'clientes': {'nombre': 'Distribuidora del Centro'},
        'profiles': {'nombre': 'Chofer Prueba'},
        'created_at': '2026-02-03T10:00:00Z',
      });

      expect(m.numeroPro, 'MN-8921');
      expect(m.clienteId, 'c1');
      expect(m.clienteNombre, 'Distribuidora del Centro');
      expect(m.capturadoPorNombre, 'Chofer Prueba');
      expect(m.tieneFoto, isTrue);
      expect(m.confianzaPorcentaje, 99);
      expect(m.cotejo, CotejoEstado.ok);
      expect(m.fecha.year, 2026);
      expect(m.fecha.month, 2);
      expect(m.fecha.day, 3);
      expect(m.creadoEn, isNotNull);
    });

    test('confianza como texto se convierte a double', () {
      final m = Manifiesto.fromMap({
        'id': 'm2',
        'numero_pro': 'X',
        'fecha': '2026-01-01',
        'ocr_confianza': '0.5',
      });
      expect(m.ocrConfianza, 0.5);
      expect(m.confianzaPorcentaje, 50);
    });

    test('cotejo desconocido cae a pendiente', () {
      final m = Manifiesto.fromMap({
        'id': 'm3',
        'numero_pro': 'X',
        'fecha': '2026-01-01',
        'cotejo': 'inventado',
      });
      expect(m.cotejo, CotejoEstado.pendiente);
    });

    test('valores por defecto cuando faltan datos', () {
      final m = Manifiesto.fromMap({
        'id': 'm4',
        'numero_pro': '   ',
        'fecha': '2026-01-01',
      });
      expect(m.numeroVisible, 'Sin número');
      expect(m.clienteVisible, 'Sin cliente');
      expect(m.tieneFoto, isFalse);
      expect(m.confianzaPorcentaje, isNull);
    });

    test('copyWith conserva los campos no indicados', () {
      final base = Manifiesto(
        id: 'm5',
        numeroPro: 'A',
        fecha: DateTime(2026, 1, 1),
        cotejo: CotejoEstado.pendiente,
      );
      final copia = base.copyWith(numeroPro: 'B', cotejo: CotejoEstado.revision);
      expect(copia.numeroPro, 'B');
      expect(copia.cotejo, CotejoEstado.revision);
      expect(copia.id, 'm5');
      expect(copia.fecha, base.fecha);
    });
  });

  group('CotejoEstado', () {
    test('desde mapea los valores conocidos', () {
      expect(CotejoEstado.desde('ok'), CotejoEstado.ok);
      expect(CotejoEstado.desde('revision'), CotejoEstado.revision);
      expect(CotejoEstado.desde(null), CotejoEstado.pendiente);
    });

    test('cada estado tiene etiqueta legible', () {
      for (final estado in CotejoEstado.values) {
        expect(estado.etiqueta, isNotEmpty);
      }
    });
  });

  group('FiltroManifiestos', () {
    test('copyWith conserva los campos no indicados', () {
      final base = FiltroManifiestos(
        busqueda: 'MN',
        desde: DateTime(2026, 1, 1),
      );
      final copia = base.copyWith(busqueda: 'PRO');
      expect(copia.busqueda, 'PRO');
      expect(copia.desde, base.desde);
    });

    test('copyWith permite limpiar las fechas con null', () {
      final base = FiltroManifiestos(
        desde: DateTime(2026, 1, 1),
        hasta: DateTime(2026, 1, 31),
      );
      final copia = base.copyWith(desde: null, hasta: null);
      expect(copia.desde, isNull);
      expect(copia.hasta, isNull);
    });

    test('dos filtros con los mismos valores son iguales', () {
      final a = FiltroManifiestos(desde: DateTime(2026, 1, 1));
      final b = FiltroManifiestos(desde: DateTime(2026, 1, 1));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
