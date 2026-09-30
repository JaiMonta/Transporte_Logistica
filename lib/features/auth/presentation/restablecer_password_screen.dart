import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/errors/mensajes_error.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/validators/validador.dart';
import '../providers/auth_providers.dart';

/// Permite fijar una nueva contraseña cuando el usuario llega desde el
/// enlace de recuperación (evento `passwordRecovery`).
class RestablecerPasswordScreen extends ConsumerStatefulWidget {
  const RestablecerPasswordScreen({super.key});

  @override
  ConsumerState<RestablecerPasswordScreen> createState() =>
      _RestablecerPasswordScreenState();
}

class _RestablecerPasswordScreenState
    extends ConsumerState<RestablecerPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();
  bool _verContrasena = false;
  bool _cargando = false;

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final controller = ref.read(authControllerProvider.notifier);
      await controller.actualizarContrasena(_contrasena.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Inicia sesión.')),
      );
      await controller.cerrarSesion();
      if (mounted) context.go(Rutas.login);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Define tu nueva contraseña',
                      style: tema.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Mínimo 8 caracteres, con mayúscula, minúscula y número.',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _contrasena,
                    label: 'Nueva contraseña',
                    icono: Icons.lock_outline,
                    obscure: !_verContrasena,
                    validator: Validador.contrasena,
                    suffixIcon: IconButton(
                      tooltip: _verContrasena
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      icon: Icon(_verContrasena
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _verContrasena = !_verContrasena),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _confirmar,
                    label: 'Confirmar contraseña',
                    icono: Icons.lock_reset_outlined,
                    obscure: !_verContrasena,
                    validator: (v) =>
                        Validador.confirmarContrasena(v, _contrasena.text),
                    onFieldSubmitted: (_) => _guardar(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    texto: 'Guardar contraseña',
                    cargando: _cargando,
                    onPressed: _guardar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
