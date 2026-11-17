import 'package:flutter/material.dart';

class AppColors {
  static const Color darkPrimaryColor = Color(0xFF303F9F); // Status bar, top mode bar, active scientific headers
  static const Color lightPrimaryColor = Color(0xFFC5CAE9); // Scientific keypad background / subtle highlights
  static const Color primaryColor = Color(0xFF3F51B5); // AppBar, primary accents, active tabs
  static const Color textIcons = Color(0xFFFFFFFF); // Text/icons on primary and accent backgrounds
  static const Color accentColor = Color(0xFF448AFF); // Equals (=) button, cursor, active indicators
  static const Color primaryText = Color(0xFF212121); // Main display output, numeric button labels
  static const Color secondaryText = Color(0xFF757575); // Expression input text, secondary labels, shift hints
  static const Color dividerColor = Color(0xFFBDBDBD); // Grid borders, subtle key dividers

  /// Light surfaces used by the display area and the numeric keypad.
  static const Color surface = Color(0xFFFAFAFA);
  static const Color keySurface = Color(0xFFFFFFFF);
}
