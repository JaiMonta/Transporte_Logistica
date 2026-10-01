import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/combustible_jornada.dart';

/// Acceso a las jornadas y recargas de combustible (PostgREST, RLS).
class CombustibleRepository {
  CombustibleRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion = '*, combustible_recargas(*)';

  /// Jornada de un manifiesto (con recargas), o null si no existe.
  Future<CombustibleJornada?> porManifiesto(String manifiestoId) async {
    final data = await _client
        .from('combustible_jornadas')
        .select(_seleccion)
        .eq('manifiesto_id', manifiestoId)
        .maybeSingle();
    if (data == null) return null;
    return CombustibleJornada.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<CombustibleJornada>> listar({bool soloPendientes = false}) async {
    dynamic query =
        _client.from('combustible_jornadas').select(_seleccion);
    if (soloPendientes) {
      query = query.inFilter('estado', ['iniciada', 'en_recorrido', 'cerrada']);
    }
    final data = await query
        .order('iniciada_en', ascending: false) as List<dynamic>;
    return data
        .map((e) => CombustibleJornada.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Inicia la jornada registrando los litros iniciales.
  Future<CombustibleJornada> iniciar({
    required String manifiestoId,
    required double litrosIniciales,
    double? odometroInicial,
  }) async {
    final data = await _client
        .from('combustible_jornadas')
        .insert({
          'manifiesto_id': manifiestoId,
          'usuario_id': _client.auth.currentUser?.id,
          'litros_iniciales': litrosIniciales,
          'odometro_inicial': odometroInicial,
          'estado': EstadoCombustible.iniciada.valor,
        })
        .select(_seleccion)
        .single();
    return CombustibleJornada.fromMap(Map<String, dynamic>.from(data));
  }

  /// Registra una recarga durante el recorrido.
  Future<void> agregarRecarga({
    required String jornadaId,
    required double litros,
    double? monto,
    String? bucket,
    String? path,
    String? hashSha256,
  }) async {
    await _client.from('combustible_recargas').insert({
      'jornada_id': jornadaId,
      'usuario_id': _client.auth.currentUser?.id,
      'litros': litros,
      'monto': monto,
      'bucket': bucket,
      'path': path,
      'hash_sha256': hashSha256,
      'registrada_en': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> eliminarRecarga(String id) async {
    await _client.from('combustible_recargas').delete().eq('id', id);
  }

  /// Cierra la jornada con los litros finales y el cálculo.
  Future<CombustibleJornada> cerrar({
    required String jornadaId,
    required double litrosFinales,
    double? odometroFinal,
    required double kmRecorridos,
    required double consumoTeorico,
    required double consumoReal,
    required double rendimiento,
    String? notas,
  }) async {
    final data = await _client
        .from('combustible_jornadas')
        .update({
          'litros_finales': litrosFinales,
          'odometro_final': odometroFinal,
          'km_recorridos': kmRecorridos,
          'consumo_teorico_lt': consumoTeorico,
          'consumo_real_lt': consumoReal,
          'rendimiento_lt_km': rendimiento,
          'estado': EstadoCombustible.cerrada.valor,
          'cerrada_en': DateTime.now().toUtc().toIso8601String(),
          'notas': notas,
        })
        .eq('id', jornadaId)
        .select(_seleccion)
        .single();
    return CombustibleJornada.fromMap(Map<String, dynamic>.from(data));
  }

  /// Validación/corrección del administrador (inicial o final).
  Future<void> validar({
    required String jornadaId,
    double? litrosInicialesValidados,
    double? litrosFinalesValidados,
    bool marcarValidada = false,
  }) async {
    final cuerpo = <String, dynamic>{
      'litros_iniciales_validados': ?litrosInicialesValidados,
      'inicial_validado_por': ?(litrosInicialesValidados != null ? _uid : null),
      'inicial_validado_en': ?(litrosInicialesValidados != null
          ? DateTime.now().toUtc().toIso8601String()
          : null),
      'litros_finales_validados': ?litrosFinalesValidados,
      'final_validado_por': ?(litrosFinalesValidados != null ? _uid : null),
      'final_validado_en': ?(litrosFinalesValidados != null
          ? DateTime.now().toUtc().toIso8601String()
          : null),
      if (marcarValidada) 'estado': EstadoCombustible.validada.valor,
    };
    if (cuerpo.isEmpty) return;
    await _client
        .from('combustible_jornadas')
        .update(cuerpo)
        .eq('id', jornadaId);
  }

  String? get _uid => _client.auth.currentUser?.id;
}
