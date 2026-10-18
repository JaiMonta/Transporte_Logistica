import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fletes/models/extra.dart';
import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/services/calculo_flete.dart';
import '../../fletes/services/calculo_extras.dart';
import '../models/factura.dart';
import '../services/calculo_facturacion_empresas.dart';

/// Acceso y generación de la facturación por empresa (PostgREST, RLS admin).
///
/// Cada factura corresponde a un período (semana o rango) y a una empresa
/// facturada. El flete base y los extras se prorratean por producto según el
/// peso capturado en el manifiesto.
class FacturacionRepository {
  FacturacionRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion =
      '*, empresas(nombre), factura_items(*, productos(nombre))';

  Future<List<Factura>> listarPorLapso(DateTime desde, DateTime hasta) async {
    final data = await _client
        .from('facturas')
        .select(_seleccion)
        .gte('periodo_inicio', _fechaTexto(desde))
        .lte('periodo_inicio', _fechaTexto(hasta))
        .order('periodo_inicio', ascending: false)
        .order('empresa_id', ascending: true) as List<dynamic>;
    return data
        .map((e) => Factura.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Factura?> obtener(String id) async {
    final data = await _client
        .from('facturas')
        .select(_seleccion)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Factura.fromMap(Map<String, dynamic>.from(data));
  }

  /// Tasa configurada USD -> Bs (0 si no está definida).
  Future<double> tasaUsdBs() async {
    final data = await _client
        .from('configuracion')
        .select('valor')
        .eq('clave', 'tasa_usd_bs')
        .maybeSingle();
    if (data == null) return 0;
    return double.tryParse('${data['valor']}') ?? 0;
  }

  /// Genera (o rehace) las facturas por empresa del período [desde]-[hasta].
  ///
  /// Devuelve las facturas resultantes (una por empresa con ítems).
  Future<List<Factura>> generar(DateTime desde, DateTime hasta) async {
    // Manifiestos con al menos una entrega 'entregado' en el período,
    // identificados por la fecha de entrega.
    final entregas = await _client
        .from('entregas')
        .select('manifiesto_id, entregado_en')
        .eq('estado', 'entregado')
        .gte('entregado_en', '${_fechaTexto(desde)}T00:00:00')
        .lte('entregado_en', '${_fechaTexto(hasta)}T23:59:59') as List<dynamic>;

    final idsManifiestos = <String>{};
    for (final e in entregas) {
      final mid = (e as Map)['manifiesto_id'] as String?;
      if (mid != null) idsManifiestos.add(mid);
    }

    final calculadas = await _calcularFacturas(idsManifiestos.toList());

    final resultado = <Factura>[];
    for (final fc in calculadas) {
      resultado.add(await _guardarFactura(desde, hasta, fc));
    }
    return resultado;
  }

  Future<Factura> _guardarFactura(
    DateTime desde,
    DateTime hasta,
    FacturaEmpresaCalculada fc,
  ) async {
    // `empresa_id` nulo no es único en Postgres: limpia la factura sin empresa
    // del período antes de recrearla (evita duplicados al regenerar).
    if (fc.empresaId == null) {
      await _client
          .from('facturas')
          .delete()
          .eq('periodo_inicio', _fechaTexto(desde))
          .eq('periodo_fin', _fechaTexto(hasta))
          .isFilter('empresa_id', null);
    }

    dynamic q = _client
        .from('facturas')
        .select('id')
        .eq('periodo_inicio', _fechaTexto(desde))
        .eq('periodo_fin', _fechaTexto(hasta));
    q = fc.empresaId == null
        ? q.isFilter('empresa_id', null)
        : q.eq('empresa_id', fc.empresaId!);
    final existente = await q.maybeSingle();

    final cabecera = {
      'periodo_inicio': _fechaTexto(desde),
      'periodo_fin': _fechaTexto(hasta),
      'empresa_id': fc.empresaId,
      'subtotal_flete': fc.subtotalFlete,
      'subtotal_extras': fc.subtotalExtras,
      'total': fc.total,
    };

    final String facturaId;
    final existenteId = existente == null ? null : existente['id'] as String?;
    if (existenteId == null) {
      final row = await _client
          .from('facturas')
          .insert({...cabecera, 'estado': 'emitida'})
          .select('id')
          .single();
      facturaId = row['id'] as String;
    } else {
      facturaId = existenteId;
      await _client.from('facturas').update(cabecera).eq('id', facturaId);
      // Rehacer los ítems.
      await _client.from('factura_items').delete().eq('factura_id', facturaId);
    }

    if (fc.items.isNotEmpty) {
      await _client.from('factura_items').insert([
        for (final it in fc.items)
          {
            'factura_id': facturaId,
            'manifiesto_id': it.manifiestoId,
            'usuario_id': it.usuarioId,
            'producto_id': it.productoId,
            'concepto': it.concepto,
            'tipo': it.tipo?.valor,
            'descripcion': it.descripcion,
            'base': it.base,
            'porcentaje': it.porcentaje,
            'monto': it.monto,
            'orden': it.orden,
          },
      ]);
    }

    return (await obtener(facturaId))!;
  }

  Future<List<FacturaEmpresaCalculada>> _calcularFacturas(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];

    final manis = await _client
        .from('manifiestos')
        .select(
          'id, capturado_por, costo_flete, camion_id, fletes_tabulador_id, '
          'es_fin_semana',
        )
        .inFilter('id', ids) as List<dynamic>;

    final extras = await _client
        .from('manifiesto_extras')
        .select()
        .inFilter('manifiesto_id', ids) as List<dynamic>;

    final entregas = await _client
        .from('entregas')
        .select(
          'id, manifiesto_id, estado, entregado_en, lat, lng, localidad, '
          'es_otra_localidad, es_mas_lejana',
        )
        .inFilter('manifiesto_id', ids) as List<dynamic>;

    // Pesos capturados y catálogo de productos (con su empresa).
    final pesosFilas = await _client
        .from('manifiesto_pesos')
        .select('manifiesto_id, producto_id, kg')
        .inFilter('manifiesto_id', ids) as List<dynamic>;
    final productos = await _client
        .from('productos')
        .select('id, nombre, empresa_id, empresas(nombre)') as List<dynamic>;
    final productoInfo = <String, ({String nombre, String? empresaId, String? empresaNombre})>{};
    for (final p in productos) {
      final m = Map<String, dynamic>.from(p as Map);
      final emp = m['empresas'];
      productoInfo[m['id'] as String] = (
        nombre: (m['nombre'] as String?) ?? '',
        empresaId: m['empresa_id'] as String?,
        empresaNombre: emp is Map ? emp['nombre'] as String? : null,
      );
    }

    final pesosPorManifiesto = <String, List<PesoProducto>>{};
    for (final p in pesosFilas) {
      final m = Map<String, dynamic>.from(p as Map);
      final mid = m['manifiesto_id'] as String?;
      final pid = m['producto_id'] as String?;
      if (mid == null || pid == null) continue;
      final info = productoInfo[pid];
      final kg = m['kg'];
      pesosPorManifiesto.putIfAbsent(mid, () => []).add(PesoProducto(
            productoId: pid,
            productoNombre: info?.nombre ?? '',
            empresaId: info?.empresaId,
            empresaNombre: info?.empresaNombre,
            kg: kg is num ? kg.toDouble() : double.tryParse('$kg') ?? 0,
          ));
    }

    final extrasPorManifiesto = <String, List<Extra>>{};
    for (final e in extras) {
      final extra = Extra.fromMap(Map<String, dynamic>.from(e as Map));
      extrasPorManifiesto.putIfAbsent(extra.manifiestoId, () => []).add(extra);
    }
    final entregasPorManifiesto = <String, List<Map<String, dynamic>>>{};
    for (final e in entregas) {
      final map = Map<String, dynamic>.from(e as Map);
      final mid = map['manifiesto_id'] as String?;
      if (mid != null) {
        entregasPorManifiesto.putIfAbsent(mid, () => []).add(map);
      }
    }

    // Caché del tabulador completo (localidad → fila) para la más lejana.
    final tabuladorPorLocalidad = await _tabuladorPorLocalidad();
    final tarifasExtras = await _tarifasExtras();
    final capacidadesCamion = <String, double?>{};

    final facturables = <ManifiestoFacturable>[];
    for (final m in manis) {
      final map = Map<String, dynamic>.from(m as Map);
      final id = map['id'] as String;
      final camId = map['camion_id'] as String?;

      double? capacidad;
      if (camId != null) {
        capacidad = capacidadesCamion.containsKey(camId)
            ? capacidadesCamion[camId]
            : capacidadesCamion[camId] = await _capacidadCamion(camId);
      }

      final ents = entregasPorManifiesto[id] ?? const [];

      // Localidad más lejana: la marcada por el admin, o la de mayor km.
      TabuladorFlete? masLejana;
      final marcada = ents.firstWhere(
        (e) => (e['es_mas_lejana'] as bool?) ?? false,
        orElse: () => const {},
      );
      final localidadMarcada = (marcada['localidad'] as String?)?.trim();
      if (localidadMarcada != null && localidadMarcada.isNotEmpty) {
        masLejana = tabuladorPorLocalidad[localidadMarcada.toUpperCase()];
      }
      if (masLejana == null) {
        for (final e in ents) {
          final loc = (e['localidad'] as String?)?.trim();
          if (loc == null || loc.isEmpty) continue;
          final fila = tabuladorPorLocalidad[loc.toUpperCase()];
          if (fila == null) continue;
          if (masLejana == null || (fila.km ?? 0) > (masLejana.km ?? 0)) {
            masLejana = fila;
          }
        }
      }

      // Flete base: tabulador de la localidad más lejana × capacidad.
      double fleteBase = (map['costo_flete'] as num?)?.toDouble() ?? 0;
      if (masLejana != null) {
        final calc = CalculoFlete.precioFlete(
          tabulador: masLejana,
          capacidadKg: capacidad,
        );
        if (calc != null) fleteBase = calc;
      } else if (fleteBase <= 0 && map['fletes_tabulador_id'] != null) {
        final tab = await _obtenerTabulador(map['fletes_tabulador_id'] as String);
        fleteBase = CalculoFlete.precioFlete(
              tabulador: tab,
              capacidadKg: capacidad,
            ) ??
            0;
      }

      // Extras automáticos sugeridos (caleta, reparto, desvío, fin de semana).
      final automaticos = _extrasAutomaticos(
        manifiestoId: id,
        entregas: ents,
        fleteBase: fleteBase,
        capacidadKg: capacidad,
        esFinSemana: (map['es_fin_semana'] as bool?) ?? false,
        tarifas: tarifasExtras,
      );

      // Extras aprobados guardados + automáticos (sin duplicar tipo automático).
      final guardados = extrasPorManifiesto[id] ?? const <Extra>[];
      final tiposGuardados = guardados.map((e) => e.tipo).toSet();
      final extrasFinal = [
        ...guardados,
        for (final a in automaticos)
          if (!tiposGuardados.contains(a.tipo)) a,
      ];

      final conceptos = [
        for (final e in extrasFinal)
          if (e.estado == EstadoExtra.aprobado)
            ConceptoExtra(
              concepto: e.tipo.valor,
              monto: e.monto,
              tipo: e.tipo,
              descripcion: e.descripcion,
              base: e.base,
              porcentaje: e.porcentaje,
            ),
      ];

      facturables.add(ManifiestoFacturable(
        manifiestoId: id,
        usuarioId: map['capturado_por'] as String?,
        fleteBase: fleteBase,
        capacidadKg: capacidad,
        pesos: pesosPorManifiesto[id] ?? const [],
        extras: conceptos,
      ));
    }

    return CalculoFacturacionEmpresas.calcular(facturables);
  }

  /// Genera extras automáticos (aprobados) a partir de las reglas del negocio:
  /// caleta (2 × tarifa), reparto (grupos ≤ radio) y desvío (otra localidad).
  List<Extra> _extrasAutomaticos({
    required String manifiestoId,
    required List<Map<String, dynamic>> entregas,
    required double fleteBase,
    required double? capacidadKg,
    required bool esFinSemana,
    required List<Map<String, dynamic>> tarifas,
  }) {
    final out = <Extra>[];
    final t = _tarifaPorCapacidad(tarifas, capacidadKg);

    // Caleta: 2 por manifiesto.
    if (t.caleta > 0) {
      out.add(Extra(
        id: '',
        manifiestoId: manifiestoId,
        tipo: TipoExtra.caleta,
        descripcion: '2 por guía de carga',
        base: t.caleta,
        monto: t.caleta * 2,
        estado: EstadoExtra.aprobado,
        origen: 'auto',
      ));
    }

    // Reparto: agrupa entregas por coords a <= radio.
    final puntos = [
      for (final e in entregas)
        PuntoEntrega(
          id: (e['id'] as String?) ?? '',
          lat: (e['lat'] as num?)?.toDouble(),
          lng: (e['lng'] as num?)?.toDouble(),
        ),
    ];
    final nRepartos = CalculoExtras.repartos(puntos);
    if (nRepartos > 0 && t.reparto > 0) {
      out.add(Extra(
        id: '',
        manifiestoId: manifiestoId,
        tipo: TipoExtra.reparto,
        descripcion: '$nRepartos reparto(s)',
        base: t.reparto,
        monto: t.reparto * nRepartos,
        estado: EstadoExtra.aprobado,
        origen: 'auto',
      ));
    }

    // Desvío: entregas marcadas "otra localidad".
    final nDesvio =
        entregas.where((e) => (e['es_otra_localidad'] as bool?) ?? false).length;
    final montoDesvio = CalculoExtras.desvio(capacidadKg, fleteBase, nDesvio);
    if (montoDesvio > 0) {
      out.add(Extra(
        id: '',
        manifiestoId: manifiestoId,
        tipo: TipoExtra.desvio,
        descripcion: '$nDesvio desvío(s) a otra localidad',
        base: fleteBase,
        monto: montoDesvio,
        estado: EstadoExtra.aprobado,
        origen: 'auto',
      ));
    }

    // Fin de semana.
    if (esFinSemana) {
      out.add(Extra(
        id: '',
        manifiestoId: manifiestoId,
        tipo: TipoExtra.finSemana,
        descripcion: 'Servicio en fin de semana (5%)',
        base: fleteBase,
        monto: CalculoExtras.finDeSemana(fleteBase),
        porcentaje: 5,
        estado: EstadoExtra.aprobado,
        origen: 'auto',
      ));
    }
    return out;
  }

  ({double caleta, double reparto}) _tarifaPorCapacidad(
    List<Map<String, dynamic>> tarifas,
    double? capacidadKg,
  ) {
    final ton = (capacidadKg ?? 0) / 1000;
    Map<String, dynamic>? elegida;
    var mejor = double.infinity;
    for (final f in tarifas) {
      final c = (f['capacidad_t'] as num?)?.toDouble() ?? 0;
      if (ton <= c && c - ton < mejor) {
        mejor = c - ton;
        elegida = f;
      }
    }
    elegida ??= tarifas.isNotEmpty ? tarifas.first : null;
    double num0(Object? v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll('%', '').replaceAll(',', '.')) ?? 0;
    }
    return (
      caleta: num0(elegida?['caleta']),
      reparto: num0(elegida?['reparto']),
    );
  }

  Future<List<Map<String, dynamic>>> _tarifasExtras() async {
    final data = await _client.from('fletes_extras').select() as List<dynamic>;
    return [for (final e in data) Map<String, dynamic>.from(e as Map)];
  }

  Future<Map<String, TabuladorFlete>> _tabuladorPorLocalidad() async {
    final data = await _client.from('fletes_tabulador').select() as List<dynamic>;
    final mapa = <String, TabuladorFlete>{};
    for (final e in data) {
      final f = TabuladorFlete.fromMap(Map<String, dynamic>.from(e as Map));
      mapa[f.localidad.toUpperCase()] = f;
    }
    return mapa;
  }

  Future<TabuladorFlete?> _obtenerTabulador(String id) async {
    final data = await _client
        .from('fletes_tabulador')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return TabuladorFlete.fromMap(Map<String, dynamic>.from(data));
  }

  Future<double?> _capacidadCamion(String id) async {
    final data = await _client
        .from('camiones')
        .select('capacidad_kg')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return (data['capacidad_kg'] as num?)?.toDouble();
  }

  Future<void> cambiarEstado({
    required String id,
    required EstadoFactura estado,
  }) async {
    await _client.from('facturas').update({'estado': estado.valor}).eq('id', id);
  }

  static String _fechaTexto(DateTime fecha) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }
}
