import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bitacora.dart';
import 'export_stub.dart' if (dart.library.js_interop) 'export_web.dart';

/// Fila plana de la Bitácora (una entrega), para CSV y PDF.
class FilaBitacora {
  const FilaBitacora({
    required this.fecha,
    required this.chofer,
    required this.guias,
    required this.cliente,
    required this.destino,
    required this.region,
    required this.capacidad,
    required this.flete,
  });

  final String fecha;
  final String chofer;
  final String guias;
  final String cliente;
  final String destino;
  final String region;
  final String capacidad;
  final double? flete;
}

/// Exportación de la Bitácora a CSV (web) y PDF (todas las plataformas).
class ExportBitacora {
  const ExportBitacora._();

  /// Aplana la Bitácora a filas (una por entrega).
  static List<FilaBitacora> filas(BitacoraResumen resumen) {
    final filas = <FilaBitacora>[];
    for (final dia in resumen.dias) {
      for (final m in dia.manifiestos) {
        if (m.entregas.isEmpty) {
          filas.add(
            FilaBitacora(
              fecha: _fecha(dia.fecha),
              chofer: m.choferVisible,
              guias: m.guiasTexto,
              cliente: '—',
              destino: '—',
              region: '—',
              capacidad: m.capacidadTexto,
              flete: m.fleteBase,
            ),
          );
          continue;
        }
        for (final e in m.entregas) {
          filas.add(
            FilaBitacora(
              fecha: _fecha(dia.fecha),
              chofer: m.choferVisible,
              guias: m.guiasTexto,
              cliente: e.cliente,
              destino: e.destinoVisible,
              region: e.regionVisible,
              capacidad: m.capacidadTexto,
              flete: m.fleteBase,
            ),
          );
        }
      }
    }
    return filas;
  }

  /// Texto CSV (separador `;`) con encabezado y totales.
  static String filasCsv(BitacoraResumen resumen) {
    final b = StringBuffer();
    b.writeln('Bitácora;${_fecha(resumen.desde)};${_fecha(resumen.hasta)}');
    b.writeln(
      'Manifiestos;${resumen.totalManifiestos};'
      'Entregas;${resumen.totalEntregas};'
      'Total flete (USD);${_num(resumen.totalFlete)}',
    );
    b.writeln();
    b.writeln(
      [
        'Fecha',
        'Chofer',
        'N° Guía(s)',
        'Cliente',
        'Destino',
        'Región',
        'Cap.',
        'Base de flete (USD)',
      ].map(_csv).join(';'),
    );
    for (final f in filas(resumen)) {
      b.writeln(
        [
          f.fecha,
          f.chofer,
          f.guias,
          f.cliente,
          f.destino,
          f.region,
          f.capacidad,
          f.flete == null ? '' : _num(f.flete!),
        ].map(_csv).join(';'),
      );
    }
    return b.toString();
  }

  static String _nombreArchivo(BitacoraResumen resumen) =>
      'bitacora_${_fechaArchivo(resumen.desde)}_${_fechaArchivo(resumen.hasta)}';

  /// Descarga el CSV (solo Web). Devuelve `false` en otras plataformas.
  static bool descargarCsv(BitacoraResumen resumen) {
    if (!kIsWeb) return false;
    return descargarArchivo(
      '${_nombreArchivo(resumen)}.csv',
      '\uFEFF${filasCsv(resumen)}',
      'text/csv;charset=utf-8',
    );
  }

  /// Genera y comparte el PDF de la Bitácora.
  static Future<void> compartirPdf(BitacoraResumen resumen) async {
    final doc = pw.Document();
    final listaFilas = filas(resumen);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Bitácora',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'DESDE ${_fecha(resumen.desde)}   '
                  'HASTA ${_fecha(resumen.hasta)}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Fecha',
              'Chofer',
              'N° Guía(s)',
              'Cliente',
              'Destino',
              'Región',
              'Cap.',
              'Base de flete',
            ],
            data: [
              for (final f in listaFilas)
                [
                  f.fecha,
                  f.chofer,
                  f.guias,
                  f.cliente,
                  f.destino,
                  f.region,
                  f.capacidad,
                  f.flete == null ? '—' : '\$ ${_num(f.flete!)}',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Manifiestos: ${resumen.totalManifiestos}   '
            'Entregas: ${resumen.totalEntregas}   '
            'Total flete: \$ ${_num(resumen.totalFlete)}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_nombreArchivo(resumen)}.pdf',
    );
  }

  static String _csv(String campo) {
    final necesita =
        campo.contains(';') ||
        campo.contains('"') ||
        campo.contains('\n') ||
        campo.contains('\r');
    if (!necesita) return campo;
    return '"${campo.replaceAll('"', '""')}"';
  }

  static String _num(double v) => v.toStringAsFixed(2);

  static String _fecha(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '$dia/$mes/${f.year}';
  }

  static String _fechaArchivo(DateTime f) {
    final dia = f.day.toString().padLeft(2, '0');
    final mes = f.month.toString().padLeft(2, '0');
    return '${f.year}$mes$dia';
  }
}
