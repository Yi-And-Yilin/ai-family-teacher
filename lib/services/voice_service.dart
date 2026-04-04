import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isSttInitialized = false;

  VoiceService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("zh-CN");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// 1. 语音转文字 (STT)
  Future<void> startListening({
    required Function(String) onResult,
    required Function(bool) onStatusChanged,
  }) async {
    if (!_isSttInitialized) {
      _isSttInitialized = await _stt.initialize(
        onStatus: (status) => onStatusChanged(status == 'listening'),
        onError: (error) => print('STT Error: $error'),
      );
    }

    if (_isSttInitialized) {
      _stt.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        localeId: "zh_CN",
      );
    }
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  /// 2. 文字转语音 (TTS)
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    // 过滤掉 [正在调用工具...] 等信令，只说出正文
    final cleanText = text.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    if (cleanText.isNotEmpty) {
      await _tts.speak(cleanText);
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
