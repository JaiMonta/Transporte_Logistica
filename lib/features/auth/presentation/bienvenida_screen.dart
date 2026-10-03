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
  static const _logo = AssetImage('assets/Logo.png');

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
        LayoutBuilder(
          builder: (context, restricciones) {
            return Padding(
              padding: EdgeInsets.all(expandido ? AppSpacing.lg : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo arriba, extremo superior izquierdo, cercano al borde.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image(
                        image: PantallaBienvenida._logo,
                        width: expandido ? 140 : 96,
                        height: expandido ? 140 : 96,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.local_shipping,
                          size: expandido ? 120 : 84,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Texto grande al lado del logo, en una sola línea.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'LOGÍSTICA DE TRANSPORTE',
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 40,
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
                        ),
                      ),
                    ],
                  ),
                  // Empuja el lema inferior bien abajo.
                  const Spacer(),
                  const Spacer(),
                  // Lema pequeño, centrado y más abajo.
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Control de flotas, manifiestos y entregas en un solo lugar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
