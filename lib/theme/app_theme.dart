import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;

  static const IconData iconoMiFinca = Icons.home;
  
  // Declaramos iconoGanado compatible con FontAwesome
  static const dynamic iconoGanado = FontAwesomeIcons.cow; 
  static const IconData iconoSanidad = Icons.vaccines;
  static const IconData iconoReproduccion = Icons.favorite;
  static const IconData iconoProduccion = Icons.opacity;
  static const IconData iconoFinanzas = Icons.attach_money;
  static const IconData iconoInventario = Icons.inventory;
  static const IconData iconoConfiguracion = Icons.settings;

  // Método auxiliar con parámetro dinámico para evitar conflictos de tipos
  static Widget obtenerIcono(dynamic icono, {Color? color, double size = 24}) {
    if (icono == FontAwesomeIcons.cow) {
      // Si no se proporciona color, FaIcon usará el color por defecto (a menudo negro)
      // Es preferible no forzar un color aquí si queremos que el NavigationBar lo controle
      return FaIcon(icono, color: color, size: size);
    }
    return Icon(icono as IconData, color: color, size: size);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundGrey,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: lightGreen,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}