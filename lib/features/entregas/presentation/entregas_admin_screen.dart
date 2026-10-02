import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/entrega.dart';
import '../providers/entregas_providers.dart';
import 'widgets/entrega_card.dart';

/// Panel admin de entregas (estado + mapa agregado de rutas pendientes).
class EntregasAdminScreen extends ConsumerStatefulWidget {
  const EntregasAdminScreen({super.key});

  @override
  ConsumerState<EntregasAdminScreen> createState() =>
      _EntregasAdminScreenState();
}

class _EntregasAdminScreenState extends ConsumerState<EntregasAdminScreen> {
  FiltroEntregas _filtro = FiltroEntregas(dia: DateTime.now());

  void _verMapa(Entrega e) =>
      context.push(Rutas.adminEntregaMapa(e.manifiestoId));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(entregasDelDiaProvider(_filtro));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    _chipModo('Pendientes', ModoEntregas.pendientes),
                    _chipModo('Hoy', ModoEntregas.hoy),
                    _chipModo('Todas', ModoEntregas.todas),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push(Rutas.adminEntregasMapa),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Mapa'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorVista(
              mensaje: mensajeError(e),
              onReintentar: () =>
                  ref.invalidate(entregasDelDiaProvider(_filtro)),
            ),
            data: (entregas) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(entregasDelDiaProvider(_filtro)),
              child: entregas.isEmpty
                  ? const _VacioVista()
                  : ResponsiveLayout(
                      breakpoint: 760,
                      movil: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: entregas.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => _FilaConCliente(
                          entrega: entregas[i],
                          onVerMapa: _verMapa,
                        ),
                      ),
                      ancho: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: _Tabla(
                            entregas: entregas, onVerMapa: _verMapa),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipModo(String texto, ModoEntregas modo) => ChoiceChip(
        label: Text(texto),
        selected: _filtro.modo == modo,
        onSelected: (_) => setState(() => _filtro = _filtro.copyWith(modo: modo)),
      );
}

class _FilaConCliente extends StatelessWidget {
  const _FilaConCliente({required this.entrega, required this.onVerMapa});

  final Entrega entrega;
  final ValueChanged<Entrega> onVerMapa;

  @override
  Widget build(BuildContext context) {
    return EntregaCard(
      entrega: entrega,
      habilitado: false,
      onEntregar: (_) {},
      onVerMapa: onVerMapa,
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.entregas, required this.onVerMapa});

  final List<Entrega> entregas;
  final ValueChanged<Entrega> onVerMapa;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Cliente')),
          DataColumn(label: Text('Dirección')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Entregado')),
          DataColumn(label: Text('Mapa')),
        ],
        rows: entregas.map((e) {
          return DataRow(cells: [
            DataCell(Text('${e.orden + 1}')),
            DataCell(Text(e.clienteVisible)),
            DataCell(Text(
              (e.direccion == null || e.direccion!.isEmpty) ? '—' : e.direccion!,
            )),
            DataCell(Row(
              children: [
                Icon(Icons.circle,
                    size: 10, color: colorEstadoEntrega(e.estado)),
                const SizedBox(width: 6),
                Text(e.estado.etiqueta),
              ],
            )),
            DataCell(Text(
              e.entregadoEn == null ? '—' : _fechaHora(e.entregadoEn!),
            )),
            DataCell(IconButton(
              tooltip: 'Ver mapa',
              icon: const Icon(Icons.map_outlined),
              onPressed: e.tieneUbicacion ? () => onVerMapa(e) : null,
            )),
          ]);
        }).toList(),
      ),
    );
  }

  static String _fechaHora(DateTime f) {
    final h = f.hour.toString().padLeft(2, '0');
    final m = f.minute.toString().padLeft(2, '0');
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')} $h:$m';
  }
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.local_shipping_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No hay entregas para mostrar.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _ErrorVista extends StatelessWidget {
  const _ErrorVista({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
