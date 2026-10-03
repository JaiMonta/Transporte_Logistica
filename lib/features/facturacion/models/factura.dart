import '../../fletes/models/extra.dart';

/// Estado de una factura semanal.
enum EstadoFactura {
  emitida,
  pendiente,
  pagada,
  anulada;

  static EstadoFactura desde(String? valor) => switch (valor) {
        'pendiente' => EstadoFactura.pendiente,
        'pagada' => EstadoFactura.pagada,
        'anulada' => EstadoFactura.anulada,
        _ => EstadoFactura.emitida,
      };

  String get valor => name;

  String get etiqueta => switch (this) {
        EstadoFactura.emitida => 'Emitida',
        EstadoFactura.pendiente => 'Pendiente',
        EstadoFactura.pagada => 'Pagada',
        EstadoFactura.anulada => 'Anulada',
      };
}

/// Ítem de una factura (tabla `factura_items`).
class FacturaItem {
  const FacturaItem({
    required this.id,
    required this.facturaId,
    required this.concepto,
    this.manifiestoId,
    this.usuarioId,
    this.tipo,
    this.descripcion,
    this.base,
    this.porcentaje,
    this.monto = 0,
    this.orden = 0,
  });

  final String id;
  final String facturaId;
  final String concepto;
  final String? manifiestoId;
  final String? usuarioId;
  final TipoExtra? tipo;
  final String? descripcion;
  final double? base;
  final double? porcentaje;
  final double monto;
  final int orden;

  factory FacturaItem.fromMap(Map<String, dynamic> m) => FacturaItem(
        id: m['id'] as String,
        facturaId: m['factura_id'] as String,
        concepto: (m['concepto'] as String?) ?? '',
        manifiestoId: m['manifiesto_id'] as String?,
        usuarioId: m['usuario_id'] as String?,
        tipo: m['tipo'] == null ? null : TipoExtra.desde(m['tipo'] as String?),
        descripcion: m['descripcion'] as String?,
        base: _d(m['base']),
        porcentaje: _d(m['porcentaje']),
        monto: _d(m['monto']) ?? 0,
        orden: (m['orden'] as num?)?.toInt() ?? 0,
      );

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// Factura semanal (tabla `facturas`).
class Factura {
  const Factura({
    required this.id,
    required this.periodoInicio,
    required this.periodoFin,
    this.subtotalFlete = 0,
    this.subtotalExtras = 0,
    this.total = 0,
    this.estado = EstadoFactura.emitida,
    this.notas,
    this.items = const [],
  });

  final String id;
  final DateTime periodoInicio;
  final DateTime periodoFin;
  final double subtotalFlete;
  final double subtotalExtras;
  final double total;
  final EstadoFactura estado;
  final String? notas;
  final List<FacturaItem> items;

  String get periodoTexto {
    String f(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
    return '${f(periodoInicio)} – ${f(periodoFin)}';
  }

  factory Factura.fromMap(Map<String, dynamic> m) {
    final itemsMap = m['factura_items'];
    final items = <FacturaItem>[];
    if (itemsMap is List) {
      for (final it in itemsMap) {
        if (it is Map) {
          items.add(FacturaItem.fromMap(Map<String, dynamic>.from(it)));
        }
      }
      items.sort((a, b) => a.orden.compareTo(b.orden));
    }
    return Factura(
      id: m['id'] as String,
      periodoInicio: DateTime.parse(m['periodo_inicio'].toString()),
      periodoFin: DateTime.parse(m['periodo_fin'].toString()),
      subtotalFlete: _d(m['subtotal_flete']) ?? 0,
      subtotalExtras: _d(m['subtotal_extras']) ?? 0,
      total: _d(m['total']) ?? 0,
      estado: EstadoFactura.desde(m['estado'] as String?),
      notas: m['notas'] as String?,
      items: items,
    );
  }

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
