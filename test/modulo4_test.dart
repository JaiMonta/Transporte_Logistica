import 'package:app_logistica/features/manifiesto/models/manifiesto.dart';
import 'package:app_logistica/features/manifiesto/providers/manifiestos_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManifiestoLinea', () {
    test('fromMap interpreta tipo, número y cliente del catálogo', () {
      final l = ManifiestoLinea.fromMap({
        'id': 'l1',
        'tipo': 'factura',
        'numero': 'FAC-100',
        'cliente_id': 'c1',
        'clientes': {'nombre': 'Distribuidora del Centro'},
        'orden': 2,
      });
      expect(l.tipo, TipoDocumento.factura);
      expect(l.numero, 'FAC-100');
      expect(l.clienteId, 'c1');
      expect(l.clienteVisible, 'Distribuidora del Centro');
      expect(l.orden, 2);
    });

    test('clienteVisible cae al texto libre', () {
      const l = ManifiestoLinea(
        tipo: TipoDocumento.pro,
        numero: 'MN-1',
        clienteTexto: 'Cliente de la guía',
      );
      expect(l.clienteVisible, 'Cliente de la guía');
    });

    test('tipo desconocido cae a pro', () {
      final l = ManifiestoLinea.fromMap({'tipo': 'x', 'numero': 'N'});
      expect(l.tipo, TipoDocumento.pro);
    });

    test('aCuerpo arma el mapa para insert', () {
      const l = ManifiestoLinea(
        tipo: TipoDocumento.factura,
        numero: '  FAC-9 ',
        clienteTexto: '  Ana  ',
      );
      final cuerpo = l.aCuerpo(manifiestoId: 'm1');
      expect(cuerpo['manifiesto_id'], 'm1');
      expect(cuerpo['tipo'], 'factura');
      expect(cuerpo['numero'], 'FAC-9');
      expect(cuerpo['cliente_texto'], 'Ana');
    });
  });

  group('Manifiesto', () {
    test('fromMap interpreta cabecera y líneas ordenadas', () {
      final m = Manifiesto.fromMap({
        'id': 'm1',
        'fecha': '2026-02-03',
        'capturado_por': 'u1',
        'ocr_confianza': 0.9,
        'cotejo': 'ok',
        'profiles': {'nombre': 'Chofer Prueba'},
        'manifiesto_lineas': [
          {'tipo': 'pro', 'numero': 'B', 'orden': 1},
          {'tipo': 'pro', 'numero': 'A', 'orden': 0},
        ],
        'created_at': '2026-02-03T10:00:00Z',
      });
      expect(m.totalDocumentos, 2);
      expect(m.lineas.first.numero, 'A');
      expect(m.primerDocumento, 'A');
      expect(m.capturadoPorNombre, 'Chofer Prueba');
      expect(m.confianzaPorcentaje, 90);
      expect(m.cotejo, CotejoEstado.ok);
      expect(m.fecha.year, 2026);
    });

    test('sin líneas reporta 0 documentos', () {
      final m = Manifiesto.fromMap({
        'id': 'm2',
        'fecha': '2026-01-01',
      });
      expect(m.totalDocumentos, 0);
      expect(m.primerDocumento, 'Sin documentos');
      expect(m.tieneFoto, isFalse);
    });

    test('copyWith conserva id y fecha', () {
      final base = Manifiesto(
        id: 'm3',
        fecha: DateTime(2026, 1, 1),
        cotejo: CotejoEstado.pendiente,
      );
      final copia = base.copyWith(cotejo: CotejoEstado.revision);
      expect(copia.id, 'm3');
      expect(copia.cotejo, CotejoEstado.revision);
      expect(copia.fecha, base.fecha);
    });
  });

  group('CotejoEstado y TipoDocumento', () {
    test('desde mapea valores conocidos y por defecto', () {
      expect(CotejoEstado.desde('ok'), CotejoEstado.ok);
      expect(CotejoEstado.desde(null), CotejoEstado.pendiente);
      expect(TipoDocumento.desde('factura'), TipoDocumento.factura);
      expect(TipoDocumento.desde(null), TipoDocumento.pro);
    });

    test('cada valor tiene etiqueta', () {
      for (final e in CotejoEstado.values) {
        expect(e.etiqueta, isNotEmpty);
      }
      for (final t in TipoDocumento.values) {
        expect(t.etiqueta, isNotEmpty);
      }
    });
  });

  group('FiltroManifiestos', () {
    test('copyWith conserva y limpia fechas', () {
      final base = FiltroManifiestos(
        busqueda: 'MN',
        desde: DateTime(2026, 1, 1),
      );
      final copia = base.copyWith(busqueda: 'PRO', desde: null);
      expect(copia.busqueda, 'PRO');
      expect(copia.desde, isNull);
    });

    test('dos filtros con los mismos valores son iguales', () {
      final a = FiltroManifiestos(desde: DateTime(2026, 1, 1));
      final b = FiltroManifiestos(desde: DateTime(2026, 1, 1));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
