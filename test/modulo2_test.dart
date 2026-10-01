import 'package:app_logistica/features/clientes/models/cliente.dart';
import 'package:app_logistica/features/clientes/providers/clientes_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cliente', () {
    test('fromMap interpreta columnas y coordenadas', () {
      final cliente = Cliente.fromMap({
        'id': 'c1',
        'nombre': 'Distribuidora del Centro',
        'cod_cli': 'CLI-001',
        'nombre_contacto': 'Ana Pérez',
        'telefono': '5551234567',
        'email': 'contacto@centro.com',
        'direccion': 'Av. Bolívar, Caracas',
        'lat': 10.4806,
        'lng': -66.9036,
        'activo': false,
        'created_at': '2026-02-03T04:05:06Z',
      });

      expect(cliente.id, 'c1');
      expect(cliente.codCli, 'CLI-001');
      expect(cliente.nombreContacto, 'Ana Pérez');
      expect(cliente.activo, isFalse);
      expect(cliente.lat, 10.4806);
      expect(cliente.lng, -66.9036);
      expect(cliente.tieneUbicacion, isTrue);
      expect(cliente.creadoEn, isNotNull);
    });

    test('lat/lng como texto se convierten a double', () {
      final cliente = Cliente.fromMap({
        'id': 'c2',
        'nombre': 'X',
        'lat': '10.5',
        'lng': '-66.9',
      });
      expect(cliente.lat, 10.5);
      expect(cliente.lng, -66.9);
    });

    test('tieneUbicacion es falso sin coordenadas o fuera de rango', () {
      const sinCoords = Cliente(id: 'c3', nombre: 'Sin coords');
      expect(sinCoords.tieneUbicacion, isFalse);

      const fueraDeRango = Cliente(id: 'c4', nombre: 'X', lat: 120, lng: 0);
      expect(fueraDeRango.tieneUbicacion, isFalse);

      const lngInvalida = Cliente(id: 'c5', nombre: 'X', lat: 0, lng: 200);
      expect(lngInvalida.tieneUbicacion, isFalse);
    });

    test('nombreVisible cae al texto por defecto cuando está vacío', () {
      const vacio = Cliente(id: 'c6', nombre: '   ');
      expect(vacio.nombreVisible, 'Cliente sin nombre');
    });

    test('iniciales toma nombre y apellido', () {
      const cliente = Cliente(id: 'c7', nombre: 'Distribuidora del Centro');
      expect(cliente.iniciales, 'DC');
    });

    test('copyWith conserva los campos no indicados', () {
      const base = Cliente(id: 'c8', nombre: 'A', activo: true, lat: 1, lng: 2);
      final copia = base.copyWith(nombre: 'B', activo: false);
      expect(copia.nombre, 'B');
      expect(copia.activo, isFalse);
      expect(copia.lat, 1);
      expect(copia.lng, 2);
      expect(copia.id, 'c8');
    });
  });

  group('FiltroClientes', () {
    test('copyWith conserva los campos no indicados', () {
      const base = FiltroClientes(busqueda: 'ana', activo: true);
      final copia = base.copyWith(busqueda: 'luis');
      expect(copia.busqueda, 'luis');
      expect(copia.activo, isTrue);
    });

    test('copyWith permite limpiar el filtro activo con null', () {
      const base = FiltroClientes(activo: true);
      final copia = base.copyWith(activo: null);
      expect(copia.activo, isNull);
    });

    test('dos filtros con los mismos valores son iguales', () {
      const a = FiltroClientes(busqueda: 'x', activo: false);
      const b = FiltroClientes(busqueda: 'x', activo: false);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
