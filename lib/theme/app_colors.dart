import 'package:flutter/material.dart';

/// Uygulamanın tüm renk tanımları — tek kaynak, hiçbir yerde hardcode renk yok.
abstract final class AppColors {
  // --- Marka Renkleri ---
  static const Color primary = Color(0xFF1E1B4B); // Derin gece lacivert
  static const Color primaryLight = Color(0xFF312E81);
  static const Color accent = Color(0xFF6366F1); // Elektrik indigo
  static const Color accentSoft = Color(0xFFEEF2FF); // Indigo'nun soluk tonu

  // --- Yüzey & Arka Plan ---
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF1F3FA);

  // --- Metin ---
  static const Color textPrimary = Color(0xFF0F0E17);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFFADB5BD);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // --- Kenarlık ---
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocused = accent;

  // --- Durum Renkleri ---
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEF2F2);

  // --- Gölge ---
  static const Color shadowSoft = Color(0x0A1E1B4B);
  static const Color shadowMedium = Color(0x141E1B4B);
  static const Color accentGlow = Color(0x306366F1);

  // --- Kategori Etiket Renkleri ---
  static const Color tagBlueText = Color(0xFF1D4ED8);
  static const Color tagBlueBg = Color(0xFFEFF6FF);
  static const Color tagGreenText = Color(0xFF065F46);
  static const Color tagGreenBg = Color(0xFFECFDF5);
  static const Color tagAmberText = Color(0xFF92400E);
  static const Color tagAmberBg = Color(0xFFFFFBEB);
}