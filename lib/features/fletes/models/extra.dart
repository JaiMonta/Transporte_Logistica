/// Tipo de extra de un manifiesto.
enum TipoExtra {
  caleta,
  reparto,
  desvio,
  retorno,
  mora,
  finSemana,
  picking;

  static TipoExtra desde(String? valor) => switch (valor) {
        'caleta' => TipoExtra.caleta,
        'reparto' => TipoExtra.reparto,
        'desvio' => TipoExtra.desvio,
        'retorno' => TipoExtra.retorno,
        'mora' => TipoExtra.mora,
        'fin_semana' => TipoExtra.finSemana,
        'picking' => TipoExtra.picking,
        _ => TipoExtra.caleta,
      };

  String get valor => switch (this) {
        TipoExtra.caleta => 'caleta',
        TipoExtra.reparto => 'reparto',
        TipoExtra.desvio => 'desvio',
        TipoExtra.retorno => 'retorno',
        TipoExtra.mora => 'mora',
        TipoExtra.finSemana => 'fin_semana',
        TipoExtra.picking => 'picking',
      };

  String get etiqueta => switch (this) {
        TipoExtra.caleta => 'Caleta',
        TipoExtra.reparto => 'Reparto',
        TipoExtra.desvio => 'Desvío',
        TipoExtra.retorno => 'Retorno',
        TipoExtra.mora => 'Mora',
        TipoExtra.finSemana => 'Fin de semana',
        TipoExtra.picking => 'Picking',
      };
}

/// Estado de aprobación de un extra.
enum EstadoExtra {
  sugerido,
  aprobado,
  rechazado;

  static EstadoExtra desde(String? valor) => switch (valor) {
        'aprobado' => EstadoExtra.aprobado,
        'rechazado' => EstadoExtra.rechazado,
        _ => EstadoExtra.sugerido,
      };

  String get valor => name;

  String get etiqueta => switch (this) {
        EstadoExtra.sugerido => 'Sugerido',
        EstadoExtra.aprobado => 'Aprobado',
        EstadoExtra.rechazado => 'Rechazado',
      };
}

/// Extra de un manifiesto (tabla `manifiesto_extras`).
class Extra {
  const Extra({
    required this.id,
    required this.manifiestoId,
    required this.tipo,
    this.descripcion,
    this.base,
    this.monto = 0,
    this.porcentaje,
    this.estado = EstadoExtra.sugerido,
    this.origen,
    this.notas,
    this.creadoEn,
  });

  final String id;
  final String manifiestoId;
  final TipoExtra tipo;
  final String? descripcion;
  final double? base;
  final double monto;
  final double? porcentaje;
  final EstadoExtra estado;
  final String? origen;
  final String? notas;
  final DateTime? creadoEn;

  factory Extra.fromMap(Map<String, dynamic> m) => Extra(
        id: m['id'] as String,
        manifiestoId: m['manifiesto_id'] as String,
        tipo: TipoExtra.desde(m['tipo'] as String?),
        descripcion: m['descripcion'] as String?,
        base: _d(m['base']),
        monto: _d(m['monto']) ?? 0,
        porcentaje: _d(m['porcentaje']),
        estado: EstadoExtra.desde(m['estado'] as String?),
        origen: m['origen'] as String?,
        notas: m['notas'] as String?,
        creadoEn: _f(m['created_at']),
      );

  Map<String, dynamic> aCuerpo({required String manifiestoId}) => {
        'manifiesto_id': manifiestoId,
        'tipo': tipo.valor,
        'descripcion': descripcion,
        'base': base,
        'monto': monto,
        'porcentaje': porcentaje,
        'origen': origen,
        'notas': notas,
      };

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _f(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
