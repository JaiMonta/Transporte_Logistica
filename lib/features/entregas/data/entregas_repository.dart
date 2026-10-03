import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entrega.dart';

/// Acceso a las entregas (PostgREST, protegido por RLS).
class EntregasRepository {
  EntregasRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion = '*, clientes(nombre)';

  /// Entregas de un manifiesto, ordenadas por secuencia.
  Future<List<Entrega>> porManifiesto(String manifiestoId) async {
    final data = await _client
        .from('entregas')
        .select(_seleccion)
        .eq('manifiesto_id', manifiestoId)
        .order('orden', ascending: true) as List<dynamic>;
    return data
        .map((e) => Entrega.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Entregas del día (por fecha del manifiesto).
  Future<List<Entrega>> delDia(DateTime fecha) async {
    final dia = _fechaTexto(fecha);
    final manis = await _client
        .from('manifiestos')
        .select('id')
        .eq('fecha', dia) as List<dynamic>;
    final ids = manis.map((e) => (e as Map)['id'] as String).toList();
    if (ids.isEmpty) return [];
    return _porManifiestos(ids);
  }

  /// Entregas pendientes (sin fecha límite).
  ///
  /// El RLS limita al chofer a las de sus manifiestos; el admin ve todas.
  Future<List<Entrega>> pendientes() async {
    final data = await _client
        .from('entregas')
        .select(_seleccion)
        .eq('estado', 'pendiente')
        .order('manifiesto_id', ascending: true)
        .order('orden', ascending: true) as List<dynamic>;
    return data
        .map((e) => Entrega.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Todas las entregas (el RLS filtra por rol).
  Future<List<Entrega>> todas() async {
    final data = await _client
        .from('entregas')
        .select(_seleccion)
        .order('manifiesto_id', ascending: true)
        .order('orden', ascending: true) as List<dynamic>;
    return data
        .map((e) => Entrega.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Entrega>> _porManifiestos(List<String> ids) async {
    final data = await _client
        .from('entregas')
        .select(_seleccion)
        .inFilter('manifiesto_id', ids)
        .order('manifiesto_id', ascending: true)
        .order('orden', ascending: true) as List<dynamic>;
    return data
        .map((e) => Entrega.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Entrega?> obtener(String id) async {
    final data = await _client
        .from('entregas')
        .select(_seleccion)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Entrega.fromMap(Map<String, dynamic>.from(data));
  }

  /// Marca una entrega como entregada (hora del servidor).
  ///
  /// Si se pasa [evidencia] se registran bucket/path/hash de la foto del
  /// recibo; si no, la entrega queda sin foto (opcional).
  Future<Entrega> marcarEntregado({
    required String id,
    String? bucket,
    String? path,
    String? hashSha256,
    String? notas,
  }) async {
    final data = await _client
        .from('entregas')
        .update({
          'estado': EstadoEntrega.entregado.valor,
          'entregado_en': DateTime.now().toUtc().toIso8601String(),
          'entregado_por': _client.auth.currentUser?.id,
          'bucket': bucket,
          'path': path,
          'hash_sha256': hashSha256,
          'notas': _texto(notas),
        })
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Entrega.fromMap(Map<String, dynamic>.from(data));
  }

  /// Marca si la entrega es en otra localidad (genera desvío).
  Future<void> marcarOtraLocalidad({
    required String id,
    required bool valor,
  }) async {
    await _client
        .from('entregas')
        .update({'es_otra_localidad': valor}).eq('id', id);
  }

  /// Asigna la localidad del tabulador (y su distancia) a una entrega.
  Future<void> asignarLocalidad({
    required String id,
    required String localidad,
    double? distanciaKm,
  }) async {
    await _client.from('entregas').update({
      'localidad': localidad,
      'localidad_distancia_km': distanciaKm,
    }).eq('id', id);
  }

  /// Marca una entrega como "más lejana" (exclusiva por manifiesto).
  Future<void> marcarMasLejana({
    required String id,
    required String manifiestoId,
    required bool valor,
  }) async {
    if (valor) {
      // Solo una por manifiesto: limpia las demás y marca esta.
      await _client
          .from('entregas')
          .update({'es_mas_lejana': false})
          .eq('manifiesto_id', manifiestoId);
    }
    await _client
        .from('entregas')
        .update({'es_mas_lejana': valor}).eq('id', id);
  }

  Future<Entrega> marcarFallido({required String id, String? notas}) async {
    final data = await _client
        .from('entregas')
        .update({
          'estado': EstadoEntrega.fallido.valor,
          'entregado_por': _client.auth.currentUser?.id,
          'notas': _texto(notas),
        })
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Entrega.fromMap(Map<String, dynamic>.from(data));
  }

  static String _fechaTexto(DateTime fecha) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }

  static String? _texto(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
