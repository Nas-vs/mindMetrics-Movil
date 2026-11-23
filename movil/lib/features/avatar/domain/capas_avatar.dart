import 'estado_avatar.dart';

/// Variantes de ojos. El nombre del enum coincide con el archivo:
/// `CapaOjos.empaticos` → `ojos_empaticos.svg`.
enum CapaOjos {
  abiertos,
  cerrados,
  felices,
  empaticos,
  pensando;

  String get archivo => 'ojos_$name';
}

/// Variantes de boca: cuatro expresiones en silencio y cinco visemas
/// para hablar (de cerrada a abierta, más la "o").
enum CapaBoca {
  sonrisa,
  alegre,
  suave,
  pensando,
  cerrada,
  pequena,
  media,
  abierta,
  o;

  String get archivo => 'boca_$name';

  bool get esVisema => index >= CapaBoca.cerrada.index;
}

/// Reglas puras que traducen el estado a capas visibles.
/// No dependen de widgets, por eso se prueban sin montar la vista.
abstract final class CapasAvatar {
  static const cuerpo = 'cuerpo';
  static const sombra = 'sombra';
  static const mejillas = 'mejillas';
  static const extraPensando = 'extra_pensando';

  /// Todas las capas que debe traer la carpeta de un personaje.
  static List<String> get todas => [
        sombra,
        cuerpo,
        mejillas,
        ...CapaOjos.values.map((o) => o.archivo),
        ...CapaBoca.values.map((b) => b.archivo),
        extraPensando,
      ];

  /// Umbrales de apertura de la boca según el nivel de voz (0..1).
  static const umbralPequena = 0.08;
  static const umbralMedia = 0.35;
  static const umbralAbierta = 0.65;

  static CapaOjos ojosPara(EstadoAvatar estado, {required bool parpadeando}) {
    final base = switch ((estado.actividad, estado.emocion)) {
      (ActividadAvatar.pensando, _) => CapaOjos.pensando,
      (_, EmocionAvatar.alegre) => CapaOjos.felices,
      (_, EmocionAvatar.empatico) => CapaOjos.empaticos,
      _ => CapaOjos.abiertos,
    };
    // Los ojos felices ya están entrecerrados: parpadear no aporta.
    if (parpadeando && base != CapaOjos.felices) return CapaOjos.cerrados;
    return base;
  }

  /// [nivelVoz] solo se usa mientras habla. [vocalRedonda] alterna la
  /// apertura media con la "o" para que el habla no se vea mecánica.
  static CapaBoca bocaPara(
    EstadoAvatar estado, {
    double nivelVoz = 0,
    bool vocalRedonda = false,
  }) {
    if (estado.actividad == ActividadAvatar.hablando) {
      if (nivelVoz < umbralPequena) return CapaBoca.cerrada;
      if (nivelVoz < umbralMedia) return CapaBoca.pequena;
      if (nivelVoz < umbralAbierta) {
        return vocalRedonda ? CapaBoca.o : CapaBoca.media;
      }
      return CapaBoca.abierta;
    }
    if (estado.actividad == ActividadAvatar.pensando) return CapaBoca.pensando;
    return switch (estado.emocion) {
      EmocionAvatar.alegre => CapaBoca.alegre,
      EmocionAvatar.empatico => CapaBoca.suave,
      EmocionAvatar.neutral => CapaBoca.sonrisa,
    };
  }
}
