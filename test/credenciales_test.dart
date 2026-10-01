import 'package:app_logistica/features/auth/data/credenciales_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// ImplementaciÃ³n en memoria para probar la lÃ³gica sin el plugin nativo.
class _StorageFalso extends FlutterSecureStorage {
  _StorageFalso();

  final Map<String, String> datos = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      datos[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      datos.remove(key);
    } else {
      datos[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    datos.remove(key);
  }
}

void main() {
  group('CredencialesService', () {
    late _StorageFalso storage;
    late CredencialesService servicio;

    setUp(() {
      storage = _StorageFalso();
      servicio = CredencialesService(storage: storage);
    });

    test('guardar con contrasena la almacena (en entorno de prueba)', () async {
      // En tests kIsWeb es false, por lo que puedeRecordarContrasena = true.
      await servicio.guardar('user@example.com', contrasena: 'Clave123');
      expect(await servicio.leerCorreo(), 'user@example.com');
      expect(await servicio.leerContrasena(), 'Clave123');
    });

    test('guardar sin contrasena borra la previa y conserva el correo',
        () async {
      await servicio.guardar('user@example.com', contrasena: 'Clave123');
      await servicio.guardar('user@example.com');
      expect(await servicio.leerCorreo(), 'user@example.com');
      expect(await servicio.leerContrasena(), isNull);
    });

    test('guardar correo vacio lo elimina', () async {
      await servicio.guardar('user@example.com');
      await servicio.guardar('   ');
      expect(await servicio.leerCorreo(), isNull);
    });

    test('olvidarContrasena conserva el correo', () async {
      await servicio.guardar('user@example.com', contrasena: 'Clave123');
      await servicio.olvidarContrasena();
      expect(await servicio.leerCorreo(), 'user@example.com');
      expect(await servicio.leerContrasena(), isNull);
    });

    test('olvidarTodo borra correo y contrasena', () async {
      await servicio.guardar('user@example.com', contrasena: 'Clave123');
      await servicio.olvidarTodo();
      expect(await servicio.leerCorreo(), isNull);
      expect(await servicio.leerContrasena(), isNull);
    });

    test('el correo se recorta con trim', () async {
      await servicio.guardar('  user@example.com  ');
      expect(await servicio.leerCorreo(), 'user@example.com');
    });
  });
}
