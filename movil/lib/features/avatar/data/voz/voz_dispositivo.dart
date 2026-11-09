import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/servicio_voz.dart';
import 'escucha_una_vez.dart';
import 'idiomas.dart';

/// Resultado de [VozDispositivo.preparar].
enum DisponibilidadVoz {
  lista,

  /// El usuario negó el micrófono o el reconocimiento de voz.
  sinPermiso,

  /// El celular no tiene servicio de reconocimiento (raro; algunos Android
  /// sin servicios de Google).
  sinReconocedor,

  /// No hay voz ni reconocimiento en español.
  sinEspanol,
}

/// Voz real en el celular: `speech_to_text` para escuchar y `flutter_tts`
/// para hablar. Todo ocurre en el dispositivo; MindMetrics nunca guarda audio,
/// solo el texto de las respuestas.
///
/// Privacidad: en Android el reconocedor es el de Google y puede enviar el
/// audio a sus servidores; en iOS lo procesa Apple. Por eso la app pide el
/// consentimiento de voz antes de usar esta clase.
class VozDispositivo implements ServicioVoz {
  VozDispositivo({
    SpeechToText? stt,
    FlutterTts? tts,
    this.escuchaMaxima = const Duration(seconds: 20),
    this.silencioFinal = const Duration(seconds: 3),
  })  : _stt = stt ?? SpeechToText(),
        _tts = tts ?? FlutterTts();

  final SpeechToText _stt;
  final FlutterTts _tts;

  /// Tiempo máximo de una respuesta.
  final Duration escuchaMaxima;

  /// Silencio tras el que se da por terminada la respuesta.
  final Duration silencioFinal;

  String? _idiomaEscucha;
  EscuchaUnaVez? _escucha;

  @override
  bool get admiteEscucha => true;

  /// Pide permisos y configura idioma y audio. Llamar una vez antes de usarla.
  Future<DisponibilidadVoz> preparar() async {
    final ok = await _stt.initialize(
      onStatus: (estado) => _escucha?.alEstado(estado),
      onError: (SpeechRecognitionError e) => _escucha?.alError(e.errorMsg),
    );
    if (!ok) {
      return await _stt.hasPermission ? DisponibilidadVoz.sinReconocedor : DisponibilidadVoz.sinPermiso;
    }

    final locales = await _stt.locales();
    final sistema = await _stt.systemLocale();
    _idiomaEscucha = elegirIdioma(locales.map((l) => l.localeId), delSistema: sistema?.localeId);

    final idiomasTts = ((await _tts.getLanguages) as List?)?.map((e) => '$e') ?? const <String>[];
    final idiomaTts = elegirIdioma(idiomasTts);
    if (_idiomaEscucha == null || idiomaTts == null) return DisponibilidadVoz.sinEspanol;

    await _tts.setLanguage(idiomaTts);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.05);
    await _tts.awaitSpeakCompletion(true);
    if (!kIsWeb && Platform.isIOS) {
      // Hablar y escuchar en la misma sesión de audio, por el altavoz.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ]);
    }
    return DisponibilidadVoz.lista;
  }

  @override
  Future<void> hablar(String texto) async {
    // Las comillas «» se leen raro en algunos motores de voz.
    await _tts.speak(texto.replaceAll(RegExp('[«»]'), ''));
  }

  @override
  Future<String?> escuchar() async {
    _escucha?.cancelar();
    final escucha = _escucha = EscuchaUnaVez();
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) =>
          escucha.alResultado(r.recognizedWords, esFinal: r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _idiomaEscucha,
        listenFor: escuchaMaxima,
        pauseFor: silencioFinal,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    final texto = await escucha.futuro;
    if (identical(_escucha, escucha)) _escucha = null;
    return texto;
  }

  @override
  Future<void> detener() async {
    _escucha?.cancelar();
    await _tts.stop();
    if (_stt.isListening) await _stt.cancel();
  }
}
