import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tabulador_flete.dart';

/// Acceso al tabulador de fletes (PostgREST, RLS).
class FletesRepository {
  FletesRepository(this._client);

  final SupabaseClient _client;

  Future<List<TabuladorFlete>> listar({String busqueda = ''}) async {
    final termino = busqueda.trim().replaceAll(RegExp(r'[(),%]'), '');
    List<dynamic> data;
    if (termino.isEmpty) {
      data = await _client
          .from('fletes_tabulador')
          .select()
          .order('localidad', ascending: true) as List<dynamic>;
    } else {
      data = await _client
          .from('fletes_tabulador')
          .select()
          .or('localidad.ilike.%$termino%,region.ilike.%$termino%')
          .order('localidad', ascending: true) as List<dynamic>;
    }
    return data
        .map((e) => TabuladorFlete.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<TabuladorFlete?> obtener(String id) async {
    final data = await _client
        .from('fletes_tabulador')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return TabuladorFlete.fromMap(Map<String, dynamic>.from(data));
  }

  Future<TabuladorFlete> actualizar(TabuladorFlete flete) async {
    final data = await _client
        .from('fletes_tabulador')
        .update(flete.aCuerpo())
        .eq('id', flete.id)
        .select()
        .single();
    return TabuladorFlete.fromMap(Map<String, dynamic>.from(data));
  }
}
