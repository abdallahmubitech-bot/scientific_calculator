import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: AppColors.darkPrimaryColor,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryColor,
        onPrimary: AppColors.textIcons,
        secondary: AppColors.accentColor,
        onSecondary: AppColors.textIcons,
        surface: AppColors.keySurface,
        onSurface: AppColors.primaryText,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      dividerColor: AppColors.dividerColor,
      textTheme: GoogleFonts.robotoTextTheme(base.textTheme).apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textIcons,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: GoogleFonts.roboto(
          color: AppColors.textIcons,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: const IconThemeData(color: AppColors.textIcons),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 0.5,
        space: 0.5,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.keySurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkPrimaryColor,
        contentTextStyle: TextStyle(color: AppColors.textIcons),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
