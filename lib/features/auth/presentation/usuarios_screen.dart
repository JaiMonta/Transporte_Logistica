import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/validators/validador.dart';
import '../models/profile.dart';
import '../providers/usuarios_providers.dart';
import 'widgets/usuario_card.dart';
import 'widgets/usuario_tabla.dart';

/// Lista de usuarios con bÃºsqueda y filtros por rol y estado.
/// Muestra tarjetas en telÃ©fono y tabla en pantalla ancha.
class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  FiltroUsuarios _filtro = const FiltroUsuarios();

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

  void _refrescar() => ref.invalidate(usuariosProvider(_filtro));

  void _editar(Profile usuario) =>
      context.push(Rutas.adminUsuarioEditar(usuario.id));

  Future<void> _alternarActivo(Profile usuario) async {
    final accion = usuario.activo ? 'desactivar' : 'reactivar';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Â¿${accion[0].toUpperCase()}${accion.substring(1)} usuario?'),
        content: Text(
          usuario.activo
              ? 'El usuario no podrÃ¡ iniciar sesiÃ³n, pero se conserva su historial.'
              : 'El usuario podrÃ¡ volver a iniciar sesiÃ³n.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('SÃ­, $accion'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(usuariosRepositoryProvider).cambiarActivo(
            id: usuario.id,
            activo: !usuario.activo,
          );
      if (!mounted) return;
      _refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            usuario.activo ? 'Usuario desactivado.' : 'Usuario reactivado.',
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

  Future<void> _restablecer(Profile usuario) async {
    final formKey = GlobalKey<FormState>();
    final contrasena = TextEditingController();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseÃ±a'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuario: ${usuario.nombreVisible}'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: contrasena,
                label: 'Nueva contraseÃ±a',
                icono: Icons.lock_outline,
                obscure: true,
                validator: Validador.contrasena,
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
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar == true) {
      try {
        await ref.read(usuariosRepositoryProvider).restablecerContrasena(
              id: usuario.id,
              contrasena: contrasena.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ContraseÃ±a restablecida.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(mensajeError(e))));
        }
      }
    }
    contrasena.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncUsuarios = ref.watch(usuariosProvider(_filtro));

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
                hint: 'Nombre, correo o telÃ©fono',
                icono: Icons.search,
                onChanged: _onBuscar,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _chipRol('Todos', null),
                  _chipRol('Administradores', Rol.admin),
                  _chipRol('Choferes', Rol.chofer),
                  const SizedBox(width: AppSpacing.md),
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
          child: asyncUsuarios.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorVista(
              mensaje: mensajeError(e),
              onReintentar: _refrescar,
            ),
            data: (usuarios) => RefreshIndicator(
              onRefresh: () async => _refrescar(),
              child: usuarios.isEmpty
                  ? const _VacioVista()
                  : ResponsiveLayout(
                      breakpoint: 760,
                      movil: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: usuarios.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => UsuarioCard(
                          usuario: usuarios[i],
                          onEditar: _editar,
                          onAlternarActivo: _alternarActivo,
                          onRestablecer: _restablecer,
                        ),
                      ),
                      ancho: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: UsuarioTabla(
                          usuarios: usuarios,
                          onEditar: _editar,
                          onAlternarActivo: _alternarActivo,
                          onRestablecer: _restablecer,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipRol(String texto, Rol? rol) => ChoiceChip(
        label: Text(texto),
        selected: _filtro.rol == rol,
        onSelected: (_) => setState(() => _filtro = _filtro.copyWith(rol: rol)),
      );

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
        const Icon(Icons.person_search_outlined,
            size: 56, color: AppColors.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text('No se encontraron usuarios.',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text('Ajusta la bÃºsqueda o los filtros.',
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
