import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

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
    debugPrint('[VOICE] 开始语音识别...');
    
    if (!_isSttInitialized) {
      debugPrint('[VOICE] 初始化 STT...');
      _isSttInitialized = await _stt.initialize(
        onStatus: (status) {
          debugPrint('[VOICE] STT 状态: $status');
          onStatusChanged(status == 'listening');
        },
        onError: (error) {
          debugPrint('[VOICE] STT 错误: ${error.errorMsg} - ${error.permanent}');
        },
      );
      debugPrint('[VOICE] STT 初始化结果: $_isSttInitialized');
      
      // 打印可用的语言
      final locales = await _stt.locales();
      debugPrint('[VOICE] 可用语言: ${locales.map((l) => l.localeId).join(", ")}');
    }

    if (_isSttInitialized) {
      debugPrint('[VOICE] 开始监听...');
      _stt.listen(
        onResult: (result) {
          debugPrint('[VOICE] 识别结果: "${result.recognizedWords}" (final: ${result.finalResult})');
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        localeId: "zh_CN",
        listenFor: const Duration(seconds: 10),  // 最长监听10秒
        pauseFor: const Duration(seconds: 3),    // 停顿3秒后自动结束
      );
    } else {
      debugPrint('[VOICE] STT 未初始化成功！');
    }
  }

  Future<void> stopListening() async {
    debugPrint('[VOICE] 停止监听');
    await _stt.stop();
  }

  /// 2. 文字转语音 (TTS)
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    // 清理文本：
    // 1. 过滤掉 [正在调用工具...] 等信令
    // 2. 过滤掉行前缀 (C> B> W> N>)，避免被读出来
    // 3. 过滤掉 LaTeX 公式 ($$...$$)，避免乱读
    String cleanText = text;
    cleanText = cleanText.replaceAll(RegExp(r'\[.*?\]'), '');  // 移除信令
    cleanText = cleanText.replaceAll(RegExp(r'^[CBWN]>\s*', multiLine: true), '');  // 移除行前缀（新格式）
    cleanText = cleanText.replaceAll(RegExp(r'^[CBWN]:\s*', multiLine: true), '');  // 移除行前缀（旧格式兼容）
    cleanText = cleanText.replaceAll(RegExp(r'\$\$.*?\$\$'), '',);  // 移除 LaTeX 公式
    cleanText = cleanText.replaceAll(RegExp(r'\$[^$]+\$'), '');  // 移除行内公式
    cleanText = cleanText.trim();
    
    if (cleanText.isNotEmpty) {
      await _tts.speak(cleanText);
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
