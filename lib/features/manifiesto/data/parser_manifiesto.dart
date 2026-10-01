import '../models/manifiesto.dart';

/// Extrae los campos de un manifiesto a partir del texto crudo del OCR.
///
/// Es una función pura (sin IO) para poder probarla con distintos formatos
/// de BOL. No inventa datos: si un campo no se reconoce, se devuelve vacío.
class ParserManifiesto {
  const ParserManifiesto._();

  /// Resultado del parseo.
  static ResultadoParseoManifiesto parsear(String texto) {
    final lineas = texto
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ResultadoParseoManifiesto(
      numeroPro: extraerNumeroPro(texto, lineas),
      fecha: extraerFecha(texto),
      cliente: extraerCliente(lineas),
    );
  }

  /// Número PRO / folio. Busca etiquetas típicas y patrones alfanuméricos.
  static String extraerNumeroPro(String texto, List<String> lineas) {
    // 1) Etiqueta explícita: "PRO", "FOLIO", "MANIFIESTO", "No.", "BOL".
    //    La etiqueta debe ser una palabra completa y venir seguida de un
    //    separador (":", "#", "-", espacio) para no capturar fragmentos.
    final etiqueta = RegExp(
      r'\b(?:n[°º]|no|num|numero|número|folio|pro|bol|manifiesto)\b'
      r'\s*[:#.\-]?\s*([A-Z]{0,4}[\s-]?\d[\dA-Z\s-]{2,})',
      caseSensitive: false,
    );
    for (final linea in lineas) {
      final m = etiqueta.firstMatch(linea);
      if (m != null) {
        final valor = _limpiarCodigo(m.group(1));
        if (valor.isNotEmpty) return valor;
      }
    }

    // 2) Código tipo MN-8921 / BOL-485729A / 485729 presentes solos.
    final suelto = RegExp(r'\b([A-Z]{2,4}[- ]?\d{3,}[A-Z0-9]*)\b');
    for (final linea in lineas) {
      final m = suelto.firstMatch(linea.toUpperCase());
      if (m != null) {
        final valor = _limpiarCodigo(m.group(1));
        if (valor.isNotEmpty) return valor;
      }
    }
    return '';
  }

  /// Fecha en varios formatos: ISO, dd/mm/aaaa, dd-mm-aaaa, aaaa/mm/dd.
  static DateTime? extraerFecha(String texto) {
    // ISO: 2026-03-15
    final iso = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
    final mIso = iso.firstMatch(texto);
    if (mIso != null) {
      return _construir(mIso.group(1)!, mIso.group(2)!, mIso.group(3)!);
    }

    // dd/mm/aaaa o dd-mm-aaaa
    final dma = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b');
    final mDma = dma.firstMatch(texto);
    if (mDma != null) {
      return _construir(mDma.group(3)!, mDma.group(2)!, mDma.group(1)!);
    }

    // aaaa/mm/dd
    final amd = RegExp(r'\b(\d{4})[/](\d{1,2})[/](\d{1,2})\b');
    final mAmd = amd.firstMatch(texto);
    if (mAmd != null) {
      return _construir(mAmd.group(1)!, mAmd.group(2)!, mAmd.group(3)!);
    }
    return null;
  }

  /// Nombre del cliente/destinatario tras etiquetas típicas.
  static String extraerCliente(List<String> lineas) {
    final etiqueta = RegExp(
      r'(?:cliente|destinatario|consignee|recibido\s+por|raz[oó]n\s+social)'
      r'\s*[:#-]?\s*(.+)',
      caseSensitive: false,
    );
    for (final linea in lineas) {
      final m = etiqueta.firstMatch(linea);
      if (m != null) {
        final valor = m.group(1)!.trim();
        // Evita capturar cuando tras la etiqueta no hay texto útil.
        if (valor.length >= 3) return valor;
      }
    }
    return '';
  }

  static DateTime? _construir(String anio, String mes, String dia) {
    final a = int.tryParse(anio);
    final me = int.tryParse(mes);
    final d = int.tryParse(dia);
    if (a == null || me == null || d == null) return null;
    if (me < 1 || me > 12 || d < 1 || d > 31) return null;
    try {
      return DateTime(a, me, d);
    } catch (_) {
      return null;
    }
  }

  static String _limpiarCodigo(String? valor) {
    final v = (valor ?? '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'^[-\s]+'), '')
        .trim();
    return v;
  }
}

/// Campos extraídos del texto del OCR.
class ResultadoParseoManifiesto {
  const ResultadoParseoManifiesto({
    required this.numeroPro,
    required this.fecha,
    required this.cliente,
  });

  final String numeroPro;
  final DateTime? fecha;
  final String cliente;

  bool get tieneAlgo =>
      numeroPro.isNotEmpty || fecha != null || cliente.isNotEmpty;

  /// Compatibilidad: reutiliza el modelo de estado del manifiesto.
  CotejoEstado get cotejo => CotejoEstado.pendiente;
}
