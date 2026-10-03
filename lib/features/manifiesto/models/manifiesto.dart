/// Tipo de documento de una línea del manifiesto.
enum TipoDocumento {
  pro,
  factura;

  static TipoDocumento desde(String? valor) => TipoDocumento.values.firstWhere(
        (t) => t.name == valor,
        orElse: () => TipoDocumento.pro,
      );

  String get valor => name;

  String get etiqueta => switch (this) {
        TipoDocumento.pro => 'PRO',
        TipoDocumento.factura => 'Factura',
      };
}

/// Estado del cotejo documental del manifiesto (revisión humana del OCR).
enum CotejoEstado {
  pendiente,
  ok,
  revision;

  static CotejoEstado desde(String? valor) => CotejoEstado.values.firstWhere(
        (c) => c.name == valor,
        orElse: () => CotejoEstado.pendiente,
      );

  String get valor => name;

  String get etiqueta => switch (this) {
        CotejoEstado.pendiente => 'Pendiente',
        CotejoEstado.ok => 'Validado',
        CotejoEstado.revision => 'Requiere revisión',
      };
}

/// Línea del manifiesto (tabla `manifiesto_lineas`).
class ManifiestoLinea {
  const ManifiestoLinea({
    this.id,
    required this.tipo,
    required this.numero,
    this.clienteId,
    this.clienteTexto,
    this.clienteNombre,
    this.orden = 0,
  });

  final String? id;
  final TipoDocumento tipo;
  final String numero;
  final String? clienteId;
  final String? clienteTexto;
  final String? clienteNombre;
  final int orden;

  String get numeroVisible =>
      numero.trim().isNotEmpty ? numero.trim() : 'Sin número';

  /// Cliente del catálogo o el texto libre.
  String get clienteVisible {
    if (clienteNombre != null && clienteNombre!.trim().isNotEmpty) {
      return clienteNombre!.trim();
    }
    if (clienteTexto != null && clienteTexto!.trim().isNotEmpty) {
      return clienteTexto!.trim();
    }
    return 'Sin cliente';
  }

  factory ManifiestoLinea.fromMap(Map<String, dynamic> mapa) {
    final clienteMap = mapa['clientes'];
    String? clienteNombre;
    if (clienteMap is Map) {
      clienteNombre = clienteMap['nombre'] as String?;
    }

    return ManifiestoLinea(
      id: mapa['id'] as String?,
      tipo: TipoDocumento.desde(mapa['tipo'] as String?),
      numero: (mapa['numero'] as String?) ?? '',
      clienteId: mapa['cliente_id'] as String?,
      clienteTexto: mapa['cliente_texto'] as String?,
      clienteNombre: clienteNombre,
      orden: (mapa['orden'] as num?)?.toInt() ?? 0,
    );
  }

  /// Cuerpo para insert/update (sin el join del cliente).
  Map<String, dynamic> aCuerpo({required String manifiestoId}) => {
        'manifiesto_id': manifiestoId,
        'tipo': tipo.valor,
        'numero': numero.trim(),
        'cliente_id': clienteId,
        'cliente_texto': _texto(clienteTexto),
        'orden': orden,
      };

  ManifiestoLinea copyWith({
    TipoDocumento? tipo,
    String? numero,
    String? clienteId,
    String? clienteTexto,
    int? orden,
  }) =>
      ManifiestoLinea(
        id: id,
        tipo: tipo ?? this.tipo,
        numero: numero ?? this.numero,
        clienteId: clienteId ?? this.clienteId,
        clienteTexto: clienteTexto ?? this.clienteTexto,
        clienteNombre: clienteNombre,
        orden: orden ?? this.orden,
      );

  static String? _texto(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// Cabecera del manifiesto/guía de carga (tabla `manifiestos`).
class Manifiesto {
  const Manifiesto({
    required this.id,
    required this.fecha,
    this.capturadoPor,
    this.capturadoPorNombre,
    this.bucket,
    this.path,
    this.hashSha256,
    this.ocrConfianza,
    this.cotejo = CotejoEstado.pendiente,
    this.camionId,
    this.camionNombre,
    this.localidadMasLejana,
    this.fletesTabuladorId,
    this.costoFlete,
    this.esFinSemana = false,
    this.lineas = const [],
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final DateTime fecha;
  final String? capturadoPor;
  final String? capturadoPorNombre;
  final String? bucket;
  final String? path;
  final String? hashSha256;
  final double? ocrConfianza;
  final CotejoEstado cotejo;
  final String? camionId;
  final String? camionNombre;
  final String? localidadMasLejana;
  final String? fletesTabuladorId;
  final double? costoFlete;
  final bool esFinSemana;
  final List<ManifiestoLinea> lineas;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get camionVisible =>
      (camionNombre?.trim().isNotEmpty ?? false)
          ? camionNombre!.trim()
          : 'Sin camión';

  int get totalDocumentos => lineas.length;

  /// Resumen de la primera línea (para tarjetas/tablas).
  String get primerDocumento =>
      lineas.isEmpty ? 'Sin documentos' : lineas.first.numeroVisible;

  /// ¿Tiene foto del BOL registrada?
  bool get tieneFoto =>
      (bucket?.isNotEmpty ?? false) && (path?.isNotEmpty ?? false);

  /// Confianza del OCR expresada en porcentaje (0–100).
  int? get confianzaPorcentaje =>
      ocrConfianza == null ? null : (ocrConfianza! * 100).round();

  factory Manifiesto.fromMap(Map<String, dynamic> mapa) {
    final perfilMap = mapa['profiles'];
    String? capturadoPorNombre;
    if (perfilMap is Map) {
      capturadoPorNombre =
          (perfilMap['nombre'] as String?) ?? (perfilMap['email'] as String?);
    }

    final lineasMap = mapa['manifiesto_lineas'];
    final lineas = <ManifiestoLinea>[];
    if (lineasMap is List) {
      for (final item in lineasMap) {
        if (item is Map) {
          lineas.add(ManifiestoLinea.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      lineas.sort((a, b) => a.orden.compareTo(b.orden));
    }

    final camionMap = mapa['camiones'];
    String? camionNombre;
    if (camionMap is Map) {
      final marca = (camionMap['marca'] as String?)?.trim();
      final placa = (camionMap['placa'] as String?)?.trim();
      camionNombre = [marca, placa].whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' · ');
      if (camionNombre.isEmpty) camionNombre = null;
    }

    return Manifiesto(
      id: mapa['id'] as String,
      fecha: _fecha(mapa['fecha']) ?? DateTime.now(),
      capturadoPor: mapa['capturado_por'] as String?,
      capturadoPorNombre: capturadoPorNombre,
      bucket: mapa['bucket'] as String?,
      path: mapa['path'] as String?,
      hashSha256: mapa['hash_sha256'] as String?,
      ocrConfianza: _doble(mapa['ocr_confianza']),
      cotejo: CotejoEstado.desde(mapa['cotejo'] as String?),
      camionId: mapa['camion_id'] as String?,
      camionNombre: camionNombre,
      localidadMasLejana: mapa['localidad_mas_lejana'] as String?,
      fletesTabuladorId: mapa['fletes_tabulador_id'] as String?,
      costoFlete: _doble(mapa['costo_flete']),
      esFinSemana: (mapa['es_fin_semana'] as bool?) ?? false,
      lineas: lineas,
      creadoEn: _fecha(mapa['created_at']),
      actualizadoEn: _fecha(mapa['updated_at']),
    );
  }

  Manifiesto copyWith({
    DateTime? fecha,
    String? bucket,
    String? path,
    String? hashSha256,
    double? ocrConfianza,
    CotejoEstado? cotejo,
    String? camionId,
    String? localidadMasLejana,
    String? fletesTabuladorId,
    double? costoFlete,
    bool? esFinSemana,
    List<ManifiestoLinea>? lineas,
  }) =>
      Manifiesto(
        id: id,
        fecha: fecha ?? this.fecha,
        capturadoPor: capturadoPor,
        capturadoPorNombre: capturadoPorNombre,
        bucket: bucket ?? this.bucket,
        path: path ?? this.path,
        hashSha256: hashSha256 ?? this.hashSha256,
        ocrConfianza: ocrConfianza ?? this.ocrConfianza,
        cotejo: cotejo ?? this.cotejo,
        camionId: camionId ?? this.camionId,
        camionNombre: camionNombre,
        localidadMasLejana: localidadMasLejana ?? this.localidadMasLejana,
        fletesTabuladorId: fletesTabuladorId ?? this.fletesTabuladorId,
        costoFlete: costoFlete ?? this.costoFlete,
        esFinSemana: esFinSemana ?? this.esFinSemana,
        lineas: lineas ?? this.lineas,
        creadoEn: creadoEn,
        actualizadoEn: actualizadoEn,
      );

  static double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  static DateTime? _fecha(Object? valor) =>
      valor == null ? null : DateTime.tryParse(valor.toString());
}
