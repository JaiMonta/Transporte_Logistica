import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../models/empresa.dart';
import '../models/producto.dart';
import '../providers/empresas_providers.dart';

/// Catálogo de empresas facturadas y sus productos (panel admin).
class EmpresasScreen extends ConsumerStatefulWidget {
  const EmpresasScreen({super.key});

  @override
  ConsumerState<EmpresasScreen> createState() => _EmpresasScreenState();
}

class _EmpresasScreenState extends ConsumerState<EmpresasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _ocupado = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refrescar() {
    ref.invalidate(empresasProvider);
    ref.invalidate(empresasActivasProvider);
    ref.invalidate(productosProvider);
    ref.invalidate(productosActivosProvider);
  }

  Future<void> _conOcupado(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) _refrescar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // ----------------------------------------------------------
  // Empresas.
  // ----------------------------------------------------------
  Future<void> _formEmpresa({Empresa? empresa}) async {
    final nombre = TextEditingController(text: empresa?.nombre ?? '');
    final rif = TextEditingController(text: empresa?.rif ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(empresa == null ? 'Nueva empresa' : 'Editar empresa'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Indica el nombre' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: rif,
                decoration:
                    const InputDecoration(labelText: 'RIF (opcional)'),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _conOcupado(() async {
      final repo = ref.read(empresasRepositoryProvider);
      final duplicado = await repo.existeNombreEmpresa(
        nombre.text,
        excluirId: empresa?.id,
      );
      if (duplicado) {
        throw Exception('Ya existe una empresa con ese nombre.');
      }
      if (empresa == null) {
        await repo.crearEmpresa(nombre: nombre.text, rif: rif.text);
      } else {
        await repo.actualizarEmpresa(
          id: empresa.id,
          nombre: nombre.text,
          rif: rif.text,
        );
      }
    });
  }

  Future<void> _toggleEmpresa(Empresa e) => _conOcupado(() async {
        await ref.read(empresasRepositoryProvider).cambiarActivoEmpresa(
              id: e.id,
              activo: !e.activo,
            );
      });

  // ----------------------------------------------------------
  // Productos.
  // ----------------------------------------------------------
  Future<void> _formProducto({
    Producto? producto,
    required List<Empresa> empresas,
  }) async {
    final nombre = TextEditingController(text: producto?.nombre ?? '');
    final formKey = GlobalKey<FormState>();
    String? empresaId = producto?.empresaId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(producto == null ? 'Nuevo producto' : 'Editar producto'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Indica el nombre'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: empresaId,
                  decoration:
                      const InputDecoration(labelText: 'Empresa (a facturar)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin empresa'),
                    ),
                    for (final e in empresas)
                      DropdownMenuItem<String?>(
                        value: e.id,
                        child: Text(e.nombreVisible),
                      ),
                  ],
                  onChanged: (v) => setDialog(() => empresaId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await _conOcupado(() async {
      final repo = ref.read(empresasRepositoryProvider);
      final duplicado = await repo.existeNombreProducto(
        nombre.text,
        excluirId: producto?.id,
      );
      if (duplicado) {
        throw Exception('Ya existe un producto con ese nombre.');
      }
      if (producto == null) {
        await repo.crearProducto(
          nombre: nombre.text,
          empresaId: empresaId,
          orden: 0,
        );
      } else {
        await repo.actualizarProducto(
          id: producto.id,
          nombre: nombre.text,
          empresaId: empresaId,
          orden: producto.orden,
        );
      }
    });
  }

  Future<void> _toggleProducto(Producto p) => _conOcupado(() async {
        await ref.read(empresasRepositoryProvider).cambiarActivoProducto(
              id: p.id,
              activo: !p.activo,
            );
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Empresas', icon: Icon(Icons.business_outlined)),
            Tab(text: 'Productos', icon: Icon(Icons.inventory_2_outlined)),
          ],
        ),
        if (_ocupado) const LinearProgressIndicator(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _EmpresasTab(
                onNueva: () => _formEmpresa(),
                onEditar: (e) => _formEmpresa(empresa: e),
                onToggle: _toggleEmpresa,
              ),
              _ProductosTab(
                onNuevo: (empresas) => _formProducto(empresas: empresas),
                onEditar: (p, empresas) =>
                    _formProducto(producto: p, empresas: empresas),
                onToggle: _toggleProducto,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmpresasTab extends ConsumerWidget {
  const _EmpresasTab({
    required this.onNueva,
    required this.onEditar,
    required this.onToggle,
  });

  final VoidCallback onNueva;
  final void Function(Empresa) onEditar;
  final Future<void> Function(Empresa) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(empresasProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(mensajeError(e), textAlign: TextAlign.center),
        ),
      ),
      data: (empresas) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onNueva,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva empresa'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (empresas.isEmpty)
            const _Vacio('Aún no hay empresas. Crea la primera.')
          else
            for (final e in empresas)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(e.nombreVisible),
                  subtitle: Text(
                    '${e.rif?.trim().isNotEmpty ?? false ? 'RIF ${e.rif}' : 'Sin RIF'} · '
                    '${e.activo ? 'Activa' : 'Inactiva'}',
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      Switch(
                        value: e.activo,
                        onChanged: (_) => onToggle(e),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => onEditar(e),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ProductosTab extends ConsumerWidget {
  const _ProductosTab({
    required this.onNuevo,
    required this.onEditar,
    required this.onToggle,
  });

  final void Function(List<Empresa>) onNuevo;
  final void Function(Producto, List<Empresa>) onEditar;
  final Future<void> Function(Producto) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProd = ref.watch(productosProvider);
    final empresas = ref.watch(empresasActivasProvider).value ?? const [];
    return asyncProd.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(mensajeError(e), textAlign: TextAlign.center),
        ),
      ),
      data: (productos) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => onNuevo(empresas),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo producto'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (productos.isEmpty)
            const _Vacio('Aún no hay productos.')
          else
            for (final p in productos)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(p.nombreVisible),
                  subtitle: Text(
                    'Empresa: ${p.empresaVisible} · '
                    '${p.activo ? 'Activo' : 'Inactivo'}',
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      Switch(
                        value: p.activo,
                        onChanged: (_) => onToggle(p),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => onEditar(p, empresas),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}
