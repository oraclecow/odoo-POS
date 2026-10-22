import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette: Official Arawali Retail Theme (Red, Orange & Midnight Slate)
  static const arawaliRed = Color(0xFFDC2626);      // Primary Arawali Brand Red
  static const arawaliDarkRed = Color(0xFF991B1B);  // Deep Crimson Header
  static const arawaliOrange = Color(0xFFEA580C);   // Accent Orange / Highlight
  static const arawaliOrangeLight = Color(0xFFFFF7ED); // Soft Warm Orange Tint
  static const sunYellow = Color(0xFFFFD54F);       // Warm Amber Price Capsule
  static const deepSlate = Color(0xFF1E293B);       // Ledger & Console Midnight Slate
  static const borderDark = Color(0xFF0F172A);      // 1.5px / 2px Border Outline
  static const cartRow = Color(0xFF0F172A);         // Obsidian Cart Row
  static const cartRowBorder = Color(0xFF334155);   // Cart Item Border
  static const pureWhite = Color(0xFFFFFFFF);       // Clean Card Surface
  static const pitchBlack = Color(0xFF0F172A);      // High-Contrast Primary Text

  // Semantic Aliases for Components
  static const background = Color(0xFFF1F5F9);      // Crisp Slate Canvas
  static const topbarBg = arawaliDarkRed;           // Topbar uses Arawali Dark Red
  static const cyanTopbar = arawaliDarkRed;         // Backward compatibility alias
  static const cardSurface = pureWhite;
  static const ticketBackground = deepSlate;

  // Primary Action Accent
  static const primaryRed = arawaliRed;
  static const primaryGreen = Color(0xFF16A34A);
  static const accentPurple = Color(0xFF7C3AED);
  static const darkHeader = deepSlate;

  // Stock Status Badges
  static const stockInStock = Color(0xFF16A34A);
  static const stockLow = Color(0xFFD97706);
  static const stockOut = Color(0xFFDC2626);

  // Text
  static const textPrimary = pitchBlack;
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const textWhite = pureWhite;

  // Dividers & Borders
  static const border = borderDark;
  static const divider = borderDark;

  // Order Channels
  static const counterBg = arawaliOrange;
  static const counterText = pureWhite;
  static const retailBg = arawaliOrange;
  static const retailText = pureWhite;
  static const dineInBg = arawaliOrange;
  static const dineInText = pureWhite;
  static const takeAwayBg = arawaliOrangeLight;
  static const takeAwayText = arawaliDarkRed;
  static const grabFoodBg = Color(0xFFF0FDF4);
  static const grabFoodText = Color(0xFF15803D);
  static const shopeeFoodBg = Color(0xFFFFF1F2);
  static const shopeeFoodText = Color(0xFFBE123C);
}
