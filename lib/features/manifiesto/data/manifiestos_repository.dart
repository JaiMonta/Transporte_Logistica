import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/manifiesto.dart';

/// Acceso a los manifiestos (cabecera + líneas).
///
/// Lecturas y escrituras directas a PostgREST (protegidas por RLS):
/// el chofer solo ve y crea los suyos; el administrador gestiona todo.
class ManifiestosRepository {
  ManifiestosRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion =
      '*, profiles(nombre, email), camiones(marca, placa), '
      'manifiesto_lineas(*, clientes(nombre))';

  Future<List<Manifiesto>> listar({
    String busqueda = '',
    DateTime? desde,
    DateTime? hasta,
  }) async {
    dynamic query = _client.from('manifiestos').select(_seleccion);

    final termino = busqueda.trim().replaceAll(RegExp(r'[(),%]'), '');
    if (termino.isNotEmpty) {
      // Busca manifiestos que tengan una línea cuyo número coincida.
      final coincidencias = await _client
          .from('manifiesto_lineas')
          .select('manifiesto_id')
          .ilike('numero', '%$termino%') as List<dynamic>;
      final ids = coincidencias
          .map((e) => (e as Map)['manifiesto_id'] as String)
          .toSet()
          .toList();
      if (ids.isEmpty) return [];
      query = query.inFilter('id', ids);
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

  /// ¿Ya existe una línea con ese tipo y número en un manifiesto de esa fecha?
  ///
  /// La unicidad se valida en la app (no hay índice único en la base).
  Future<bool> existeDocumento({
    required TipoDocumento tipo,
    required String numero,
    required DateTime fecha,
    String? excluirLineaId,
  }) async {
    final n = numero.trim();
    if (n.isEmpty) return false;

    // IDs de manifiestos de esa fecha.
    final manis = await _client
        .from('manifiestos')
        .select('id')
        .eq('fecha', _fechaTexto(fecha)) as List<dynamic>;
    final ids = manis.map((e) => (e as Map)['id'] as String).toList();
    if (ids.isEmpty) return false;

    dynamic query = _client
        .from('manifiesto_lineas')
        .select('id')
        .eq('tipo', tipo.valor)
        .ilike('numero', n)
        .inFilter('manifiesto_id', ids);
    if (excluirLineaId != null) {
      query = query.neq('id', excluirLineaId);
    }
    final data = await query.limit(1) as List<dynamic>;
    return data.isNotEmpty;
  }

  /// Crea la cabecera y sus líneas. Devuelve el manifiesto creado.
  Future<Manifiesto> crear({
    required DateTime fecha,
    required List<ManifiestoLinea> lineas,
    String? camionId,
    String? bucket,
    String? path,
    String? hashSha256,
    double? ocrConfianza,
    CotejoEstado cotejo = CotejoEstado.pendiente,
  }) async {
    final uid = _client.auth.currentUser?.id;
    final cabecera = await _client
        .from('manifiestos')
        .insert({
          'fecha': _fechaTexto(fecha),
          'capturado_por': uid,
          'camion_id': camionId,
          'bucket': bucket,
          'path': path,
          'hash_sha256': hashSha256,
          'ocr_confianza': ocrConfianza,
          'cotejo': cotejo.valor,
        })
        .select('id')
        .single();

    final manifiestoId = cabecera['id'] as String;
    try {
      if (lineas.isNotEmpty) {
        final filas = [
          for (var i = 0; i < lineas.length; i++)
            lineas[i].copyWith(orden: i).aCuerpo(manifiestoId: manifiestoId),
        ];
        // Insertar líneas y recuperar sus ids para crear las entregas.
        final insertadas = await _client
            .from('manifiesto_lineas')
            .insert(filas)
            .select('id, cliente_id, cliente_texto, orden') as List<dynamic>;

        await _crearEntregas(
          manifiestoId: manifiestoId,
          lineasInsertadas: insertadas
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (e) {
      // No dejar una cabecera huérfana si fallan las líneas/entregas.
      await _client.from('manifiestos').delete().eq('id', manifiestoId);
      rethrow;
    }

    final creado = await obtener(manifiestoId);
    return creado ??
        Manifiesto(id: manifiestoId, fecha: fecha, lineas: lineas);
  }

  /// Crea una entrega por cada línea, heredando cliente y coordenadas.
  Future<void> _crearEntregas({
    required String manifiestoId,
    required List<Map<String, dynamic>> lineasInsertadas,
  }) async {
    // Coordenadas de los clientes referenciados (si son de catálogo).
    final idsClientes = lineasInsertadas
        .map((l) => l['cliente_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final datosClientes = <String, Map<String, dynamic>>{};
    if (idsClientes.isNotEmpty) {
      final clientes = await _client
          .from('clientes')
          .select('id, direccion, lat, lng')
          .inFilter('id', idsClientes) as List<dynamic>;
      for (final c in clientes) {
        final m = Map<String, dynamic>.from(c as Map);
        datosClientes[m['id'] as String] = m;
      }
    }

    final entregas = <Map<String, dynamic>>[];
    for (final l in lineasInsertadas) {
      final clienteId = l['cliente_id'] as String?;
      final cliente = clienteId == null ? null : datosClientes[clienteId];
      entregas.add({
        'manifiesto_id': manifiestoId,
        'linea_id': l['id'],
        'cliente_id': clienteId,
        'cliente_texto': l['cliente_texto'],
        'direccion': cliente?['direccion'],
        'lat': cliente?['lat'],
        'lng': cliente?['lng'],
        'orden': l['orden'] ?? 0,
        'estado': 'pendiente',
      });
    }

    if (entregas.isNotEmpty) {
      await _client.from('entregas').insert(entregas);
    }
  }

  /// Actualiza datos de cabecera que gestiona el administrador.
  Future<Manifiesto> actualizarCabecera({
    required String id,
    String? camionId,
    String? localidadMasLejana,
    double? costoFlete,
    CotejoEstado? cotejo,
  }) async {
    final data = await _client
        .from('manifiestos')
        .update({
          'camion_id': camionId,
          'localidad_mas_lejana': localidadMasLejana,
          'costo_flete': costoFlete,
          if (cotejo != null) 'cotejo': cotejo.valor,
        })
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Manifiesto.fromMap(Map<String, dynamic>.from(data));
  }

  /// Purga manifiestos validados más antiguos que la retención.
  ///
  /// `dryRun = true` solo cuenta. Devuelve cuántos (se) borrarían.
  Future<int> purgarAntiguos({int? dias, bool dryRun = false}) async {
    final r = await _client.rpc(
      'purgar_manifiestos_antiguos',
      params: {'p_dias': dias, 'p_dry_run': dryRun},
    );
    return (r as num?)?.toInt() ?? 0;
  }

  static String _fechaTexto(DateTime fecha) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }
}
