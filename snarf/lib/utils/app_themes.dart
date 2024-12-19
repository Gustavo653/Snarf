import 'package:flutter/material.dart';
import 'package:snarf/utils/app_colors.dart';

class AppThemes {
  // Tema Claro
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryColor,
      iconTheme: const IconThemeData(color: Colors.black),
    ),
    textTheme: const TextTheme(
      bodySmall: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
      bodyLarge: TextStyle(color: Colors.black),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: AppColors.buttonColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
    ),
  );

  // Tema Escuro
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      bodySmall: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: AppColors.buttonColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
    ),
  );
}