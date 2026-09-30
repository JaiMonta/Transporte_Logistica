import 'package:flutter/material.dart';

/// Conmuta entre un diseño móvil y uno de pantalla ancha según el ancho
/// disponible (no según la plataforma).
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.movil,
    required this.ancho,
    this.breakpoint = 720,
  });

  final Widget movil;
  final Widget ancho;
  final double breakpoint;

  static bool esAncho(BuildContext context, {double breakpoint = 720}) =>
      MediaQuery.sizeOf(context).width >= breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= breakpoint
          ? ancho
          : movil,
    );
  }
}
