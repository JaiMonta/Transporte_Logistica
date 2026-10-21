import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fletes/models/tabulador_flete.dart';
import '../models/manifiesto.dart';
import '../services/calculo_destino.dart';

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
    Map<String, double> pesos = const {},
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
            .select('id, tipo, numero, cliente_id, cliente_texto, orden')
            as List<dynamic>;

        await _crearEntregas(
          manifiestoId: manifiestoId,
          lineasInsertadas: insertadas
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
      if (pesos.isNotEmpty) {
        await guardarPesos(manifiestoId: manifiestoId, pesos: pesos);
      }
      // Calcula el destino por geolocalización (queda pendiente de aprobación).
      await calcularDestino(manifiestoId: manifiestoId);
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
        'documento_tipo': (l['tipo'] as String?) ?? 'factura',
        'documento_numero': l['numero'],
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
  ///
  /// Solo escribe los campos que se pasan con valor; así no se borran por
  /// accidente el camión, la localidad o el costo de flete ya definidos.
  Future<Manifiesto> actualizarCabecera({
    required String id,
    String? camionId,
    String? localidadMasLejana,
    String? fletesTabuladorId,
    double? costoFlete,
    CotejoEstado? cotejo,
  }) async {
    final campos = <String, dynamic>{};
    if (camionId != null) campos['camion_id'] = camionId;
    if (localidadMasLejana != null) {
      campos['localidad_mas_lejana'] = localidadMasLejana;
    }
    if (fletesTabuladorId != null) {
      campos['fletes_tabulador_id'] = fletesTabuladorId;
    }
    if (costoFlete != null) campos['costo_flete'] = costoFlete;
    if (cotejo != null) campos['cotejo'] = cotejo.valor;
    if (campos.isEmpty) {
      final actual = await obtener(id);
      if (actual != null) return actual;
    }
    final data = await _client
        .from('manifiestos')
        .update(campos)
        .eq('id', id)
        .select(_seleccion)
        .single();
    return Manifiesto.fromMap(Map<String, dynamic>.from(data));
  }

  /// Calcula el destino del manifiesto por geolocalización.
  ///
  /// Asigna a cada entrega su localidad más cercana, marca el desvío y deja
  /// el destino calculado en estado `pendiente` (salvo que ya esté aprobado y
  /// [sobrescribirAprobado] sea falso).
  Future<ResultadoDestino> calcularDestino({
    required String manifiestoId,
    bool sobrescribirAprobado = false,
  }) async {
    final man = await _client
        .from('manifiestos')
        .select('destino_estado')
        .eq('id', manifiestoId)
        .maybeSingle();
    final estado = DestinoEstado.desde(man?['destino_estado'] as String?);
    if (!sobrescribirAprobado && estado.esFacturable) {
      return const ResultadoDestino();
    }

    final entregasData = await _client
        .from('entregas')
        .select('id, lat, lng, orden')
        .eq('manifiesto_id', manifiestoId)
        .order('orden', ascending: true) as List<dynamic>;
    final tabuladorData = await _client
        .from('fletes_tabulador')
        .select('id, localidad, km, lat, lng') as List<dynamic>;
    final tabulador = [
      for (final e in tabuladorData)
        TabuladorFlete.fromMap(Map<String, dynamic>.from(e as Map)),
    ];
    final origen = await _origen();

    final puntos = [
      for (final e in entregasData)
        PuntoCliente(
          id: (e as Map)['id'] as String,
          lat: _doble(e['lat']),
          lng: _doble(e['lng']),
        ),
    ];
    final resultado = CalculoDestino.calcular(
      puntos: puntos,
      tabulador: tabulador,
      origenLat: origen.$1,
      origenLng: origen.$2,
    );

    // Refleja el cálculo en cada entrega.
    String? idMasLejana;
    for (final de in resultado.entregas) {
      await _client.from('entregas').update({
        'localidad_calculada': de.localidad,
        'localidad': de.localidad,
        'localidad_distancia_km': de.distanciaKm,
        'es_otra_localidad': de.esOtraLocalidad,
      }).eq('id', de.id);
      if (idMasLejana == null &&
          de.localidad != null &&
          de.localidad == resultado.destino) {
        idMasLejana = de.id;
      }
    }
    await _client
        .from('entregas')
        .update({'es_mas_lejana': false}).eq('manifiesto_id', manifiestoId);
    if (idMasLejana != null) {
      await _client
          .from('entregas')
          .update({'es_mas_lejana': true}).eq('id', idMasLejana);
    }

    await _client.from('manifiestos').update({
      'destino_calculado': resultado.destino,
      'destino_calculado_km': resultado.destinoKm,
      'destino_estado':
          resultado.calculado ? 'pendiente' : 'sin_calcular',
    }).eq('id', manifiestoId);

    return resultado;
  }

  /// Fija el destino aprobado (o corregido) por el administrador.
  Future<void> fijarDestinoAprobado({
    required String id,
    required TabuladorFlete flete,
    double? costoFlete,
    bool corregido = false,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('manifiestos').update({
      'destino_aprobado': flete.localidad,
      'destino_estado': corregido ? 'corregido' : 'aprobado',
      'destino_aprobado_por': uid,
      'destino_aprobado_en': DateTime.now().toUtc().toIso8601String(),
      'localidad_mas_lejana': flete.localidad,
      'fletes_tabulador_id': flete.id,
      'costo_flete': costoFlete,
    }).eq('id', id);

    // La entrega que coincide con el destino define el flete.
    await _client
        .from('entregas')
        .update({'es_mas_lejana': false}).eq('manifiesto_id', id);
    final entregas = await _client
        .from('entregas')
        .select('id, localidad')
        .eq('manifiesto_id', id) as List<dynamic>;
    for (final e in entregas) {
      final loc = ((e as Map)['localidad'] as String?)?.trim().toUpperCase();
      if (loc == flete.localidad.trim().toUpperCase()) {
        await _client
            .from('entregas')
            .update({'es_mas_lejana': true}).eq('id', e['id']);
        break;
      }
    }
  }

  /// Coordenadas del origen de carga (configuración), con Maracay por defecto.
  Future<(double, double)> _origen() async {
    final data = await _client
        .from('configuracion')
        .select('clave, valor')
        .inFilter('clave', ['origen_carga_lat', 'origen_carga_lng'])
        as List<dynamic>;
    var lat = 10.2469;
    var lng = -67.5958;
    for (final e in data) {
      final m = Map<String, dynamic>.from(e as Map);
      final v = double.tryParse('${m['valor']}');
      if (v == null) continue;
      if (m['clave'] == 'origen_carga_lat') lat = v;
      if (m['clave'] == 'origen_carga_lng') lng = v;
    }
    return (lat, lng);
  }

  /// Marca el manifiesto como servicio de fin de semana.
  Future<void> marcarFinSemana({
    required String id,
    required bool valor,
  }) async {
    await _client
        .from('manifiestos')
        .update({'es_fin_semana': valor}).eq('id', id);
  }

  /// Pesos (kg) por producto de un manifiesto, en `{producto_id: kg}`.
  Future<Map<String, double>> pesosDeManifiesto(String manifiestoId) async {
    final data = await _client
        .from('manifiesto_pesos')
        .select('producto_id, kg')
        .eq('manifiesto_id', manifiestoId) as List<dynamic>;
    final mapa = <String, double>{};
    for (final e in data) {
      final m = Map<String, dynamic>.from(e as Map);
      final kg = m['kg'];
      mapa[m['producto_id'] as String] =
          kg is num ? kg.toDouble() : double.tryParse('$kg') ?? 0;
    }
    return mapa;
  }

  /// Guarda (upsert) los pesos por producto de un manifiesto.
  ///
  /// Solo escribe los productos presentes en [pesos]; los que lleguen con kg 0
  /// se guardan igual (permite dejar constancia de que se revisó).
  Future<void> guardarPesos({
    required String manifiestoId,
    required Map<String, double> pesos,
  }) async {
    if (pesos.isEmpty) return;
    final filas = [
      for (final e in pesos.entries)
        {
          'manifiesto_id': manifiestoId,
          'producto_id': e.key,
          'kg': e.value,
        },
    ];
    await _client
        .from('manifiesto_pesos')
        .upsert(filas, onConflict: 'manifiesto_id,producto_id');
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

  static double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  static String _fechaTexto(DateTime fecha) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }
}
