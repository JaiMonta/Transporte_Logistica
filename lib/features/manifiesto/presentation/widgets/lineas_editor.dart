import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../clientes/presentation/widgets/selector_cliente_hibrido.dart';
import '../../models/manifiesto.dart';

/// Editor de las líneas (PRO/factura) de un manifiesto.
///
/// Cada línea tiene tipo, número y cliente (de catálogo o texto libre).
/// Sin límite de cantidad: se pueden agregar o quitar renglones.
class LineasEditor extends StatefulWidget {
  const LineasEditor({
    super.key,
    required this.lineas,
    required this.onCambio,
    this.habilitado = true,
  });

  final List<ManifiestoLinea> lineas;
  final ValueChanged<List<ManifiestoLinea>> onCambio;
  final bool habilitado;

  @override
  State<LineasEditor> createState() => _LineasEditorState();
}

class _LineasEditorState extends State<LineasEditor> {
  late List<_LineaEditable> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.lineas.map(_LineaEditable.desde).toList();
    if (_items.isEmpty) _items.add(_LineaEditable.vacia());
  }

  void _emitir() {
    widget.onCambio([for (var i = 0; i < _items.length; i++) _items[i].aLinea(i)]);
  }

  void _agregar() {
    setState(() => _items.add(_LineaEditable.vacia()));
    _emitir();
  }

  void _quitar(int i) {
    setState(() => _items.removeAt(i));
    if (_items.isEmpty) _items.add(_LineaEditable.vacia());
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Documentos (PRO o factura)',
                style: tema.textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.habilitado ? _agregar : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _linea(tema, i),
          ),
      ],
    );
  }

  Widget _linea(ThemeData tema, int i) {
    final item = _items[i];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Documento ${i + 1}', style: tema.textTheme.labelMedium),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.delete_outline, color: AppColors.peligro),
                  onPressed: widget.habilitado ? () => _quitar(i) : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<TipoDocumento>(
            segments: const [
              ButtonSegment(value: TipoDocumento.pro, label: Text('PRO')),
              ButtonSegment(
                  value: TipoDocumento.factura, label: Text('Factura')),
            ],
            selected: {item.tipo},
            onSelectionChanged: widget.habilitado
                ? (s) {
                    setState(() => item.tipo = s.first);
                    _emitir();
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: item.numero,
            enabled: widget.habilitado,
            decoration: InputDecoration(
              labelText: item.tipo == TipoDocumento.pro
                  ? 'Número PRO'
                  : 'Número de factura',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Ingresa el número.' : null,
            onChanged: (_) => _emitir(),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectorClienteHibrido(
            clienteId: item.clienteId,
            clienteTexto: item.clienteTexto,
            habilitado: widget.habilitado,
            onCambio: (id, texto) {
              setState(() {
                item.clienteId = id;
                item.clienteTexto = texto;
              });
              _emitir();
            },
          ),
        ],
      ),
    );
  }
}

/// Estado mutable de una línea durante la edición.
class _LineaEditable {
  _LineaEditable({
    this.tipo = TipoDocumento.pro,
    required this.numero,
    this.clienteId,
    this.clienteTexto,
  });

  TipoDocumento tipo;
  final TextEditingController numero;
  String? clienteId;
  String? clienteTexto;

  factory _LineaEditable.vacia() => _LineaEditable(numero: TextEditingController());

  factory _LineaEditable.desde(ManifiestoLinea l) => _LineaEditable(
        tipo: l.tipo,
        numero: TextEditingController(text: l.numero),
        clienteId: l.clienteId,
        clienteTexto: l.clienteTexto,
      );

  ManifiestoLinea aLinea(int orden) => ManifiestoLinea(
        tipo: tipo,
        numero: numero.text.trim(),
        clienteId: clienteId,
        clienteTexto: clienteTexto,
        orden: orden,
      );
}
