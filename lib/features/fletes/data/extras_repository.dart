import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/extra.dart';

/// Acceso a los extras de un manifiesto (PostgREST, RLS).
class ExtrasRepository {
  ExtrasRepository(this._client);

  final SupabaseClient _client;

  Future<List<Extra>> porManifiesto(String manifiestoId) async {
    final data = await _client
        .from('manifiesto_extras')
        .select()
        .eq('manifiesto_id', manifiestoId)
        .order('created_at', ascending: true) as List<dynamic>;
    return data
        .map((e) => Extra.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Extra> crear(Extra extra) async {
    final data = await _client
        .from('manifiesto_extras')
        .insert(extra.aCuerpo(manifiestoId: extra.manifiestoId))
        .select()
        .single();
    return Extra.fromMap(Map<String, dynamic>.from(data));
  }

  /// Crea un lote de extras (cálculo sugerido).
  Future<void> crearLote(List<Extra> extras) async {
    if (extras.isEmpty) return;
    final filas = [for (final e in extras) e.aCuerpo(manifiestoId: e.manifiestoId)];
    await _client.from('manifiesto_extras').insert(filas);
  }

  Future<void> cambiarEstado({
    required String id,
    required EstadoExtra estado,
    String? notas,
  }) async {
    await _client.from('manifiesto_extras').update({
      'estado': estado.valor,
      'aprobado_por': _client.auth.currentUser?.id,
      'aprobado_en': DateTime.now().toUtc().toIso8601String(),
      'notas': notas,
    }).eq('id', id);
  }

  Future<void> actualizarMonto({required String id, required double monto}) async {
    await _client.from('manifiesto_extras').update({'monto': monto}).eq('id', id);
  }

  Future<void> eliminar(String id) async {
    await _client.from('manifiesto_extras').delete().eq('id', id);
  }

  /// Elimina los extras en estado "sugerido" de un manifiesto (para recalcular).
  Future<void> eliminarSugeridos(String manifiestoId) async {
    await _client
        .from('manifiesto_extras')
        .delete()
        .eq('manifiesto_id', manifiestoId)
        .eq('estado', 'sugerido');
  }
}
