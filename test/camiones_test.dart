import 'package:app_logistica/features/camiones/models/camion.dart';
import 'package:app_logistica/features/camiones/providers/camiones_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Camion', () {
    test('fromMap interpreta campos y chofer del join', () {
      final c = Camion.fromMap({
        'id': 'c1',
        'marca': 'Marca X',
        'placa': 'ABC123',
        'modelo': 'Modelo 1',
        'anio': 2020,
        'capacidad_kg': 5000,
        'volumen_m3': 20,
        'chofer_id': 'u1',
        'profiles': {'nombre': 'Chofer Uno'},
        'activo': false,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(c.marca, 'Marca X');
      expect(c.placa, 'ABC123');
      expect(c.anio, 2020);
      expect(c.capacidadKg, 5000);
      expect(c.volumenM3, 20);
      expect(c.choferId, 'u1');
      expect(c.choferVisible, 'Chofer Uno');
      expect(c.activo, isFalse);
      expect(c.creadoEn, isNotNull);
    });

    test('capacidad/volumen como texto se convierten a double', () {
      final c = Camion.fromMap({
        'id': 'c2',
        'marca': 'X',
        'placa': 'P',
        'chofer_id': 'u1',
        'capacidad_kg': '1500.5',
        'volumen_m3': '12',
      });
      expect(c.capacidadKg, 1500.5);
      expect(c.volumenM3, 12);
    });

    test('marcaVisible y choferVisible caen a texto por defecto', () {
      const c = Camion(id: 'c3', marca: '  ', placa: 'P', choferId: 'u1');
      expect(c.marcaVisible, 'Camión sin marca');
      expect(c.choferVisible, 'Sin chofer');
    });

    test('choferVisible cae al email si no hay nombre', () {
      final c = Camion.fromMap({
        'id': 'c4',
        'marca': 'X',
        'placa': 'P',
        'chofer_id': 'u1',
        'profiles': {'email': 'chofer@example.com'},
      });
      expect(c.choferVisible, 'chofer@example.com');
    });

    test('copyWith conserva los campos no indicados', () {
      const base = Camion(
          id: 'c5', marca: 'A', placa: 'AA', choferId: 'u1', activo: true);
      final copia = base.copyWith(marca: 'B', activo: false);
      expect(copia.marca, 'B');
      expect(copia.activo, isFalse);
      expect(copia.placa, 'AA');
      expect(copia.choferId, 'u1');
    });
  });

  group('FiltroCamiones', () {
    test('copyWith conserva los campos no indicados', () {
      const base = FiltroCamiones(busqueda: 'abc', activo: true);
      final copia = base.copyWith(busqueda: 'xyz');
      expect(copia.busqueda, 'xyz');
      expect(copia.activo, isTrue);
    });

    test('copyWith permite limpiar el filtro activo con null', () {
      const base = FiltroCamiones(activo: true);
      final copia = base.copyWith(activo: null);
      expect(copia.activo, isNull);
    });

    test('dos filtros con los mismos valores son iguales', () {
      const a = FiltroCamiones(busqueda: 'x', activo: false);
      const b = FiltroCamiones(busqueda: 'x', activo: false);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
