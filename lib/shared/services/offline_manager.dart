import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Estado de un elemento de la cola local de sincronización.
enum EstadoCola {
  pendiente,
  subiendo,
  fallido,
  completado;

  static EstadoCola desde(String? valor) => switch (valor) {
        'subiendo' => EstadoCola.subiendo,
        'fallido' => EstadoCola.fallido,
        'completado' => EstadoCola.completado,
        _ => EstadoCola.pendiente,
      };

  String get valor => name;
}

/// Acción a replicar en el servidor cuando vuelva la conexión.
enum AccionSync {
  crear,
  actualizar,
  eliminar;

  static AccionSync desde(String? valor) => switch (valor) {
        'actualizar' => AccionSync.actualizar,
        'eliminar' => AccionSync.eliminar,
        _ => AccionSync.crear,
      };

  String get valor => name;
}

/// Un elemento de la cola local.
class ElementoCola {
  const ElementoCola({
    this.id,
    required this.entidad,
    required this.entidadId,
    required this.accion,
    this.payload = const {},
    this.estado = EstadoCola.pendiente,
    this.intentos = 0,
    this.ultimoError,
  });

  final int? id;
  final String entidad;
  final String entidadId;
  final AccionSync accion;
  final Map<String, dynamic> payload;
  final EstadoCola estado;
  final int intentos;
  final String? ultimoError;

  /// Clave lógica idempotente (misma que usa sync_events en el servidor).
  String get claveIdempotencia => '$entidad|$entidadId|${accion.valor}';

  ElementoCola copyWith({
    int? id,
    EstadoCola? estado,
    int? intentos,
    String? ultimoError,
  }) =>
      ElementoCola(
        id: id ?? this.id,
        entidad: entidad,
        entidadId: entidadId,
        accion: accion,
        payload: payload,
        estado: estado ?? this.estado,
        intentos: intentos ?? this.intentos,
        ultimoError: ultimoError ?? this.ultimoError,
      );

  Map<String, Object?> aFila() => {
        if (id != null) 'id': id,
        'entidad': entidad,
        'entidad_id': entidadId,
        'accion': accion.valor,
        'payload': jsonEncode(payload),
        'estado': estado.valor,
        'intentos': intentos,
        'ultimo_error': ultimoError,
      };

  factory ElementoCola.desdeFila(Map<String, Object?> fila) => ElementoCola(
        id: fila['id'] as int?,
        entidad: fila['entidad'] as String,
        entidadId: fila['entidad_id'] as String,
        accion: AccionSync.desde(fila['accion'] as String?),
        payload: _decodificar(fila['payload'] as String?),
        estado: EstadoCola.desde(fila['estado'] as String?),
        intentos: (fila['intentos'] as int?) ?? 0,
        ultimoError: fila['ultimo_error'] as String?,
      );

  static Map<String, dynamic> _decodificar(String? texto) {
    if (texto == null || texto.isEmpty) return const {};
    final valor = jsonDecode(texto);
    return valor is Map ? Map<String, dynamic>.from(valor) : const {};
  }
}

/// Una posición capturada sin conexión (búfer GPS).
class PuntoGps {
  const PuntoGps({
    this.id,
    required this.lat,
    required this.lng,
    this.precision,
    this.capturadoEn,
    this.enviado = false,
  });

  final int? id;
  final double lat;
  final double lng;
  final double? precision;
  final DateTime? capturadoEn;
  final bool enviado;

  Map<String, Object?> aFila() => {
        if (id != null) 'id': id,
        'lat': lat,
        'lng': lng,
        'precision': precision,
        'capturado_en': (capturadoEn ?? DateTime.now()).toIso8601String(),
        'enviado': enviado ? 1 : 0,
      };

  factory PuntoGps.desdeFila(Map<String, Object?> fila) => PuntoGps(
        id: fila['id'] as int?,
        lat: (fila['lat'] as num).toDouble(),
        lng: (fila['lng'] as num).toDouble(),
        precision: (fila['precision'] as num?)?.toDouble(),
        capturadoEn: DateTime.tryParse(fila['capturado_en'] as String? ?? ''),
        enviado: (fila['enviado'] as int? ?? 0) == 1,
      );
}

/// Administra la base de datos local de la cola offline y el búfer GPS.
///
/// Solo se inicializa en móvil (Android/iOS). En web se comporta como un
/// no-op: el panel administrativo trabaja siempre en línea.
class OfflineManager {
  OfflineManager();

  static const String _nombreDb = 'logistica_offline.db';
  static const int _version = 1;

  Database? _db;
  bool _inicializado = false;

  bool get disponible => !kIsWeb;

  /// Abre (o crea) la base local. En web retorna sin hacer nada.
  Future<void> inicializar() async {
    if (!disponible || _inicializado) return;
    final ruta = p.join(await getDatabasesPath(), _nombreDb);
    _db = await openDatabase(
      ruta,
      version: _version,
      onCreate: _crearEsquema,
    );
    _inicializado = true;
  }

  Future<void> _crearEsquema(Database db, int version) async {
    await db.execute('''
      create table offline_queue (
        id integer primary key autoincrement,
        entidad text not null,
        entidad_id text not null,
        accion text not null,
        payload text not null default '{}',
        estado text not null default 'pendiente',
        intentos integer not null default 0,
        ultimo_error text,
        created_at text not null default (datetime('now'))
      )
    ''');
    await db.execute('''
      create unique index if not exists offline_queue_unico
        on offline_queue (entidad, entidad_id, accion)
    ''');
    await db.execute('''
      create table gps_buffer (
        id integer primary key autoincrement,
        lat real not null,
        lng real not null,
        precision real,
        capturado_en text not null,
        enviado integer not null default 0
      )
    ''');
  }

  /// Encola una operación. Es idempotente por (entidad, entidad_id, acción).
  Future<void> encolar(ElementoCola elemento) async {
    if (!disponible) return;
    await inicializar();
    await _db!.insert(
      'offline_queue',
      elemento.aFila(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Todos los elementos pendientes o fallidos (candidatos a reintento).
  Future<List<ElementoCola>> pendientes() async {
    if (!disponible) return const [];
    await inicializar();
    final filas = await _db!.query(
      'offline_queue',
      where: "estado in ('pendiente','fallido','subiendo')",
      orderBy: 'id asc',
    );
    return filas.map(ElementoCola.desdeFila).toList();
  }

  /// Cuántos elementos faltan por sincronizar.
  Future<int> contadorPendientes() async {
    if (!disponible) return 0;
    await inicializar();
    final resultado = await _db!.rawQuery(
      "select count(*) as total from offline_queue "
      "where estado in ('pendiente','fallido','subiendo')",
    );
    return (resultado.first['total'] as int?) ?? 0;
  }

  /// Marca el estado de un elemento tras un intento de sincronización.
  Future<void> marcarEstado(
    int id,
    EstadoCola estado, {
    int? intentos,
    String? ultimoError,
  }) async {
    if (!disponible) return;
    await inicializar();
    await _db!.update(
      'offline_queue',
      {
        'estado': estado.valor,
        'intentos': ?intentos,
        'ultimo_error': ultimoError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina un elemento ya sincronizado.
  Future<void> eliminarElemento(int id) async {
    if (!disponible) return;
    await inicializar();
    await _db!.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Guarda una posición GPS para enviarla al reconectar.
  Future<void> guardarPunto(PuntoGps punto) async {
    if (!disponible) return;
    await inicializar();
    await _db!.insert('gps_buffer', punto.aFila());
  }

  /// Posiciones GPS aún no enviadas.
  Future<List<PuntoGps>> puntosPendientes() async {
    if (!disponible) return const [];
    await inicializar();
    final filas = await _db!.query(
      'gps_buffer',
      where: 'enviado = 0',
      orderBy: 'id asc',
    );
    return filas.map(PuntoGps.desdeFila).toList();
  }

  Future<void> marcarPuntosEnviados(List<int> ids) async {
    if (!disponible || ids.isEmpty) return;
    await inicializar();
    final marcas = List.filled(ids.length, '?').join(',');
    await _db!.rawUpdate(
      'update gps_buffer set enviado = 1 where id in ($marcas)',
      ids,
    );
  }

  Future<void> cerrar() async {
    await _db?.close();
    _db = null;
    _inicializado = false;
  }
}
