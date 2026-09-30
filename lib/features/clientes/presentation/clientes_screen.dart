import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/cliente.dart';
import '../providers/clientes_providers.dart';
import 'widgets/cliente_card.dart';
import 'widgets/cliente_tabla.dart';

/// Catálogo de clientes con búsqueda y filtro por estado.
/// Muestra tarjetas en teléfono y tabla en pantalla ancha.
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  FiltroClientes _filtro = const FiltroClientes();

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _onBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _filtro = _filtro.copyWith(busqueda: texto));
    });
  }

  void _refrescar() => ref.invalidate(clientesProvider(_filtro));

  void _editar(Cliente cliente) =>
      context.go(Rutas.adminClienteEditar(cliente.id));

  Future<void> _alternarActivo(Cliente cliente) async {
    final accion = cliente.activo ? 'desactivar' : 'reactivar';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿${accion[0].toUpperCase()}${accion.substring(1)} cliente?'),
        content: Text(
          cliente.activo
              ? 'El cliente dejará de aparecer para los choferes, pero se conserva su historial.'
              : 'El cliente volverá a estar disponible para los choferes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sí, $accion'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(clientesRepositoryProvider).cambiarActivo(
            id: cliente.id,
            activo: !cliente.activo,
          );
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cliente.activo ? 'Cliente desactivado.' : 'Cliente reactivado.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncClientes = ref.watch(clientesProvider(_filtro));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _busqueda,
                label: 'Buscar',
                hint: 'Nombre, contacto, correo o dirección',
                icono: Icons.search,
                onChanged: _onBuscar,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _chipEstado('Todos', null),
                  _chipEstado('Activos', true),
                  _chipEstado('Inactivos', false),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: asyncClientes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorVista(
              mensaje: mensajeError(e),
              onReintentar: _refrescar,
            ),
            data: (clientes) => RefreshIndicator(
              onRefresh: () async => _refrescar(),
              child: clientes.isEmpty
                  ? const _VacioVista()
                  : ResponsiveLayout(
                      breakpoint: 820,
                      movil: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: clientes.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => ClienteCard(
                          cliente: clientes[i],
                          onEditar: _editar,
                          onAlternarActivo: _alternarActivo,
                        ),
                      ),
                      ancho: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: ClienteTabla(
                          clientes: clientes,
                          onEditar: _editar,
                          onAlternarActivo: _alternarActivo,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipEstado(String texto, bool? activo) => ChoiceChip(
        label: Text(texto),
        selected: _filtro.activo == activo,
        onSelected: (_) =>
            setState(() => _filtro = _filtro.copyWith(activo: activo)),
      );
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.storefront_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No se encontraron clientes.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text('Ajusta la búsqueda o los filtros.',
              style: Theme.of(context).textTheme.bodySmall),
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
