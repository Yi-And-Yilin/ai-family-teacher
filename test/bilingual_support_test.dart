import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

/// Comprehensive unit tests for the bilingual/multi-language support system
/// 
/// Tests cover:
/// 1. JSON language pack integrity (UI translations)
/// 2. JSON prompt pack integrity (AI system prompts)
/// 3. Language validation logic
/// 4. Translation key completeness and parity
void main() {
  final projectRoot = Directory.current.path;
  final i18nDir = path.join(projectRoot, 'lib', 'i18n', 'lang');
  final promptsDir = path.join(projectRoot, 'lib', 'prompts', 'lang');

  group('JSON Language Pack Integrity (UI Translations)', () {
    test('zh.json is valid JSON', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      expect(file.existsSync(), isTrue, reason: 'zh.json must exist');
      
      final jsonString = file.readAsStringSync();
      expect(() => jsonDecode(jsonString), returnsNormally,
          reason: 'zh.json should be valid JSON');
    });

    test('en.json is valid JSON', () {
      final file = File(path.join(i18nDir, 'en.json'));
      expect(file.existsSync(), isTrue, reason: 'en.json must exist');
      
      final jsonString = file.readAsStringSync();
      expect(() => jsonDecode(jsonString), returnsNormally,
          reason: 'en.json should be valid JSON');
    });

    test('zh.json has meta section with correct structure', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      expect(data.containsKey('meta'), isTrue,
          reason: 'zh.json must have a meta section');
      
      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['language'], 'zh',
          reason: 'meta.language should be "zh"');
      expect(meta['name'], isA<String>(),
          reason: 'meta.name should be a string');
      expect((meta['name'] as String).isNotEmpty, isTrue,
          reason: 'meta.name should not be empty');
    });

    test('en.json has meta section with correct structure', () {
      final file = File(path.join(i18nDir, 'en.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      expect(data.containsKey('meta'), isTrue,
          reason: 'en.json must have a meta section');
      
      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['language'], 'en',
          reason: 'meta.language should be "en"');
      expect(meta['name'], isA<String>(),
          reason: 'meta.name should be a string');
      expect((meta['name'] as String).isNotEmpty, isTrue,
          reason: 'meta.name should not be empty');
    });

    test('zh.json and en.json have identical keys (100% parity)', () {
      final zhFile = File(path.join(i18nDir, 'zh.json'));
      final enFile = File(path.join(i18nDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      // 移除 meta 键后比较
      final zhKeys = zhData.keys.where((k) => k != 'meta').toSet();
      final enKeys = enData.keys.where((k) => k != 'meta').toSet();
      
      final missingInEn = zhKeys.difference(enKeys);
      final missingInZh = enKeys.difference(zhKeys);
      
      expect(missingInEn, isEmpty,
          reason: 'Keys missing in en.json: ${missingInEn.join(", ")}');
      expect(missingInZh, isEmpty,
          reason: 'Keys missing in zh.json: ${missingInZh.join(", ")}');
    });

    test('zh.json has sufficient translation keys (>= 100)', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final keyCount = data.keys.where((k) => k != 'meta').length;
      expect(keyCount, greaterThanOrEqualTo(100),
          reason: 'Language pack should have at least 100 translation keys, got $keyCount');
    });

    test('en.json has same key count as zh.json', () {
      final zhFile = File(path.join(i18nDir, 'zh.json'));
      final enFile = File(path.join(i18nDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      final zhKeyCount = zhData.keys.where((k) => k != 'meta').length;
      final enKeyCount = enData.keys.where((k) => k != 'meta').length;
      
      expect(enKeyCount, equals(zhKeyCount),
          reason: 'en.json should have same number of keys as zh.json ($zhKeyCount vs $enKeyCount)');
    });

    test('all values in zh.json are non-empty strings', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final emptyKeys = <String>[];
      for (final entry in data.entries) {
        if (entry.key == 'meta') continue;
        
        if (entry.value is! String || (entry.value as String).isEmpty) {
          emptyKeys.add(entry.key);
        }
      }
      
      expect(emptyKeys, isEmpty,
          reason: 'Keys with empty values in zh.json: ${emptyKeys.join(", ")}');
    });

    test('all values in en.json are non-empty strings', () {
      final file = File(path.join(i18nDir, 'en.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final emptyKeys = <String>[];
      for (final entry in data.entries) {
        if (entry.key == 'meta') continue;
        
        if (entry.value is! String || (entry.value as String).isEmpty) {
          emptyKeys.add(entry.key);
        }
      }
      
      expect(emptyKeys, isEmpty,
          reason: 'Keys with empty values in en.json: ${emptyKeys.join(", ")}');
    });

    test('critical UI keys exist in zh.json', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final criticalKeys = [
        'app_name',
        'ai_companion',
        'settings_language',
        'dialog_delete_title',
        'dialog_delete_confirm',
        'dialog_cancel',
        'dialog_agree',
        'common_loading',
        'common_error',
        'common_confirm',
        'common_delete',
      ];
      
      final missingKeys = <String>[];
      for (final key in criticalKeys) {
        if (!data.containsKey(key)) {
          missingKeys.add(key);
        }
      }
      
      expect(missingKeys, isEmpty,
          reason: 'Missing critical keys in zh.json: ${missingKeys.join(", ")}');
    });

    test('critical UI keys exist in en.json', () {
      final file = File(path.join(i18nDir, 'en.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final criticalKeys = [
        'app_name',
        'ai_companion',
        'settings_language',
        'dialog_delete_title',
        'dialog_delete_confirm',
        'dialog_cancel',
        'dialog_agree',
        'common_loading',
        'common_error',
        'common_confirm',
        'common_delete',
      ];
      
      final missingKeys = <String>[];
      for (final key in criticalKeys) {
        if (!data.containsKey(key)) {
          missingKeys.add(key);
        }
      }
      
      expect(missingKeys, isEmpty,
          reason: 'Missing critical keys in en.json: ${missingKeys.join(", ")}');
    });

    test('tool call indicator keys exist in zh.json', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final toolKeys = [
        'tool_create_workbook_progress',
        'tool_create_workbook_done',
        'tool_create_question_progress',
        'tool_create_question_done',
        'tool_grade_answer_progress',
        'tool_grade_answer_done',
        'tool_grade_workbook_progress',
        'tool_grade_workbook_done',
        'tool_explain_solution_progress',
        'tool_explain_solution_done',
        'tool_executing',
        'tool_fetching_response',
      ];
      
      final missingKeys = <String>[];
      for (final key in toolKeys) {
        if (!data.containsKey(key)) {
          missingKeys.add(key);
        }
      }
      
      expect(missingKeys, isEmpty,
          reason: 'Missing tool call keys in zh.json: ${missingKeys.join(", ")}');
    });

    test('tool call indicator keys exist in en.json', () {
      final file = File(path.join(i18nDir, 'en.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final toolKeys = [
        'tool_create_workbook_progress',
        'tool_create_workbook_done',
        'tool_create_question_progress',
        'tool_create_question_done',
        'tool_grade_answer_progress',
        'tool_grade_answer_done',
        'tool_grade_workbook_progress',
        'tool_grade_workbook_done',
        'tool_explain_solution_progress',
        'tool_explain_solution_done',
        'tool_executing',
        'tool_fetching_response',
      ];
      
      final missingKeys = <String>[];
      for (final key in toolKeys) {
        if (!data.containsKey(key)) {
          missingKeys.add(key);
        }
      }
      
      expect(missingKeys, isEmpty,
          reason: 'Missing tool call keys in en.json: ${missingKeys.join(", ")}');
    });

    test('landing page keys exist in both languages', () {
      final zhFile = File(path.join(i18nDir, 'zh.json'));
      final enFile = File(path.join(i18nDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      final landingKeys = [
        'landing_morning',
        'landing_afternoon',
        'landing_evening',
        'landing_ready',
        'landing_quick_start',
        'landing_chat',
        'landing_workbook',
        'landing_notebook',
        'landing_blackboard',
      ];
      
      for (final key in landingKeys) {
        expect(zhData.containsKey(key), isTrue,
            reason: 'zh.json must have landing key: $key');
        expect(enData.containsKey(key), isTrue,
            reason: 'en.json must have landing key: $key');
      }
    });

    test('settings keys exist in both languages', () {
      final zhFile = File(path.join(i18nDir, 'zh.json'));
      final enFile = File(path.join(i18nDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      final settingsKeys = [
        'settings_api_title',
        'settings_select_provider',
        'settings_save',
        'settings_cancel',
        'settings_import',
        'settings_saving',
      ];
      
      for (final key in settingsKeys) {
        expect(zhData.containsKey(key), isTrue,
            reason: 'zh.json must have settings key: $key');
        expect(enData.containsKey(key), isTrue,
            reason: 'en.json must have settings key: $key');
      }
    });
  });

  group('JSON Prompt Packs (AI System Prompts)', () {
    test('zh.json prompts is valid JSON', () {
      final file = File(path.join(promptsDir, 'zh.json'));
      expect(file.existsSync(), isTrue, reason: 'zh prompts must exist');
      
      final jsonString = file.readAsStringSync();
      expect(() => jsonDecode(jsonString), returnsNormally,
          reason: 'zh prompts should be valid JSON');
    });

    test('en.json prompts is valid JSON', () {
      final file = File(path.join(promptsDir, 'en.json'));
      expect(file.existsSync(), isTrue, reason: 'en prompts must exist');
      
      final jsonString = file.readAsStringSync();
      expect(() => jsonDecode(jsonString), returnsNormally,
          reason: 'en prompts should be valid JSON');
    });

    test('zh.json prompts has study_buddy with non-empty prompt', () {
      final file = File(path.join(promptsDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      expect(data.containsKey('study_buddy'), isTrue,
          reason: 'zh prompts must have study_buddy agent');
      expect(data['study_buddy']['name'], isA<String>(),
          reason: 'study_buddy must have a name');
      expect(data['study_buddy']['system_prompt'], isA<String>(),
          reason: 'study_buddy must have a system_prompt');
      expect((data['study_buddy']['system_prompt'] as String).isNotEmpty, isTrue,
          reason: 'study_buddy system_prompt should not be empty');
    });

    test('en.json prompts has study_buddy with non-empty prompt', () {
      final file = File(path.join(promptsDir, 'en.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      expect(data.containsKey('study_buddy'), isTrue,
          reason: 'en prompts must have study_buddy agent');
      expect(data['study_buddy']['name'], isA<String>(),
          reason: 'study_buddy must have a name');
      expect(data['study_buddy']['system_prompt'], isA<String>(),
          reason: 'study_buddy must have a system_prompt');
      expect((data['study_buddy']['system_prompt'] as String).isNotEmpty, isTrue,
          reason: 'study_buddy system_prompt should not be empty');
    });

    test('prompt packs have all required agents', () {
      final zhFile = File(path.join(promptsDir, 'zh.json'));
      final enFile = File(path.join(promptsDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      final requiredAgents = ['study_buddy', 'question_generator', 'answer_explainer'];
      
      for (final agent in requiredAgents) {
        expect(zhData.containsKey(agent), isTrue,
            reason: 'zh prompts must have agent: $agent');
        expect(enData.containsKey(agent), isTrue,
            reason: 'en prompts must have agent: $agent');
      }
    });

    test('all agents have required fields', () {
      final zhFile = File(path.join(promptsDir, 'zh.json'));
      final enFile = File(path.join(promptsDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      final agents = ['study_buddy', 'question_generator', 'answer_explainer'];
      
      for (final langData in [zhData, enData]) {
        for (final agent in agents) {
          final agentData = langData[agent] as Map<String, dynamic>?;
          if (agentData != null) {
            // study_buddy must have name and system_prompt
            if (agent == 'study_buddy') {
              expect(agentData.containsKey('name'), isTrue,
                  reason: '$agent must have a name field');
              expect(agentData.containsKey('system_prompt'), isTrue,
                  reason: '$agent must have a system_prompt field');
              expect((agentData['system_prompt'] as String).isNotEmpty, isTrue,
                  reason: '$agent system_prompt should not be empty');
            } else {
              // Other agents must at least have system_prompt field (can be empty)
              expect(agentData.containsKey('system_prompt'), isTrue,
                  reason: '$agent must have a system_prompt field');
            }
          }
        }
      }
    });
  });

  group('Language Validation Logic', () {
    test('valid language codes should pass validation', () {
      final validCodes = ['zh', 'en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'ru'];
      final invalidPattern = RegExp(r'[^a-zA-Z]');
      
      for (final code in validCodes) {
        final isValid = code.isNotEmpty && !code.contains(invalidPattern);
        expect(isValid, isTrue,
            reason: '"$code" should be a valid language code');
      }
    });

    test('invalid language codes should fail validation', () {
      final invalidCodes = [
        '',           // empty
        'zh-CN',      // contains hyphen
        'en_US',      // contains underscore
        'es ',        // contains space
        '123',        // numeric only
        'zh.json',    // contains dot
        'en.json',    // contains dot
      ];
      final invalidPattern = RegExp(r'[^a-zA-Z]');
      
      for (final code in invalidCodes) {
        final isValid = code.isNotEmpty && !code.contains(invalidPattern);
        expect(isValid, isFalse,
            reason: '"$code" should be an invalid language code');
      }
    });

    test('language codes with special characters should be rejected', () {
      final invalidPattern = RegExp(r'[^a-zA-Z]');
      final specialChars = ['@', '#', r'$', '%', '&', '*', '1', '2', '3', '-', '_', ' ', '.'];
      
      for (final char in specialChars) {
        final code = 'zh$char';
        final isValid = code.isNotEmpty && !code.contains(invalidPattern);
        expect(isValid, isFalse,
            reason: 'Language code with special character "$char" should be invalid');
      }
    });
  });

  group('Translation Value Quality Checks', () {
    test('English translations should not contain Chinese characters', () {
      final file = File(path.join(i18nDir, 'en.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final chinesePattern = RegExp(r'[\u4e00-\u9fff]');
      final keysWithChinese = <String>[];
      
      for (final entry in data.entries) {
        if (entry.key == 'meta') continue;
        
        if (entry.value is String && chinesePattern.hasMatch(entry.value as String)) {
          keysWithChinese.add(entry.key);
        }
      }
      
      expect(keysWithChinese, isEmpty,
          reason: 'English translations should not contain Chinese characters: ${keysWithChinese.join(", ")}');
    });

    test('Chinese translations should contain Chinese characters', () {
      final file = File(path.join(i18nDir, 'zh.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      
      final chinesePattern = RegExp(r'[\u4e00-\u9fff]');
      final keysWithoutChinese = <String>[];
      
      for (final entry in data.entries) {
        if (entry.key == 'meta') continue;
        
        if (entry.value is String && !chinesePattern.hasMatch(entry.value as String)) {
          keysWithoutChinese.add(entry.key);
        }
      }
      
      // Allow some keys to be without Chinese (e.g., URLs, codes)
      final maxAllowedWithout = 5;
      expect(keysWithoutChinese.length, lessThanOrEqualTo(maxAllowedWithout),
          reason: 'Too many Chinese keys without Chinese characters: ${keysWithoutChinese.join(", ")}');
    });

    test('no placeholder keys remain untranslated', () {
      final zhFile = File(path.join(i18nDir, 'zh.json'));
      final enFile = File(path.join(i18nDir, 'en.json'));
      
      final zhData = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      final enData = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      
      // Check for placeholder patterns that might indicate incomplete translation
      final placeholderPatterns = [
        RegExp(r'^TODO$', caseSensitive: false),
        RegExp(r'^PLACEHOLDER$', caseSensitive: false),
        RegExp(r'^TRANSLATE_ME$', caseSensitive: false),
        RegExp(r'^FIX_ME$', caseSensitive: false),
      ];
      
      final placeholderKeys = <String>[];
      
      for (final data in [zhData, enData]) {
        for (final entry in data.entries) {
          if (entry.key == 'meta') continue;
          
          for (final pattern in placeholderPatterns) {
            if (pattern.hasMatch(entry.value as String)) {
              placeholderKeys.add('${entry.key}=${entry.value}');
            }
          }
        }
      }
      
      expect(placeholderKeys, isEmpty,
          reason: 'Placeholder values found: ${placeholderKeys.join(", ")}');
    });
  });
}
