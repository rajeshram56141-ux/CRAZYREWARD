import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF101010); // Dark background (#101010)
  static const Color cardDarkColor = Color(0xFF1E1B4B); // Dark indigo surface
  static const Color headerDarkColor = Color(0xFF131438); // Header surface
  static const Color accentPurple = Color(0xFF9333EA); // Neon Purple
  static const Color accentMagenta = Color(0xFFF472B6); // Neon Magenta
  static const Color accentCyan = Color(0xFF38BDF8); // Neon Sky Blue
  static const Color primaryColor = Color(0xFF9333EA); // Neon brand color
  static const Color titleColor = Colors.white; // White for dark titles
  static const Color subtitleColor = Color(0xFF94A3B8); // Slate 400 for descriptions
  static const Color errorColor = Color(0xFFEF4444); // Premium red
  static const Color processingColor = Color(0xFFF59E0B); // Amber yellow
  static const Color successColor = Color(0xFF22C55E); // Bright success green
  static const Color disabledColor = Color(0xFF64748B); // Slate 500
  static const Color borderColor = Color(0xFF1E293B); // Dark border line

  // Obsidian Violet Theme Palette (from Home Screen)
  static const Color obsidianBase = Color(0xFF101010);
  static const Color obsidianCardStart = Color(0xFF201B30);
  static const Color obsidianCardMid = Color(0xFF291E42);
  static const Color obsidianCardEnd = Color(0xFF382060);
  static const Color violetPrimary = Color(0xFF7C3AED);
  static const Color violetElectric = Color(0xFF6B15F6);
  static const Color violetLight = Color(0xFFC084FC);
  static const Color violetGloss = Color(0xFFEADBFF);
  static const Color textMuted = Color(0xFF8E82AC);

  // Card & Surface Colors
  static const Color cardColor = Color(0xFF201B30);
  static const Color cardBorderColor = Color(0xFF334155);
  static const Color goldAccent = Color(0xFFEAB308);

  // Theme Gradients
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF201B30), Color(0xFF291E42), Color(0xFF382060)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGlossGradient = LinearGradient(
    colors: [
      Color(0xFFEADBFF),
      Color(0xFFA565FF),
      Color(0xFF6B15F6),
      Color(0xFF550BD0),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient activeMethodGradient = LinearGradient(
    colors: [
      Color(0xFF3B1868),
      Color(0xFF5B21B6),
      Color(0xFF7C3AED),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient inactiveMethodGradient = LinearGradient(
    colors: [
      Color(0xFF201B30),
      Color(0xFF291E42),
      Color(0xFF382060),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF15803D)], // Premium Green Gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sageGradient = LinearGradient(
    colors: [Color(0xFF869A7C), Color(0xFF607456)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFF3E0), Color(0xFFFFD54F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient redeemGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFEADBFF),
      Color(0xFFA565FF),
      Color(0xFF6B15F6),
      Color(0xFF550BD0),
    ],
  );

  static const fontFamily = 'Poppins';

  static final ThemeData appTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    primaryColor: primaryColor,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundColor,
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
        fontSize: 15.sp,
        color: titleColor,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 12.sp,
        color: subtitleColor,
        fontWeight: FontWeight.normal,
        fontFamily: fontFamily,
      ),
      iconColor: primaryColor,
    ),
    disabledColor: disabledColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      surface: backgroundColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: titleColor, size: 24.w),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: titleColor,
        fontFamily: fontFamily,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32.sp,
        fontWeight: FontWeight.bold,
        color: titleColor,
        fontFamily: fontFamily,
      ),
      displayMedium: TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.bold,
        color: titleColor,
        fontFamily: fontFamily,
      ),
      displaySmall: TextStyle(
        fontSize: 18.sp,
        color: subtitleColor,
        fontFamily: fontFamily,
      ),
      headlineMedium: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: titleColor,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 16.sp,
        color: titleColor,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.sp,
        color: subtitleColor,
        fontFamily: fontFamily,
      ),
      labelLarge: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: titleColor,
        fontFamily: fontFamily,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: const StadiumBorder(),
      backgroundColor: primaryColor,
      labelStyle: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: fontFamily,
      ),
    ),
  );

  // For backward compatibility during migration
  static ThemeData get darkTheme => appTheme;
  static ThemeData get lightTheme => appTheme;
}
