import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Paletă Pădure Adâncă ─────────────────────────────────────────
  static const darkTeal    = Color(0xFF073B3A);
  static const darkEmerald = Color(0xFF0B6E4F);
  static const jungle      = Color(0xFF08A045);
  static const moss        = Color(0xFF6BBF59);
  static const fawn        = Color(0xFFDDB771);
  static const fawnLight   = Color(0xFFFDF3E0);

  // ── Suprafețe ─────────────────────────────────────────────────────
  static const bg          = Color(0xFFF4F7F4);
  static const surface     = Color(0xFFFFFFFF);

  // ── Text ──────────────────────────────────────────────────────────
  static const text        = Color(0xFF0D1F1E);
  static const textMuted   = Color(0xFF4A6B68);

  // ── Expiry semantic ───────────────────────────────────────────────
  static const expiryRed   = Color(0xFFC0392B);
  static const expiryFawn  = Color(0xFFDDB771);
  static const expiryGreen = Color(0xFF08A045);

  // ── Shadow ────────────────────────────────────────────────────────
  static const shadowColor = Color(0xFF073B3A);

  // ── Aliasuri de compatibilitate ───────────────────────────────────
  static const primary       = jungle;
  static const accent        = fawn;
  static const freshGreen    = expiryGreen;
  static const useSoonYellow = expiryFawn;
  static const expiredRed    = expiryRed;
  static const background    = bg;
  static const textPrimary   = text;
  static const textSecondary = textMuted;
  static const divider       = Color(0xFFE8EDEC);

  // ── NutriScore (alias semantic) ───────────────────────────────────
  static const nutriA = Color(0xFF27AE60);
  static const nutriB = jungle;
  static const nutriC = fawn;
  static const nutriD = expiryRed;
}
