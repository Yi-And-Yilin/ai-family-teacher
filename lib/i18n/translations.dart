import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 轻量级翻译系统 — 基于 JSON 语言包，支持任意数量语言
///
/// ## 如何添加新语言
/// 1. 在 `lib/i18n/lang/` 目录下创建 `{language_code}.json`（如 `es.json`）
/// 2. 复制 `zh.json` 或 `en.json` 作为模板，翻译所有值
/// 3. 在语言选择器中添加对应选项
///
/// **无需修改任何 Dart 源代码！**
///
/// ## JSON 格式
/// ```json
/// {
///   "meta": { "language": "es", "name": "Español" },
///   "app_name": "Mi Compañero de Estudio",
///   "settings_language": "Idioma",
///   ...
/// }
/// ```
class Translations extends ChangeNotifier {
  static final Translations _instance = Translations._internal();
  factory Translations() => _instance;
  Translations._internal();

  String _currentLanguage = 'zh';
  String get currentLanguage => _currentLanguage;

  /// 当前语言的翻译键值对
  Map<String, String> _translations = {};

  /// 缓存的语言名称（避免重复加载 JSON）
  String _cachedLanguageName = '';

  /// 默认回退语言
  static const String _fallbackLanguage = 'zh';

  /// 初始化：加载默认语言包
  Future<void> init({String defaultLanguage = 'zh'}) async {
    _currentLanguage = defaultLanguage;
    await _loadLanguagePack(defaultLanguage);
  }

  /// 切换语言
  Future<void> setLanguage(String language) async {
    if (_currentLanguage == language) return;

    _currentLanguage = language;
    _cachedLanguageName = ''; // 清空缓存
    await _loadLanguagePack(language);
    notifyListeners();
  }

  /// 加载语言包（带回退链）
  Future<void> _loadLanguagePack(String language) async {
    try {
      final jsonString = await rootBundle.loadString(
        'lib/i18n/lang/$language.json',
      );
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // 缓存语言名称
      _cachedLanguageName = (data['meta'] as Map<String, dynamic>?)?['name'] as String? ?? language;

      // 过滤掉 "meta" 键，只保留翻译键值对
      _translations = {};
      for (final entry in data.entries) {
        if (entry.key != 'meta' && entry.value is String) {
          _translations[entry.key] = entry.value as String;
        }
      }
    } catch (e) {
      debugPrint('[Translations] Failed to load language: $language — $e');

      // 回退链：如果加载失败且不是回退语言本身，尝试加载回退语言
      if (language != _fallbackLanguage) {
        debugPrint('[Translations] Falling back to $_fallbackLanguage');
        try {
          final jsonString = await rootBundle.loadString(
            'lib/i18n/lang/$_fallbackLanguage.json',
          );
          final data = jsonDecode(jsonString) as Map<String, dynamic>;
          _translations = {};
          for (final entry in data.entries) {
            if (entry.key != 'meta' && entry.value is String) {
              _translations[entry.key] = entry.value as String;
            }
          }
        } catch (fallbackError) {
          debugPrint('[Translations] Fallback also failed: $_fallbackLanguage — $fallbackError');
          _translations = {};
        }
      } else {
        _translations = {};
      }
    }
  }

  /// 获取翻译
  ///
  /// 如果键不存在，返回键名本身作为回退
  String t(String key) {
    return _translations[key] ?? key;
  }

  /// 判断是否为当前语言
  bool isCurrent(String language) => _currentLanguage == language;

  /// 获取当前语言的名称（来自 meta，使用缓存）
  String getLanguageName() {
    if (_cachedLanguageName.isNotEmpty) {
      return _cachedLanguageName;
    }
    // 如果缓存为空（切换语言后未加载完成），返回当前语言代码
    return _currentLanguage;
  }
}
