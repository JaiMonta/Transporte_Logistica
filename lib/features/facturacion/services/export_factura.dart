import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../fletes/models/extra.dart';
import '../models/factura.dart';

/// Exportación de una factura por empresa a PDF.
class ExportFactura {
  const ExportFactura._();

  /// Genera y comparte el PDF de la factura.
  static Future<void> compartirPdf(Factura f, {double tasaBs = 0}) async {
    final porProducto = <String, List<FacturaItem>>{};
    for (final it in f.items) {
      final k = (it.productoNombre?.trim().isNotEmpty ?? false)
          ? it.productoNombre!.trim()
          : 'Sin producto';
      porProducto.putIfAbsent(k, () => []).add(it);
    }

    final headers = ['Producto', 'Concepto', 'Monto (USD)'];
    if (tasaBs > 0) headers.add('Monto (Bs)');

    final data = <List<String>>[];
    for (final entrada in porProducto.entries) {
      for (final it in entrada.value) {
        final fila = <String>[
          entrada.key,
          _concepto(it),
          _num(it.monto),
        ];
        if (tasaBs > 0) fila.add(_num(it.monto * tasaBs));
        data.add(fila);
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Factura — ${f.empresaVisible}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Periodo ${f.periodoTexto}   ·   '
                    'Estado: ${f.estado.etiqueta}'),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data.isEmpty ? [['—', '—', '—']] : data,
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _totales('Flete base', f.subtotalFlete, tasaBs),
                  _totales('Extras', f.subtotalExtras, tasaBs),
                  _totales('Total', f.total, tasaBs, negrita: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'factura_${_archivo(f.periodoInicio)}_'
          '${_archivo(f.periodoFin)}_${f.empresaVisible}.pdf',
    );
  }

  static pw.Widget _totales(
    String etiqueta,
    double valor,
    double tasaBs, {
    bool negrita = false,
  }) {
    final estilo = pw.TextStyle(
      fontSize: negrita ? 11 : 10,
      fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    final texto = tasaBs > 0
        ? '$etiqueta: \$ ${_num(valor)}   (Bs ${_num(valor * tasaBs)})'
        : '$etiqueta: \$ ${_num(valor)}';
    return pw.Text(texto, style: estilo);
  }

  static String _concepto(FacturaItem it) {
    if (it.tipo == TipoExtra.caleta) return 'Flete secundario';
    final etiqueta = it.tipo?.etiqueta;
    if (etiqueta != null) return etiqueta;
    return it.concepto.isEmpty
        ? '—'
        : it.concepto[0].toUpperCase() + it.concepto.substring(1);
  }

  static String _num(double v) => v.toStringAsFixed(2);

  static String _archivo(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '${f.year}$mes$dia';
  }
}
