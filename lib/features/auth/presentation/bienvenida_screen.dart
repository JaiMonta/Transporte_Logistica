import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/offline_banner.dart';
import 'widgets/formulario_login.dart';

/// Pantalla inicial: mitad izquierda con imagen de bienvenida y lema,
/// mitad derecha con el formulario de inicio de sesión.
///
/// En pantallas estrechas se apila: imagen arriba y formulario abajo.
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  static const _imagen = AssetImage('assets/bienvenida_transporte.jfif');
  static const _logo = AssetImage('assets/logo.png');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ancho = constraints.maxWidth >= 900;
                  return ancho ? _VistaAncha() : const _VistaAngosta();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VistaAncha extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 3, child: _PanelImagen(expandido: true)),
        Expanded(flex: 2, child: _PanelLogin()),
      ],
    );
  }
}

class _VistaAngosta extends StatelessWidget {
  const _VistaAngosta();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(flex: 45, child: _PanelImagen(expandido: false)),
        Expanded(flex: 55, child: _PanelLogin()),
      ],
    );
  }
}

class _PanelImagen extends StatelessWidget {
  const _PanelImagen({required this.expandido});

  final bool expandido;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: PantallaBienvenida._imagen,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: AppColors.primary),
        ),
        // Degradado para asegurar contraste del texto y el logo.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.30),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(expandido ? AppSpacing.xl : AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: expandido
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Image(
                image: PantallaBienvenida._logo,
                width: expandido ? 96 : 72,
                height: expandido ? 96 : 72,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.local_shipping, size: 72, color: Colors.white),
              ),
              SizedBox(height: expandido ? AppSpacing.lg : AppSpacing.md),
              Text(
                'LOGÍSTICA\nDE TRANSPORTE',
                textAlign: expandido ? TextAlign.start : TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: expandido ? 60 : 34,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Control de flota, manifiestos y entregas en un solo lugar.',
                textAlign: expandido ? TextAlign.start : TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelLogin extends StatelessWidget {
  const _PanelLogin();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const FormularioLogin(),
          ),
        ),
      ),
    );
  }
}
