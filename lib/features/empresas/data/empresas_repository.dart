import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/empresa.dart';
import '../models/producto.dart';

/// Acceso a los catálogos de empresas y productos (PostgREST, protegido por RLS).
class EmpresasRepository {
  EmpresasRepository(this._client);

  final SupabaseClient _client;

  static const String _selEmpresa = '*';
  static const String _selProducto = '*, empresas(nombre)';

  // ----------------------------------------------------------
  // Empresas.
  // ----------------------------------------------------------
  Future<List<Empresa>> listarEmpresas({bool? activo}) async {
    dynamic query = _client.from('empresas').select(_selEmpresa);
    if (activo != null) query = query.eq('activo', activo);
    final data = await query.order('nombre', ascending: true) as List<dynamic>;
    return data
        .map((e) => Empresa.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Empresa?> obtenerEmpresa(String id) async {
    final data = await _client
        .from('empresas')
        .select(_selEmpresa)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Empresa.fromMap(Map<String, dynamic>.from(data));
  }

  Future<bool> existeNombreEmpresa(String nombre, {String? excluirId}) async {
    final n = nombre.trim();
    if (n.isEmpty) return false;
    dynamic query = _client.from('empresas').select('id').ilike('nombre', n);
    if (excluirId != null) query = query.neq('id', excluirId);
    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  Future<Empresa> crearEmpresa({
    required String nombre,
    String? rif,
  }) async {
    final data = await _client
        .from('empresas')
        .insert({'nombre': nombre.trim(), 'rif': _texto(rif)})
        .select(_selEmpresa)
        .single();
    return Empresa.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Empresa> actualizarEmpresa({
    required String id,
    required String nombre,
    String? rif,
  }) async {
    final data = await _client
        .from('empresas')
        .update({'nombre': nombre.trim(), 'rif': _texto(rif)})
        .eq('id', id)
        .select(_selEmpresa)
        .single();
    return Empresa.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> cambiarActivoEmpresa({
    required String id,
    required bool activo,
  }) async {
    await _client.from('empresas').update({'activo': activo}).eq('id', id);
  }

  // ----------------------------------------------------------
  // Productos.
  // ----------------------------------------------------------
  Future<List<Producto>> listarProductos({bool? activo}) async {
    dynamic query = _client.from('productos').select(_selProducto);
    if (activo != null) query = query.eq('activo', activo);
    final data = await query
        .order('orden', ascending: true)
        .order('nombre', ascending: true) as List<dynamic>;
    return data
        .map((e) => Producto.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> existeNombreProducto(String nombre, {String? excluirId}) async {
    final n = nombre.trim();
    if (n.isEmpty) return false;
    dynamic query = _client.from('productos').select('id').ilike('nombre', n);
    if (excluirId != null) query = query.neq('id', excluirId);
    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  Future<Producto> crearProducto({
    required String nombre,
    String? empresaId,
    int orden = 0,
  }) async {
    final data = await _client
        .from('productos')
        .insert({
          'nombre': nombre.trim(),
          'empresa_id': empresaId,
          'orden': orden,
        })
        .select(_selProducto)
        .single();
    return Producto.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Producto> actualizarProducto({
    required String id,
    required String nombre,
    String? empresaId,
    int orden = 0,
  }) async {
    final data = await _client
        .from('productos')
        .update({
          'nombre': nombre.trim(),
          'empresa_id': empresaId,
          'orden': orden,
        })
        .eq('id', id)
        .select(_selProducto)
        .single();
    return Producto.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> cambiarActivoProducto({
    required String id,
    required bool activo,
  }) async {
    await _client.from('productos').update({'activo': activo}).eq('id', id);
  }

  static String? _texto(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
