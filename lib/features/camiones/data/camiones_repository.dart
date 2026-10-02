import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/camion.dart';

/// Acceso al catálogo de camiones (PostgREST, protegido por RLS).
class CamionesRepository {
  CamionesRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion = '*, profiles(nombre, email)';

  Future<List<Camion>> listar({
    String busqueda = '',
    bool? activo,
  }) async {
    dynamic query = _client.from('camiones').select(_seleccion);

    if (activo != null) {
      query = query.eq('activo', activo);
    }
    final termino = busqueda.trim().replaceAll(RegExp(r'[(),%]'), '');
    if (termino.isNotEmpty) {
      query = query.or('marca.ilike.%$termino%,placa.ilike.%$termino%,'
          'modelo.ilike.%$termino%');
    }

    final data = await query.order('marca', ascending: true) as List<dynamic>;
    return data
        .map((e) => Camion.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Camion?> obtener(String id) async {
    final data = await _client
        .from('camiones')
        .select(_seleccion)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Camion.fromMap(Map<String, dynamic>.from(data));
  }

  /// ¿Ya existe un camión con esa placa? (comparación sin distinguir mayúsculas)
  Future<bool> existePlaca(String placa, {String? excluirId}) async {
    final p = placa.trim();
    if (p.isEmpty) return false;
    dynamic query =
        _client.from('camiones').select('id').ilike('placa', p);
    if (excluirId != null) {
      query = query.neq('id', excluirId);
    }
    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  Future<Camion> crear({
    required String marca,
    required String placa,
    required String choferId,
    String? modelo,
    int? anio,
    double? capacidadKg,
    double? volumenM3,
  }) async {
    final data = await _client
        .from('camiones')
        .insert(_cuerpo(
          marca: marca,
          placa: placa,
          choferId: choferId,
          modelo: modelo,
          anio: anio,
          capacidadKg: capacidadKg,
          volumenM3: volumenM3,
        ))
        .select(_seleccion)
        .single();
    return Camion.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Camion> actualizar({
    required String id,
    required String marca,
    required String placa,
    required String choferId,
    String? modelo,
    int? anio,
    double? capacidadKg,
    double? volumenM3,
  }) async {
    final data = await _client
        .from('camiones')
        .update(_cuerpo(
          marca: marca,
          placa: placa,
          choferId: choferId,
          modelo: modelo,
          anio: anio,
          capacidadKg: capacidadKg,
          volumenM3: volumenM3,
        ))
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Camion.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> cambiarActivo({required String id, required bool activo}) async {
    await _client.from('camiones').update({'activo': activo}).eq('id', id);
  }

  Map<String, dynamic> _cuerpo({
    required String marca,
    required String placa,
    required String choferId,
    String? modelo,
    int? anio,
    double? capacidadKg,
    double? volumenM3,
  }) =>
      {
        'marca': marca.trim(),
        'placa': placa.trim(),
        'chofer_id': choferId,
        'modelo': _texto(modelo),
        'anio': anio,
        'capacidad_kg': capacidadKg,
        'volumen_m3': volumenM3,
      };

  static String? _texto(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
