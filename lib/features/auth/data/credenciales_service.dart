import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda las credenciales de acceso recordadas en el almacenamiento seguro
/// del dispositivo (Keychain en iOS, Keystore en Android).
///
/// Reglas de seguridad:
///   * La **contraseña** solo se recuerda en móvil (nunca en Web).
///   * El **correo** sí se recuerda también en Web.
///   * Al cerrar sesión se borran todas las credenciales recordadas.
class CredencialesService {
  CredencialesService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _claveCorreo = 'auth-correo';
  static const String _claveContrasena = 'auth-contrasena';

  /// ¿Se puede recordar la contraseña en esta plataforma?
  bool get puedeRecordarContrasena => !kIsWeb;

  Future<String?> leerCorreo() => _storage.read(key: _claveCorreo);

  Future<String?> leerContrasena() async {
    if (!puedeRecordarContrasena) return null;
    return _storage.read(key: _claveContrasena);
  }

  /// Guarda el correo (siempre) y, si [contrasena] no es nula y la plataforma
  /// lo permite, también la contraseña. Si [contrasena] es nula, borra la
  /// contraseña previa.
  Future<void> guardar(String correo, {String? contrasena}) async {
    final c = correo.trim();
    if (c.isEmpty) {
      await _storage.delete(key: _claveCorreo);
    } else {
      await _storage.write(key: _claveCorreo, value: c);
    }

    if (contrasena != null && contrasena.isNotEmpty && puedeRecordarContrasena) {
      await _storage.write(key: _claveContrasena, value: contrasena);
    } else {
      await _storage.delete(key: _claveContrasena);
    }
  }

  /// Borra solo la contraseña recordada (conserva el correo).
  Future<void> olvidarContrasena() => _storage.delete(key: _claveContrasena);

  /// Borra todas las credenciales recordadas (al cerrar sesión).
  Future<void> olvidarTodo() async {
    await _storage.delete(key: _claveCorreo);
    await _storage.delete(key: _claveContrasena);
  }
}
