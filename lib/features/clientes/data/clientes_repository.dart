import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente.dart';

/// Acceso al catálogo de clientes.
///
/// Las lecturas y escrituras van directo a PostgREST (protegidas por RLS):
/// el chofer solo lee los activos, el administrador gestiona todo.
class ClientesRepository {
  ClientesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Cliente>> listar({
    String busqueda = '',
    bool? activo,
  }) async {
    dynamic query = _client.from('clientes').select();

    if (activo != null) {
      query = query.eq('activo', activo);
    }
    final termino = busqueda.trim().replaceAll(RegExp(r'[(),%]'), '');
    if (termino.isNotEmpty) {
      query = query.or(
        'nombre.ilike.%$termino%,nombre_contacto.ilike.%$termino%,'
        'email.ilike.%$termino%,telefono.ilike.%$termino%,'
        'direccion.ilike.%$termino%',
      );
    }

    final data = await query.order('nombre', ascending: true) as List<dynamic>;
    return data
        .map((e) => Cliente.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Cliente?> obtener(String id) async {
    final data = await _client
        .from('clientes')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Cliente.fromMap(Map<String, dynamic>.from(data));
  }

  Future<bool> existeCorreo(String correo, {String? excluirId}) async {
    final correoNormalizado = correo.trim().toLowerCase();
    if (correoNormalizado.isEmpty) return false;
    dynamic query = _client
        .from('clientes')
        .select('id')
        .eq('email', correoNormalizado);
    if (excluirId != null) {
      query = query.neq('id', excluirId);
    }
    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  Future<Cliente> crear({
    required String nombre,
    String? nombreContacto,
    String? telefono,
    String? email,
    String? direccion,
    double? lat,
    double? lng,
  }) async {
    final data = await _client
        .from('clientes')
        .insert(_cuerpo(
          nombre: nombre,
          nombreContacto: nombreContacto,
          telefono: telefono,
          email: email,
          direccion: direccion,
          lat: lat,
          lng: lng,
        ))
        .select()
        .single();
    return Cliente.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Cliente> actualizar({
    required String id,
    required String nombre,
    String? nombreContacto,
    String? telefono,
    String? email,
    String? direccion,
    double? lat,
    double? lng,
  }) async {
    final data = await _client
        .from('clientes')
        .update(_cuerpo(
          nombre: nombre,
          nombreContacto: nombreContacto,
          telefono: telefono,
          email: email,
          direccion: direccion,
          lat: lat,
          lng: lng,
        ))
        .eq('id', id)
        .select()
        .single();
    return Cliente.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> cambiarActivo({required String id, required bool activo}) async {
    await _client.from('clientes').update({'activo': activo}).eq('id', id);
  }

  Map<String, dynamic> _cuerpo({
    required String nombre,
    String? nombreContacto,
    String? telefono,
    String? email,
    String? direccion,
    double? lat,
    double? lng,
  }) =>
      {
        'nombre': nombre.trim(),
        'nombre_contacto': _texto(nombreContacto),
        'telefono': _texto(telefono),
        'email': _texto(email)?.toLowerCase(),
        'direccion': _texto(direccion),
        'lat': lat,
        'lng': lng,
      };

  static String? _texto(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
