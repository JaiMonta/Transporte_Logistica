import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/combustible_jornada.dart';
import '../providers/combustible_providers.dart';

/// Panel admin de consumo de combustible.
class CombustibleAdminScreen extends ConsumerWidget {
  const CombustibleAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(combustibleListaProvider);
    return Column(
      children: [
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(mensajeError(e), textAlign: TextAlign.center),
              ),
            ),
            data: (jornadas) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(combustibleListaProvider),
              child: jornadas.isEmpty
                  ? const _VacioVista()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: jornadas.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _JornadaCard(
                        jornada: jornadas[i],
                        onVerDetalle: () => context.push(
                          Rutas.adminCombustibleDetalle(jornadas[i].id),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JornadaCard extends StatelessWidget {
  const _JornadaCard({required this.jornada, required this.onVerDetalle});

  final CombustibleJornada jornada;
  final VoidCallback onVerDetalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_gas_station_outlined),
        title: Text(
          'Inicial: ${_n(jornada.inicialEfectivo)} lt Â· '
          'Final: ${_n(jornada.finalEfectivo)} lt',
          style: tema.textTheme.titleSmall,
        ),
        subtitle: Text(
          '${jornada.estado.etiqueta} Â· Recargas: ${_n(jornada.totalRecargasLt)} lt Â· '
          'Km: ${_n(jornada.kmRecorridos)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onVerDetalle,
      ),
    );
  }

  static String _n(double? v) => v == null ? 'â€”' : v.toStringAsFixed(2);
}

/// Detalle/validaciÃ³n de una jornada de combustible (admin).
class CombustibleAdminDetalleScreen extends ConsumerStatefulWidget {
  const CombustibleAdminDetalleScreen({
    super.key,
    required this.jornadaId,
  });

  final String jornadaId;

  @override
  ConsumerState<CombustibleAdminDetalleScreen> createState() =>
      _CombustibleAdminDetalleScreenState();
}

class _CombustibleAdminDetalleScreenState
    extends ConsumerState<CombustibleAdminDetalleScreen> {
  bool _ocupado = false;

  Future<void> _editar(
    CombustibleJornada j, {
    required bool inicial,
  }) async {
    final controller = TextEditingController(
      text: (inicial ? j.inicialEfectivo : j.finalEfectivo)?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(inicial ? 'Validar litros iniciales' : 'Validar litros finales'),
        content: Form(
          key: formKey,
          child: AppTextField(
            controller: controller,
            label: 'Litros reales',
            icono: Icons.local_gas_station_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (n == null || n < 0) return 'Ingresa un nÃºmero vÃ¡lido.';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardar != true) {
      controller.dispose();
      return;
    }
    setState(() => _ocupado = true);
    try {
      final valor = double.parse(controller.text.replaceAll(',', '.'));
      await ref.read(combustibleRepositoryProvider).validar(
            jornadaId: j.id,
            litrosInicialesValidados: inicial ? valor : null,
            litrosFinalesValidados: inicial ? null : valor,
          );
      if (!mounted) return;
      ref.invalidate(combustibleListaProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad validada.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _validarTodo(CombustibleJornada j) async {
    setState(() => _ocupado = true);
    try {
      await ref.read(combustibleRepositoryProvider).validar(
            jornadaId: j.id,
            marcarValidada: true,
          );
      if (!mounted) return;
      ref.invalidate(combustibleListaProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jornada validada.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(combustibleListaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de combustible')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(mensajeError(e))),
        data: (jornadas) {
          final j = jornadas.firstWhere(
            (x) => x.id == widget.jornadaId,
            orElse: () => jornadas.isEmpty
                ? const CombustibleJornada(
                    id: '', manifiestoId: '', usuarioId: '')
                : jornadas.first,
          );
          if (j.id.isEmpty) {
            return const Center(child: Text('Jornada no encontrada.'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _fila('Estado', j.estado.etiqueta),
              _fila('Litros iniciales (reportado)', _n(j.litrosIniciales)),
              _fila('Litros iniciales (validado)', _n(j.litrosInicialesValidados)),
              _fila('Recargas', '${_n(j.totalRecargasLt)} lt (${j.recargas.length})'),
              _fila('Litros finales (reportado)', _n(j.litrosFinales)),
              _fila('Litros finales (validado)', _n(j.litrosFinalesValidados)),
              const Divider(),
              _fila('Km recorridos', _n(j.kmRecorridos)),
              _fila('Consumo teÃ³rico', '${_n(j.consumoTeoricoLt)} lt'),
              _fila('Consumo real', '${_n(j.consumoRealLt)} lt'),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : () => _editar(j, inicial: true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corregir litros iniciales'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : () => _editar(j, inicial: false),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corregir litros finales'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _ocupado ? null : () => _validarTodo(j),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Marcar como validada'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta)),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static String _n(double? v) => v == null ? 'â€”' : v.toStringAsFixed(2);
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.local_gas_station_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('AÃºn no hay jornadas de combustible.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}
