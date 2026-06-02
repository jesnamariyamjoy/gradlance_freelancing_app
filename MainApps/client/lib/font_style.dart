import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle heading1({Color? color}) => poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: color ?? const Color(0xFF102030),
      );

  static TextStyle heading2({Color? color}) => poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: color ?? const Color(0xFF102030),
      );

  static TextStyle body({Color? color}) => poppins(
        fontSize: 14,
        color: color ?? Colors.blueGrey[800],
      );

  static TextStyle caption({Color? color}) => poppins(
        fontSize: 12,
        color: color ?? Colors.grey[600],
      );
}
