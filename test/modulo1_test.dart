import 'package:app_logistica/features/auth/models/profile.dart';
import 'package:app_logistica/features/auth/providers/usuarios_providers.dart';
import 'package:app_logistica/shared/validators/validador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validador', () {
    test('nombre exige al menos 3 caracteres', () {
      expect(Validador.nombre(null), isNotNull);
      expect(Validador.nombre('  '), isNotNull);
      expect(Validador.nombre('Jo'), isNotNull);
      expect(Validador.nombre('Ana'), isNull);
    });

    test('correo valida formato', () {
      expect(Validador.correo('sin-arroba'), isNotNull);
      expect(Validador.correo('a@b'), isNotNull);
      expect(Validador.correo('usuario@dominio.com'), isNull);
    });

    test('telefono es opcional pero si viene debe ser válido', () {
      expect(Validador.telefono(''), isNull);
      expect(Validador.telefono(null), isNull);
      expect(Validador.telefono('abc'), isNotNull);
      expect(Validador.telefono('+52 555 123 4567'), isNull);
    });

    test('contrasena aplica política mínima', () {
      expect(Validador.contrasena('corta'), isNotNull);
      expect(Validador.contrasena('solominusculas1'), isNotNull);
      expect(Validador.contrasena('SinNumeros'), isNotNull);
      expect(Validador.contrasena('Segura123'), isNull);
    });

    test('confirmarContrasena compara con el original', () {
      expect(Validador.confirmarContrasena('', 'Segura123'), isNotNull);
      expect(Validador.confirmarContrasena('Otra123', 'Segura123'), isNotNull);
      expect(Validador.confirmarContrasena('Segura123', 'Segura123'), isNull);
    });
  });

  group('Profile', () {
    test('fromMap interpreta rol, activo y fechas', () {
      final perfil = Profile.fromMap({
        'id': 'abc',
        'email': 'a@b.com',
        'nombre': 'Ana Pérez',
        'telefono': '1234567890',
        'rol': 'admin',
        'activo': false,
        'created_at': '2026-01-02T03:04:05Z',
      });

      expect(perfil.esAdmin, isTrue);
      expect(perfil.activo, isFalse);
      expect(perfil.telefono, '1234567890');
      expect(perfil.creadoEn, isNotNull);
    });

    test('rol desconocido o nulo cae a chofer', () {
      expect(RolX.desde('admin'), Rol.admin);
      expect(RolX.desde('chofer'), Rol.chofer);
      expect(RolX.desde(null), Rol.chofer);
      expect(RolX.desde('otro'), Rol.chofer);
    });

    test('nombreVisible cae al correo cuando no hay nombre', () {
      const sinNombre = Profile(
        id: '1',
        email: 'chofer@dominio.com',
        rol: Rol.chofer,
        activo: true,
      );
      expect(sinNombre.nombreVisible, 'chofer@dominio.com');
      expect(sinNombre.iniciales, '?');
    });

    test('iniciales toma nombre y apellido', () {
      const perfil = Profile(
        id: '1',
        nombre: 'Ana Pérez',
        rol: Rol.chofer,
        activo: true,
      );
      expect(perfil.iniciales, 'AP');
    });
  });

  group('FiltroUsuarios', () {
    test('copyWith conserva los campos no indicados', () {
      const base = FiltroUsuarios(busqueda: 'ana', rol: Rol.admin, activo: true);
      final copia = base.copyWith(busqueda: 'luis');
      expect(copia.busqueda, 'luis');
      expect(copia.rol, Rol.admin);
      expect(copia.activo, isTrue);
    });

    test('copyWith permite limpiar filtros con null', () {
      const base = FiltroUsuarios(rol: Rol.admin, activo: true);
      final copia = base.copyWith(rol: null, activo: null);
      expect(copia.rol, isNull);
      expect(copia.activo, isNull);
    });

    test('dos filtros con los mismos valores son iguales', () {
      const a = FiltroUsuarios(busqueda: 'x', rol: Rol.chofer, activo: false);
      const b = FiltroUsuarios(busqueda: 'x', rol: Rol.chofer, activo: false);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
