import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fletes/models/extra.dart';
import '../../fletes/models/tabulador_flete.dart';
import '../../fletes/services/calculo_flete.dart';
import '../../fletes/services/calculo_extras.dart';
import '../services/calculo_factura_semanal.dart';
import '../models/factura.dart';

/// Acceso y generación de la facturación semanal (PostgREST, RLS solo admin).
class FacturacionRepository {
  FacturacionRepository(this._client);

  final SupabaseClient _client;

  static const String _seleccion = '*, factura_items(*)';

  Future<List<Factura>> listarPorLapso(DateTime desde, DateTime hasta) async {
    final data = await _client
        .from('facturas')
        .select(_seleccion)
        .gte('periodo_inicio', _fechaTexto(desde))
        .lte('periodo_inicio', _fechaTexto(hasta))
        .order('periodo_inicio', ascending: false) as List<dynamic>;
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

  /// Genera (o rehace) la factura de la semana que contiene [dia].
  Future<Factura> generarSemana(DateTime dia) async {
    final semana = SemanaRange.deFecha(dia);

    // Manifiestos con al menos una entrega 'entregado' en el período,
    // identificados por la fecha de entrega.
    final entregas = await _client
        .from('entregas')
        .select('manifiesto_id, entregado_en')
        .eq('estado', 'entregado')
        .gte('entregado_en', '${_fechaTexto(semana.inicio)}T00:00:00')
        .lte('entregado_en', '${_fechaTexto(semana.fin)}T23:59:59') as List<dynamic>;

    final idsManifiestos = <String>{};
    for (final e in entregas) {
      final mid = (e as Map)['manifiesto_id'] as String?;
      if (mid != null) idsManifiestos.add(mid);
    }

    final resumen = await _resumenDeManifiestos(idsManifiestos.toList());

    // Upsert de la cabecera del período.
    final facturaRow = await _client
        .from('facturas')
        .upsert({
          'periodo_inicio': _fechaTexto(semana.inicio),
          'periodo_fin': _fechaTexto(semana.fin),
          'subtotal_flete': resumen.subtotalFlete,
          'subtotal_extras': resumen.subtotalExtras,
          'total': resumen.total,
          'estado': 'emitida',
        }, onConflict: 'periodo_inicio,periodo_fin')
        .select('id')
        .single();

    final facturaId = facturaRow['id'] as String;

    // Rehacer: eliminar los ítems previos y volver a insertarlos.
    await _client.from('factura_items').delete().eq('factura_id', facturaId);

    if (resumen.items.isNotEmpty) {
      await _client.from('factura_items').insert([
        for (final it in resumen.items)
          {
            'factura_id': facturaId,
            'manifiesto_id': it.manifiestoId,
            'usuario_id': it.usuarioId,
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

  Future<ResumenFactura> _resumenDeManifiestos(List<String> ids) async {
    if (ids.isEmpty) {
      return CalculoFacturaSemanal.calcular(const []);
    }
    // Manifiestos con chofer, camión, localidad y flete guardado.
    final manis = await _client
        .from('manifiestos')
        .select(
          'id, capturado_por, costo_flete, camion_id, fletes_tabulador_id, es_fin_semana',
        )
        .inFilter('id', ids) as List<dynamic>;
    // Extras ya aprobados de esos manifiestos.
    final extras = await _client
        .from('manifiesto_extras')
        .select()
        .inFilter('manifiesto_id', ids) as List<dynamic>;
    // Entregas de esos manifiestos (para reparto/desvío/localidad).
    final entregas = await _client
        .from('entregas')
        .select(
          'manifiesto_id, estado, entregado_en, lat, lng, localidad, es_otra_localidad, es_mas_lejana',
        )
        .inFilter('manifiesto_id', ids) as List<dynamic>;

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

      // Localidades de las entregas de este manifiesto.
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

      facturables.add(ManifiestoFacturable(
        manifiestoId: id,
        usuarioId: map['capturado_por'] as String?,
        fleteBase: fleteBase,
        extras: extrasFinal,
      ));
    }
    return CalculoFacturaSemanal.calcular(facturables);
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
