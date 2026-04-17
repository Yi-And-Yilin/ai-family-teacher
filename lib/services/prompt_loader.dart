import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 系统提示词加载器 — 从 JSON 语言包加载 AI 系统提示词
///
/// 添加新语言只需在 `lib/prompts/lang/` 下添加对应的 JSON 文件。
class PromptLoader {
  static final PromptLoader _instance = PromptLoader._internal();
  factory PromptLoader() => _instance;
  PromptLoader._internal();

  final Map<String, Map<String, dynamic>> _loadedPrompts = {};

  /// 默认回退语言
  static const String _fallbackLanguage = 'zh';

  /// 获取指定语言的系统提示词（带回退链）
  Future<String> getSystemPrompt({
    required String language,
    required String agentType, // 'study_buddy', 'question_generator', 'answer_explainer'
  }) async {
    await _loadLanguagePack(language);

    final langPack = _loadedPrompts[language];
    if (langPack == null) {
      debugPrint('[PromptLoader] No prompt pack for language: $language, falling back to $_fallbackLanguage');
      // 回退到默认语言
      await _loadLanguagePack(_fallbackLanguage);
      return _getPromptForAgent(_fallbackLanguage, agentType);
    }

    final prompt = _getPromptForAgent(language, agentType);
    if (prompt.isEmpty && language != _fallbackLanguage) {
      // 如果提示词为空且不是回退语言本身，尝试回退
      debugPrint('[PromptLoader] Empty prompt for $agentType in $language, falling back to $_fallbackLanguage');
      await _loadLanguagePack(_fallbackLanguage);
      return _getPromptForAgent(_fallbackLanguage, agentType);
    }

    return prompt;
  }

  /// 获取指定 agent 的提示词（辅助方法）
  String _getPromptForAgent(String language, String agentType) {
    final langPack = _loadedPrompts[language];
    if (langPack == null) return '';

    final agentData = langPack[agentType] as Map<String, dynamic>?;
    if (agentData == null) return '';

    return agentData['system_prompt'] as String? ?? '';
  }

  /// 获取指定语言的 AI 名称
  Future<String> getAiName({
    required String language,
    required String agentType,
  }) async {
    await _loadLanguagePack(language);

    final langPack = _loadedPrompts[language];
    if (langPack == null) return '';

    final agentData = langPack[agentType] as Map<String, dynamic>?;
    if (agentData == null) return '';

    return agentData['name'] as String? ?? '';
  }

  /// 加载语言包（如果尚未加载）
  Future<void> _loadLanguagePack(String language) async {
    if (_loadedPrompts.containsKey(language)) return;

    try {
      final jsonString = await rootBundle.loadString(
        'lib/prompts/lang/$language.json',
      );
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      _loadedPrompts[language] = data;
    } catch (e) {
      debugPrint('[PromptLoader] Failed to load prompt for language: $language — $e');
    }
  }

  /// 清除缓存（用于热重载）
  void clearCache() {
    _loadedPrompts.clear();
  }
}
