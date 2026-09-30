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

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState
    extends ConsumerState<RecuperarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  bool _cargando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .recuperarContrasena(_correo.text);
      if (mounted) setState(() => _enviado = true);
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
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _enviado ? _confirmacion(tema) : _formulario(tema),
          ),
        ),
      ),
    );
  }

  Widget _formulario(ThemeData tema) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿Olvidaste tu contraseña?', style: tema.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Escribe tu correo y te enviaremos un enlace para restablecerla.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _correo,
            label: 'Correo electrónico',
            icono: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validador.correo,
            onFieldSubmitted: (_) => _enviar(),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            texto: 'Enviar enlace',
            cargando: _cargando,
            onPressed: _enviar,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _cargando ? null : () => context.go(Rutas.login),
            child: const Text('Volver al inicio de sesión'),
          ),
        ],
      ),
    );
  }

  Widget _confirmacion(ThemeData tema) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 64, color: AppColors.tertiary),
        const SizedBox(height: AppSpacing.md),
        Text('Revisa tu correo', style: tema.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Si existe una cuenta con ${_correo.text.trim()}, recibirás un enlace '
          'para restablecer tu contraseña.',
          style: tema.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          texto: 'Volver al inicio de sesión',
          onPressed: () => context.go(Rutas.login),
        ),
      ],
    );
  }
}
