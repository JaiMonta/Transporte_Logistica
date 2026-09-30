import '../../clientes/models/cliente.dart';

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

/// Manifiesto capturado en campo (tabla `manifiestos`).
class Manifiesto {
  const Manifiesto({
    required this.id,
    required this.numeroPro,
    required this.fecha,
    this.clienteId,
    this.clienteNombre,
    this.capturadoPor,
    this.capturadoPorNombre,
    this.bucket,
    this.path,
    this.hashSha256,
    this.ocrPro,
    this.ocrConfianza,
    this.cotejo = CotejoEstado.pendiente,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String numeroPro;
  final DateTime fecha;
  final String? clienteId;
  final String? clienteNombre;
  final String? capturadoPor;
  final String? capturadoPorNombre;
  final String? bucket;
  final String? path;
  final String? hashSha256;
  final String? ocrPro;
  final double? ocrConfianza;
  final CotejoEstado cotejo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get numeroVisible =>
      numeroPro.trim().isNotEmpty ? numeroPro.trim() : 'Sin número';

  String get clienteVisible =>
      (clienteNombre?.trim().isNotEmpty ?? false)
          ? clienteNombre!.trim()
          : 'Sin cliente';

  /// ¿Tiene foto del BOL registrada?
  bool get tieneFoto =>
      (bucket?.isNotEmpty ?? false) && (path?.isNotEmpty ?? false);

  /// Confianza del OCR expresada en porcentaje (0–100).
  int? get confianzaPorcentaje =>
      ocrConfianza == null ? null : (ocrConfianza! * 100).round();

  factory Manifiesto.fromMap(Map<String, dynamic> mapa) {
    // El cliente puede venir embebido por el join (clientes(nombre)).
    final clienteMap = mapa['clientes'];
    String? clienteNombre;
    if (clienteMap is Map) {
      clienteNombre = clienteMap['nombre'] as String?;
    }

    final perfilMap = mapa['profiles'];
    String? capturadoPorNombre;
    if (perfilMap is Map) {
      capturadoPorNombre =
          (perfilMap['nombre'] as String?) ?? (perfilMap['email'] as String?);
    }

    return Manifiesto(
      id: mapa['id'] as String,
      numeroPro: (mapa['numero_pro'] as String?) ?? '',
      fecha: _fecha(mapa['fecha']) ?? DateTime.now(),
      clienteId: mapa['cliente_id'] as String?,
      clienteNombre: clienteNombre,
      capturadoPor: mapa['capturado_por'] as String?,
      capturadoPorNombre: capturadoPorNombre,
      bucket: mapa['bucket'] as String?,
      path: mapa['path'] as String?,
      hashSha256: mapa['hash_sha256'] as String?,
      ocrPro: mapa['ocr_pro'] as String?,
      ocrConfianza: _doble(mapa['ocr_confianza']),
      cotejo: CotejoEstado.desde(mapa['cotejo'] as String?),
      creadoEn: _fecha(mapa['created_at']),
      actualizadoEn: _fecha(mapa['updated_at']),
    );
  }

  Manifiesto copyWith({
    String? numeroPro,
    DateTime? fecha,
    String? clienteId,
    String? clienteNombre,
    String? bucket,
    String? path,
    String? hashSha256,
    String? ocrPro,
    double? ocrConfianza,
    CotejoEstado? cotejo,
  }) =>
      Manifiesto(
        id: id,
        numeroPro: numeroPro ?? this.numeroPro,
        fecha: fecha ?? this.fecha,
        clienteId: clienteId ?? this.clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        capturadoPor: capturadoPor,
        capturadoPorNombre: capturadoPorNombre,
        bucket: bucket ?? this.bucket,
        path: path ?? this.path,
        hashSha256: hashSha256 ?? this.hashSha256,
        ocrPro: ocrPro ?? this.ocrPro,
        ocrConfianza: ocrConfianza ?? this.ocrConfianza,
        cotejo: cotejo ?? this.cotejo,
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

  /// Utilidad para el `ClienteSelector` (nombre para mostrar).
  static String etiquetaCliente(Cliente cliente) => cliente.nombreVisible;
}
