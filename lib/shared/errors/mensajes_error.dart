import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce errores técnicos a mensajes claros para el usuario final.
String mensajeError(Object error) {
  if (error is AuthException) return _traducir(error.message);
  if (error is PostgrestException) return _traducir(error.message);
  if (error is FunctionException) {
    final detalle = error.details;
    if (detalle is Map && detalle['error'] != null) {
      return detalle['error'].toString();
    }
    return _traducir(error.details?.toString() ?? 'Error del servidor.');
  }
  final texto = error.toString();
  return _traducir(texto.startsWith('Exception: ') ? texto.substring(11) : texto);
}

String _traducir(String mensaje) {
  final m = mensaje.toLowerCase();
  if (m.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (m.contains('email not confirmed')) {
    return 'Debes confirmar tu correo antes de iniciar sesión.';
  }
  if (m.contains('user is banned') || m.contains('banned')) {
    return 'La cuenta está inactiva. Contacta al administrador.';
  }
  if (m.contains('security purposes') || m.contains('rate limit')) {
    return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
  }
  if (m.contains('password should') || m.contains('password is too short')) {
    return 'La contraseña no cumple la política mínima de seguridad.';
  }
  if (m.contains('user not found')) {
    return 'No existe una cuenta con ese correo.';
  }
  if (m.contains('already registered') || m.contains('already been registered')) {
    return 'Ya existe una cuenta con ese correo.';
  }
  return mensaje;
}
