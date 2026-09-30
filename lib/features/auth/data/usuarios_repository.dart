import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Método de alta de un usuario nuevo.
enum MetodoAlta { invitacion, contrasenaTemporal }

/// Acceso a la lista de perfiles (vía RLS del admin) y a las operaciones
/// privilegiadas mediante la Edge Function `admin-users` (nunca usa
/// service_role en la app).
class UsuariosRepository {
  UsuariosRepository(this._client);

  final SupabaseClient _client;

  static const String _funcion = 'admin-users';

  Future<List<Profile>> listar({
    String busqueda = '',
    Rol? rol,
    bool? activo,
  }) async {
    dynamic query = _client.from('profiles').select();

    if (rol != null) {
      query = query.eq('rol', rol.valor);
    }
    if (activo != null) {
      query = query.eq('activo', activo);
    }
    final termino = busqueda.trim().replaceAll(RegExp(r'[(),%]'), '');
    if (termino.isNotEmpty) {
      query = query.or(
        'nombre.ilike.%$termino%,email.ilike.%$termino%,telefono.ilike.%$termino%',
      );
    }

    final data = await query.order('nombre', ascending: true) as List<dynamic>;
    return data
        .map((e) => Profile.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> existeCorreo(String correo, {String? excluirId}) async {
    dynamic query = _client
        .from('profiles')
        .select('id')
        .eq('email', correo.trim().toLowerCase());
    if (excluirId != null) {
      query = query.neq('id', excluirId);
    }
    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  Future<void> crear({
    required String correo,
    required String nombre,
    required Rol rol,
    required MetodoAlta metodo,
    String? telefono,
    String? contrasena,
  }) =>
      _invocar({
        'action': 'create',
        'email': correo.trim(),
        'nombre': nombre.trim(),
        'rol': rol.valor,
        'metodo': metodo == MetodoAlta.invitacion ? 'invite' : 'password',
        if (telefono != null && telefono.trim().isNotEmpty)
          'telefono': telefono.trim(),
        'password': ?contrasena,
      });

  Future<void> actualizar({
    required String id,
    required String nombre,
    required Rol rol,
    String? telefono,
  }) =>
      _invocar({
        'action': 'update',
        'id': id,
        'nombre': nombre.trim(),
        'rol': rol.valor,
        'telefono': (telefono == null || telefono.trim().isEmpty)
            ? null
            : telefono.trim(),
      });

  Future<void> cambiarActivo({required String id, required bool activo}) =>
      _invocar({'action': 'set-active', 'id': id, 'activo': activo});

  Future<void> restablecerContrasena({
    required String id,
    required String contrasena,
  }) =>
      _invocar({
        'action': 'reset-password',
        'id': id,
        'password': contrasena,
      });

  Future<void> _invocar(Map<String, dynamic> cuerpo) async {
    try {
      final res = await _client.functions.invoke(_funcion, body: cuerpo);
      _leerRespuesta(res.data);
    } on FunctionException catch (e) {
      throw Exception(
        _mensajeDesde(e.details) ?? 'Error del servidor (${e.status}).',
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  void _leerRespuesta(dynamic data) {
    if (data is Map) {
      final mapa = Map<String, dynamic>.from(data);
      if (mapa['ok'] == true) return;
      throw Exception(mapa['error']?.toString() ?? 'No se pudo completar la operación.');
    }
    throw Exception('Respuesta inesperada del servidor.');
  }

  String? _mensajeDesde(dynamic details) {
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (details is String && details.isNotEmpty) return details;
    return null;
  }
}
