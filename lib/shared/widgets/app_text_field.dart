import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Campo de texto estándar (altura mínima 56, alto contraste).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icono,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.maxLines = 1,
    this.suffixIcon,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icono;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final int maxLines;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      enabled: enabled,
      maxLines: maxLines,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            icono == null ? null : Icon(icono, color: AppColors.onSurfaceVariant),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
