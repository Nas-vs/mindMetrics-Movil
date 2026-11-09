/// Contrato de la voz del avatar.
///
/// La Fase 4 lo implementa con `speech_to_text` + `flutter_tts` en el
/// celular. Mientras tanto, [VozSoloTexto] permite probar toda la
/// conversación escribiendo, y las pruebas usan una voz falsa.
abstract interface class ServicioVoz {
  /// Dice [texto]. El Future termina cuando acaba de hablar.
  Future<void> hablar(String texto);

  /// Escucha una respuesta. Devuelve `null` si hubo silencio, si se canceló
  /// con [detener] o si no hay micrófono.
  Future<String?> escuchar();

  /// Corta lo que esté diciendo o escuchando.
  Future<void> detener();

  /// `false` cuando la entrada es por teclado (no hay que escuchar).
  bool get admiteEscucha;
}

/// Voz de desarrollo: "habla" esperando un tiempo proporcional al texto
/// (para ver la boca del avatar moverse) y no escucha: se responde escribiendo.
class VozSoloTexto implements ServicioVoz {
  VozSoloTexto({this.msPorPalabra = 90, this.maximo = const Duration(seconds: 4)});

  final int msPorPalabra;
  final Duration maximo;

  @override
  bool get admiteEscucha => false;

  @override
  Future<void> hablar(String texto) {
    final n = texto.split(RegExp(r'\s+')).length;
    final d = Duration(milliseconds: n * msPorPalabra);
    return Future<void>.delayed(d < maximo ? d : maximo);
  }

  @override
  Future<String?> escuchar() async => null;

  @override
  Future<void> detener() async {}
}
