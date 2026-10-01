import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../models/cliente.dart';
import '../../providers/clientes_providers.dart';

/// Selección de cliente híbrida: del catálogo o texto libre.
///
/// Devuelve `(clienteId, clienteTexto)`. Si elige "Otro", pide el nombre a
/// mano y `clienteId` queda nulo.
class SelectorClienteHibrido extends ConsumerStatefulWidget {
  const SelectorClienteHibrido({
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
  ConsumerState<SelectorClienteHibrido> createState() =>
      _SelectorClienteHibridoState();
}

class _SelectorClienteHibridoState
    extends ConsumerState<SelectorClienteHibrido> {
  static const String _otro = '__otro__';

  final _texto = TextEditingController();

  @override
  void initState() {
    super.initState();
    _texto.text = widget.clienteTexto ?? '';
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
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
      data: (clientes) => _selector(context, clientes),
    );
  }

  Widget _selector(BuildContext context, List<Cliente> clientes) {
    final usarOtro = widget.clienteId == null &&
        (widget.clienteTexto?.isNotEmpty ?? false);
    final valor =
        usarOtro ? _otro : (clientes.any((c) => c.id == widget.clienteId)
            ? widget.clienteId
            : (_texto.text.isNotEmpty ? _otro : null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: valor,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: [
            ...clientes.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.nombreVisible, overflow: TextOverflow.ellipsis),
                )),
            const DropdownMenuItem(
              value: _otro,
              child: Text('Otro (texto libre)'),
            ),
          ],
          onChanged: widget.habilitado
              ? (v) {
                  if (v == _otro) {
                    widget.onCambio(null, _texto.text);
                  } else {
                    widget.onCambio(v, null);
                  }
                }
              : null,
        ),
        if (valor == _otro) ...[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _texto,
            enabled: widget.habilitado,
            decoration: const InputDecoration(
              labelText: 'Nombre del cliente',
              hintText: 'Como aparece en la guía',
            ),
            onChanged: (t) => widget.onCambio(null, t),
          ),
        ],
      ],
    );
  }
}
