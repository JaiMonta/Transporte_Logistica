import 'package:app_logistica/features/manifiesto/data/parser_manifiesto.dart';
import 'package:app_logistica/features/manifiesto/models/manifiesto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParserManifiesto.extraerDocumentos', () {
    test('detecta etiqueta PRO', () {
      final r = ParserManifiesto.parsear('No. PRO: MN-4501');
      expect(r.documentos.length, 1);
      expect(r.documentos.first.numero, 'MN-4501');
      expect(r.documentos.first.tipo, TipoDocumento.pro);
    });

    test('detecta etiqueta Factura', () {
      final r = ParserManifiesto.parsear('Factura: FAC-100');
      expect(r.documentos.first.tipo, TipoDocumento.factura);
      expect(r.documentos.first.numero, 'FAC-100');
    });

    test('detecta código suelto letras-número', () {
      final r = ParserManifiesto.parsear('Remisión\nMN-8921');
      expect(r.documentos.first.numero, 'MN-8921');
    });

    test('detecta varias líneas y respeta el tipo', () {
      const texto = '''
MANIFIESTO DE CARGA
Fecha: 2026-03-15
PRO: MN-4501
FACTURA: FAC-7788
PRO: MN-4502
''';
      final r = ParserManifiesto.parsear(texto);
      expect(r.documentos.length, 3);
      expect(r.documentos[0].tipo, TipoDocumento.pro);
      expect(r.documentos[0].numero, 'MN-4501');
      expect(r.documentos[1].tipo, TipoDocumento.factura);
      expect(r.documentos[1].numero, 'FAC-7788');
      expect(r.documentos[2].numero, 'MN-4502');
    });

    test('no repite el mismo documento', () {
      final r = ParserManifiesto.parsear('PRO: MN-1\nPRO: MN-1');
      expect(r.documentos.length, 1);
    });

    test('sin documentos devuelve lista vacía', () {
      final r = ParserManifiesto.parsear('Solo texto sin folio');
      expect(r.documentos, isEmpty);
    });

    test('aLineas asigna orden correlativo', () {
      final r = ParserManifiesto.parsear('PRO: A-100\nPRO: A-200');
      final lineas = r.aLineas();
      expect(lineas.length, 2);
      expect(lineas[0].orden, 0);
      expect(lineas[1].orden, 1);
    });
  });

  group('ParserManifiesto.extraerFecha', () {
    test('formato ISO', () {
      expect(ParserManifiesto.parsear('Fecha: 2026-03-15').fecha,
          DateTime(2026, 3, 15));
    });

    test('formato dd/mm/aaaa', () {
      expect(ParserManifiesto.parsear('Fecha: 15/03/2026').fecha,
          DateTime(2026, 3, 15));
    });

    test('formato dd-mm-aaaa', () {
      expect(ParserManifiesto.parsear('Fecha 01-12-2025').fecha,
          DateTime(2025, 12, 1));
    });

    test('mes inválido devuelve null', () {
      expect(ParserManifiesto.parsear('2026-13-40').fecha, isNull);
    });
  });

  group('ParserManifiesto.parsear (integral)', () {
    test('documento completo', () {
      const texto = '''
MANIFIESTO DE CARGA
Fecha: 2026-03-15
PRO: MN-4501
Factura: FAC-100
''';
      final r = ParserManifiesto.parsear(texto);
      expect(r.fecha, DateTime(2026, 3, 15));
      expect(r.documentos.length, 2);
      expect(r.tieneAlgo, isTrue);
    });

    test('texto vacío no tiene datos', () {
      final r = ParserManifiesto.parsear('');
      expect(r.fecha, isNull);
      expect(r.documentos, isEmpty);
      expect(r.tieneAlgo, isFalse);
    });
  });
}
