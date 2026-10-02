import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../models/cliente.dart';
import '../../providers/clientes_providers.dart';

/// Selección de cliente con **búsqueda por nombre** (híbrida).
///
/// Escribe para filtrar el catálogo; al elegir un resultado se devuelve el
/// `clienteId`. Si no elige ninguno (texto libre), devuelve `clienteTexto`.
class SelectorClienteBusqueda extends ConsumerStatefulWidget {
  const SelectorClienteBusqueda({
    super.key,
    required this.clienteId,
    required this.clienteTexto,
    required this.onCambio,
    this.habilitado = true,
  });

  final String? clienteId;
  final String? clienteTexto;
  final void Function(String? clienteId, String? clienteTexto) onCambio;
  final bool habilitado;

  @override
  ConsumerState<SelectorClienteBusqueda> createState() =>
      _SelectorClienteBusquedaState();
}

class _SelectorClienteBusquedaState
    extends ConsumerState<SelectorClienteBusqueda> {
  final _busqueda = TextEditingController();
  final _focus = FocusNode();
  bool _modoLibre = false;

  @override
  void initState() {
    super.initState();
    if (widget.clienteId == null && (widget.clienteTexto?.isNotEmpty ?? false)) {
      _modoLibre = true;
      _busqueda.text = widget.clienteTexto!;
    }
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _elegir(Cliente c) {
    _busqueda.text = c.nombreVisible;
    setState(() => _modoLibre = false);
    _focus.unfocus();
    widget.onCambio(c.id, null);
  }

  void _usarLibre() {
    setState(() => _modoLibre = true);
    widget.onCambio(null, _busqueda.text);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientesActivosProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('No se pudieron cargar los clientes: $e'),
      data: (clientes) => _build(context, clientes),
    );
  }

  Widget _build(BuildContext context, List<Cliente> clientes) {
    final termino = _busqueda.text.trim().toLowerCase();
    final coincideId = widget.clienteId != null
        ? clientes.where((c) => c.id == widget.clienteId).firstOrNull
        : null;
    if (coincideId != null && _busqueda.text.isEmpty) {
      _busqueda.text = coincideId.nombreVisible;
    }

    final filtrados = termino.isEmpty
        ? clientes
        : clientes
            .where((c) => c.nombreVisible.toLowerCase().contains(termino))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _busqueda,
          focusNode: _focus,
          enabled: widget.habilitado,
          decoration: InputDecoration(
            labelText: 'Cliente',
            hintText: 'Escribe para buscar',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busqueda.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Limpiar',
                    onPressed: () {
                      _busqueda.clear();
                      setState(() => _modoLibre = false);
                      widget.onCambio(null, null);
                    },
                  ),
          ),
          onChanged: (t) {
            setState(() => _modoLibre = false);
            widget.onCambio(null, null);
          },
        ),
        if (_focus.hasFocus || termino.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in filtrados.take(30))
                  ListTile(
                    dense: true,
                    title: Text(c.nombreVisible),
                    subtitle: (c.codCli == null || c.codCli!.isEmpty)
                        ? null
                        : Text('Código: ${c.codCli}'),
                    onTap: widget.habilitado ? () => _elegir(c) : null,
                  ),
                if (termino.isNotEmpty)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text('Usar "$termino" como texto libre'),
                    onTap: widget.habilitado ? _usarLibre : null,
                  ),
              ],
            ),
          ),
        ],
        if (_modoLibre) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Se usará el nombre escrito (sin enlazar al catálogo).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
