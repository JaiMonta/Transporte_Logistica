import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../features/auth/providers/auth_providers.dart';
import '../shared/widgets/responsive_layout.dart';

/// Panel de administración (resumen). Se ampliará en módulos posteriores.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(currentProfileProvider).value;
    final tema = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hola, ${perfil?.nombreVisible ?? ''}',
              style: tema.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Resumen general del sistema.', style: tema.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          ResponsiveLayout(
            movil: Column(
              children: [
                _Acceso(
                  icono: Icons.people_outline,
                  titulo: 'Usuarios y accesos',
                  descripcion: 'Crea, edita y administra las cuentas.',
                  onTap: () => context.go(Rutas.adminUsuarios),
                ),
              ],
            ),
            ancho: Row(
              children: [
                Expanded(
                  child: _Acceso(
                    icono: Icons.people_outline,
                    titulo: 'Usuarios y accesos',
                    descripcion: 'Crea, edita y administra las cuentas.',
                    onTap: () => context.go(Rutas.adminUsuarios),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(icono, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(descripcion,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
