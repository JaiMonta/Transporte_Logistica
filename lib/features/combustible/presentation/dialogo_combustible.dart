import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Resultado del diálogo de combustible (litros iniciales / finales).
class DatosCombustible {
  const DatosCombustible({
    required this.litros,
    this.odometro,
  });

  final double litros;
  final double? odometro;
}

/// Diálogo para capturar litros (iniciales o finales) y odómetro opcional.
Future<DatosCombustible?> mostrarDialogoCombustible(
  BuildContext context, {
  required String titulo,
  required String etiquetaLitros,
  double? litrosIniciales,
  double? odometroInicial,
}) {
  return showDialog<DatosCombustible>(
    context: context,
    builder: (_) => _DialogoCombustible(
      titulo: titulo,
      etiquetaLitros: etiquetaLitros,
      litrosIniciales: litrosIniciales,
      odometroInicial: odometroInicial,
    ),
  );
}

class _DialogoCombustible extends StatefulWidget {
  const _DialogoCombustible({
    required this.titulo,
    required this.etiquetaLitros,
    this.litrosIniciales,
    this.odometroInicial,
  });

  final String titulo;
  final String etiquetaLitros;
  final double? litrosIniciales;
  final double? odometroInicial;

  @override
  State<_DialogoCombustible> createState() => _DialogoCombustibleState();
}

class _DialogoCombustibleState extends State<_DialogoCombustible> {
  final _formKey = GlobalKey<FormState>();
  final _litros = TextEditingController();
  final _odometro = TextEditingController();

  @override
  void dispose() {
    _litros.dispose();
    _odometro.dispose();
    super.dispose();
  }

  double? _num(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _litros,
              label: widget.etiquetaLitros,
              icono: Icons.local_gas_station_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = _num(v ?? '');
                if (n == null || n < 0) return 'Ingresa un número válido.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _odometro,
              label: 'Odómetro (km, opcional)',
              icono: Icons.speed_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = _num(t);
                if (n == null || n < 0) return 'Ingresa un número válido.';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final od = (_odometro.text.trim().isEmpty)
                ? null
                : _num(_odometro.text);
            Navigator.pop(
              context,
              DatosCombustible(litros: _num(_litros.text)!, odometro: od),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
