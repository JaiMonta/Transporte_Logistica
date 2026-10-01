import 'package:supabase_flutter/supabase_flutter.dart';

/// Envío de ubicaciones GPS a `public.ubicaciones_gps`.
class UbicacionesRepository {
  UbicacionesRepository(this._client);

  final SupabaseClient _client;

  Future<void> registrar({
    required double lat,
    required double lng,
    double? precision,
    String? manifiestoId,
    DateTime? capturadoEn,
  }) async {
    await _client.from('ubicaciones_gps').insert({
      'usuario_id': _client.auth.currentUser?.id,
      'manifiesto_id': manifiestoId,
      'lat': lat,
      'lng': lng,
      'precision': precision,
      'capturado_en':
          (capturadoEn ?? DateTime.now().toUtc()).toIso8601String(),
    });
  }

  /// Última posición conocida por usuario (para el mapa del panel).
  Future<Map<String, ({double lat, double lng, DateTime? cuando})>>
      ultimasPorUsuario() async {
    final data = await _client
        .from('ubicaciones_gps')
        .select('usuario_id, lat, lng, capturado_en')
        .order('capturado_en', ascending: false)
        .limit(200) as List<dynamic>;

    final resultado =
        <String, ({double lat, double lng, DateTime? cuando})>{};
    for (final item in data) {
      final m = Map<String, dynamic>.from(item as Map);
      final uid = m['usuario_id'] as String?;
      if (uid == null || resultado.containsKey(uid)) continue;
      resultado[uid] = (
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        cuando: DateTime.tryParse((m['capturado_en'] ?? '').toString()),
      );
    }
    return resultado;
  }

  /// Puntos GPS de un manifiesto, en orden temporal (para calcular km).
  Future<List<({double lat, double lng})>> puntosDeManifiesto(
    String manifiestoId,
  ) async {
    final data = await _client
        .from('ubicaciones_gps')
        .select('lat, lng')
        .eq('manifiesto_id', manifiestoId)
        .order('capturado_en', ascending: true) as List<dynamic>;
    return data
        .map((e) => (
              lat: ((e as Map)['lat'] as num).toDouble(),
              lng: (e['lng'] as num).toDouble(),
            ))
        .toList();
  }
}
