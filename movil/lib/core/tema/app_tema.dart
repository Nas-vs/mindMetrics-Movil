import 'package:flutter/material.dart';

/// Paleta oficial de MindMetrics (tokens del diseño).
///
/// Cada color tiene su pareja "sobre" (foreground) para el texto que va
/// encima. Usar siempre la pareja garantiza contraste consistente.
abstract final class AppColores {
  static const primario = Color(0xFF15919B);
  static const sobrePrimario = Color(0xFFFFFFFF);

  static const secundario = Color(0xFFEFF6FB);
  static const sobreSecundario = Color(0xFF4B5563);

  static const acento = Color(0xFFD1FAE5);
  static const sobreAcento = Color(0xFF374151);

  static const fondo = Color(0xFFF0F8FF);
  static const texto = Color(0xFF374151);

  static const tarjeta = Color(0xFFFFFFFF);
  static const sobreTarjeta = Color(0xFF374151);

  static const atenuado = Color(0xFFF3F4F6);
  static const sobreAtenuado = Color(0xFF6B7280);

  static const destructivo = Color(0xFFEF4444);
  static const sobreDestructivo = Color(0xFFFFFFFF);

  static const borde = Color(0xFFE5E7EB);
  static const campo = Color(0xFFE5E7EB);
  static const anillo = Color(0xFF484885);

  static const grafico1 = Color(0xFF15919B);
  static const grafico2 = Color(0xFF0A5483);
}

/// Medidas compartidas para que todas las pantallas se vean iguales.
abstract final class AppMedidas {
  static const radio = 8.0;
  static const radioTarjeta = 12.0;
  static const margenPantalla = 16.0;
  static const relleno = 24.0;
  static const anchoMaximoFormulario = 440.0;
}

/// Tema global de la app. Se aplica una sola vez en MaterialApp:
///   MaterialApp.router(theme: AppTema.claro(), ...)
abstract final class AppTema {
  static ThemeData claro() {
    const esquema = ColorScheme(
      brightness: Brightness.light,
      primary: AppColores.primario,
      onPrimary: AppColores.sobrePrimario,
      secondary: AppColores.secundario,
      onSecondary: AppColores.sobreSecundario,
      tertiary: AppColores.acento,
      onTertiary: AppColores.sobreAcento,
      error: AppColores.destructivo,
      onError: AppColores.sobreDestructivo,
      surface: AppColores.tarjeta,
      onSurface: AppColores.sobreTarjeta,
      onSurfaceVariant: AppColores.sobreAtenuado,
      surfaceContainerHighest: AppColores.atenuado,
      outline: AppColores.borde,
      outlineVariant: AppColores.borde,
    );

    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMedidas.radio),
          borderSide: BorderSide(color: color, width: ancho),
        );

    final base = ThemeData(useMaterial3: true, colorScheme: esquema);

    return base.copyWith(
      scaffoldBackgroundColor: AppColores.fondo,
      textTheme: base.textTheme.apply(
        bodyColor: AppColores.texto,
        displayColor: AppColores.texto,
      ),
      // Campos: caja gris sin borde; borde primario al enfocar.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColores.atenuado,
        hintStyle: const TextStyle(color: AppColores.sobreAtenuado, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: borde(Colors.transparent),
        enabledBorder: borde(Colors.transparent),
        focusedBorder: borde(AppColores.primario, 1.5),
        errorBorder: borde(AppColores.destructivo),
        focusedErrorBorder: borde(AppColores.destructivo, 1.5),
        errorStyle: const TextStyle(color: AppColores.destructivo, fontSize: 12),
        errorMaxLines: 2,
        suffixIconColor: AppColores.sobreAtenuado,
      ),
      // Botón principal: ancho completo, 52 px de alto, texto grande.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColores.primario,
          foregroundColor: AppColores.sobrePrimario,
          disabledBackgroundColor: AppColores.primario.withValues(alpha: 0.7),
          disabledForegroundColor: AppColores.sobrePrimario,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppMedidas.radio),
          ),
          // 19 px en negrita = "texto grande" WCAG: el blanco sobre el
          // primario (contraste 3.8:1) cumple AA solo a este tamaño.
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColores.tarjeta,
        elevation: 6,
        shadowColor: Colors.black26,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMedidas.radioTarjeta),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColores.texto,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColores.tarjeta,
      ),
    );
  }
}
