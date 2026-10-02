import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../models/tabulador_flete.dart';
import '../../providers/fletes_providers.dart';

/// Selector de localidad del tabulador con búsqueda por texto.
///
/// Devuelve el [TabuladorFlete] elegido o null.
class SelectorLocalidadFlete extends ConsumerStatefulWidget {
  const SelectorLocalidadFlete({
    super.key,
    required this.onSeleccion,
    this.etiqueta = 'Localidad (tabulador)',
  });

  final ValueChanged<TabuladorFlete> onSeleccion;
  final String etiqueta;

  @override
  ConsumerState<SelectorLocalidadFlete> createState() =>
      _SelectorLocalidadFleteState();
}

class _SelectorLocalidadFleteState
    extends ConsumerState<SelectorLocalidadFlete> {
  final _busqueda = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _busqueda.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      tabuladorProvider(FiltroFletes(busqueda: _busqueda.text)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _busqueda,
          focusNode: _focus,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            hintText: 'Escribe para buscar',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('No se pudo cargar el tabulador: $e'),
            ),
            data: (fletes) => fletes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('Sin resultados.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: fletes.length,
                    itemBuilder: (context, i) {
                      final f = fletes[i];
                      return ListTile(
                        dense: true,
                        title: Text(f.localidadVisible),
                        subtitle: Text(
                          '${f.region ?? '—'} · KM ${f.km?.toStringAsFixed(0) ?? '—'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          widget.onSeleccion(f);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
