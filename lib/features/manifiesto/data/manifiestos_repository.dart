import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/manifiesto.dart';

/// Acceso a los manifiestos capturados.
///
/// Lecturas y escrituras directas a PostgREST (protegidas por RLS):
/// el chofer solo ve y crea los suyos; el administrador gestiona todo.
class ManifiestosRepository {
  ManifiestosRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion =
      '*, clientes(nombre), profiles(nombre, email)';

  Future<List<Manifiesto>> listar({
    String busqueda = '',
    DateTime? desde,
    DateTime? hasta,
  }) async {
    dynamic query = _client.from('manifiestos').select(_seleccion);

    final termino = busqueda.trim().replaceAll(RegExp(r'[(),%]'), '');
    if (termino.isNotEmpty) {
      query = query.ilike('numero_pro', '%$termino%');
    }
    if (desde != null) {
      query = query.gte('fecha', _fechaTexto(desde));
    }
    if (hasta != null) {
      query = query.lte('fecha', _fechaTexto(hasta));
    }

    final data = await query
        .order('fecha', ascending: false)
        .order('created_at', ascending: false) as List<dynamic>;
    return data
        .map((e) => Manifiesto.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Manifiesto?> obtener(String id) async {
    final data = await _client
        .from('manifiestos')
        .select(_seleccion)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Manifiesto.fromMap(Map<String, dynamic>.from(data));
  }

  /// ¿Ya existe un manifiesto con ese PRO, cliente y fecha?
  Future<bool> existePro({
    required String numeroPro,
    required DateTime fecha,
    String? clienteId,
    String? excluirId,
  }) async {
    final numero = numeroPro.trim();
    if (numero.isEmpty) return false;

    dynamic query = _client
        .from('manifiestos')
        .select('id')
        .ilike('numero_pro', numero)
        .eq('fecha', _fechaTexto(fecha));
    query = clienteId == null
        ? query.isFilter('cliente_id', null)
        : query.eq('cliente_id', clienteId);
    if (excluirId != null) {
      query = query.neq('id', excluirId);
    }

    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  Future<Manifiesto> crear({
    required String numeroPro,
    required DateTime fecha,
    String? clienteId,
    String? bucket,
    String? path,
    String? hashSha256,
    String? ocrPro,
    double? ocrConfianza,
    CotejoEstado cotejo = CotejoEstado.pendiente,
  }) async {
    final uid = _client.auth.currentUser?.id;
    final data = await _client
        .from('manifiestos')
        .insert({
          'numero_pro': numeroPro.trim(),
          'fecha': _fechaTexto(fecha),
          'cliente_id': clienteId,
          'capturado_por': uid,
          'bucket': bucket,
          'path': path,
          'hash_sha256': hashSha256,
          'ocr_pro': ocrPro,
          'ocr_confianza': ocrConfianza,
          'cotejo': cotejo.valor,
        })
        .select(_seleccion)
        .single();
    return Manifiesto.fromMap(Map<String, dynamic>.from(data));
  }

  static String _fechaTexto(DateTime fecha) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }
}
