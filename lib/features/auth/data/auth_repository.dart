import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Operaciones de autenticación y del perfil propio.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> perfilDeUsuario(String id) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<Profile?> perfilActual() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return null;
    return perfilDeUsuario(usuario.id);
  }

  Future<AuthResponse> iniciarSesion({
    required String correo,
    required String contrasena,
  }) =>
      _client.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );

  Future<void> cerrarSesion() => _client.auth.signOut();

  Future<void> recuperarContrasena(String correo, {String? redireccion}) =>
      _client.auth.resetPasswordForEmail(
        correo.trim(),
        redirectTo: redireccion,
      );

  Future<void> actualizarContrasena(String nuevaContrasena) =>
      _client.auth.updateUser(UserAttributes(password: nuevaContrasena));

  /// El chofer (o admin) actualiza su propio nombre y teléfono.
  Future<void> actualizarPerfilPropio({
    required String id,
    required String nombre,
    String? telefono,
  }) async {
    final tel = telefono?.trim();
    await _client.from('profiles').update({
      'nombre': nombre.trim(),
      'telefono': (tel == null || tel.isEmpty) ? null : tel,
    }).eq('id', id);
  }
}
