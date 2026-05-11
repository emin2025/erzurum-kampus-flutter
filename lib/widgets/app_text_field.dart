import 'package:erzurum_kampus/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Projenin tek yetkili TextFormField bileşeni.
/// Tüm sayfalar bu widget'ı kullanır — hiçbir yerde inline TextFormField tanımlanmaz.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.inputFormatters,
    this.prefixText,
    this.autofillHints,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      onChanged: onChanged,
      textInputAction: textInputAction,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      readOnly: readOnly,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.textMuted),
        suffixIcon: isPassword
            ? _PasswordToggleIcon(
                obscureText: obscureText,
                onToggle: onToggleObscure,
              )
            : null,
      ),
    );
  }
}

/// Şifre alanı için göster/gizle ikonu — ayrı widget olarak tanımlandı.
class _PasswordToggleIcon extends StatelessWidget {
  const _PasswordToggleIcon({required this.obscureText, this.onToggle});

  final bool obscureText;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscureText
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        size: 20,
        color: AppColors.textMuted,
      ),
      onPressed: onToggle,
      splashRadius: 20,
    );
  }
}