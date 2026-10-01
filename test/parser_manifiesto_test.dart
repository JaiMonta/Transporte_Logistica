import 'package:app_logistica/features/manifiesto/data/parser_manifiesto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParserManifiesto.extraerNumeroPro', () {
    test('reconoce etiqueta PRO', () {
      final r = ParserManifiesto.parsear('MANIFIESTO DE CARGA\nNo. PRO: MN-4501');
      expect(r.numeroPro, 'MN-4501');
    });

    test('reconoce etiqueta Folio', () {
      final r = ParserManifiesto.parsear('Folio: BOL-485729A');
      expect(r.numeroPro, 'BOL-485729A');
    });

    test('reconoce código suelto tipo letras-numero', () {
      final r = ParserManifiesto.parsear('Remisión\nMN-8921\nDestino: Valencia');
      expect(r.numeroPro, 'MN-8921');
    });

    test('devuelve vacío si no hay número', () {
      final r = ParserManifiesto.parsear('Solo texto sin folio alguno');
      expect(r.numeroPro, '');
    });
  });

  group('ParserManifiesto.extraerFecha', () {
    test('formato ISO', () {
      final r = ParserManifiesto.parsear('Fecha: 2026-03-15');
      expect(r.fecha, DateTime(2026, 3, 15));
    });

    test('formato dd/mm/aaaa', () {
      final r = ParserManifiesto.parsear('Fecha: 15/03/2026');
      expect(r.fecha, DateTime(2026, 3, 15));
    });

    test('formato dd-mm-aaaa', () {
      final r = ParserManifiesto.parsear('Fecha 01-12-2025');
      expect(r.fecha, DateTime(2025, 12, 1));
    });

    test('formato aaaa/mm/dd', () {
      final r = ParserManifiesto.parsear('2026/07/04');
      expect(r.fecha, DateTime(2026, 7, 4));
    });

    test('mes inválido devuelve null', () {
      final r = ParserManifiesto.parsear('Fecha: 2026-13-40');
      expect(r.fecha, isNull);
    });

    test('sin fecha devuelve null', () {
      final r = ParserManifiesto.parsear('Sin fecha aquí');
      expect(r.fecha, isNull);
    });
  });

  group('ParserManifiesto.extraerCliente', () {
    test('reconoce etiqueta Cliente', () {
      final r = ParserManifiesto.parsear('Cliente: Distribuidora del Centro');
      expect(r.cliente, 'Distribuidora del Centro');
    });

    test('reconoce etiqueta Destinatario', () {
      final r = ParserManifiesto.parsear('Destinatario: Grupo Industrial F&B');
      expect(r.cliente, 'Grupo Industrial F&B');
    });

    test('devuelve vacío si la etiqueta no tiene valor', () {
      final r = ParserManifiesto.parsear('Cliente:');
      expect(r.cliente, '');
    });
  });

  group('ParserManifiesto.parsear (integral)', () {
    test('documento completo', () {
      const texto = '''
MANIFIESTO DE CARGA
No. PRO: MN-4501
Fecha: 2026-03-15
Cliente: Distribuidora del Centro
Origen: Caracas   Destino: Valencia
''';
      final r = ParserManifiesto.parsear(texto);
      expect(r.numeroPro, 'MN-4501');
      expect(r.fecha, DateTime(2026, 3, 15));
      expect(r.cliente, 'Distribuidora del Centro');
      expect(r.tieneAlgo, isTrue);
    });

    test('texto vacío no tiene datos', () {
      final r = ParserManifiesto.parsear('');
      expect(r.numeroPro, '');
      expect(r.fecha, isNull);
      expect(r.cliente, '');
      expect(r.tieneAlgo, isFalse);
    });
  });
}
