import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/services/ai_service.dart';
import 'package:ai_family_teacher/services/api_config.dart';
import 'package:ai_family_teacher/models/conversation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('AIService Backend Integration Tests', () {
    setUpAll(() async {
      // 初始化 sqflite_ffi（测试环境必须）
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // 初始化配置（幂等，多次调用无副作用）
      await APIConfigService.instance.init();
      
      // 初始化日志记录器
      await AILogger.init();
    });

    // 测试结束后刷新日志
    tearDownAll(() async {
      print('\n[TEST] 测试结束，正在刷新日志到 log.txt...');
      await AILogger.flush();
    });

      test('纯文本对话 - Handler 应返回有效响应', () async {
        // ========== 1. 模拟 UI 层发出的信号 ==========
        final history = [
          Message(
            id: '1',
            conversationId: 'test',
            role: MessageRole.user,
            content: '请给我出一道小学五年级的数学题',
            timestamp: DateTime.now(),
          ),
        ];

      // ========== 2. 直接调用 Handler（无需准备） ==========
      final aiService = AIService();
      final chunks = <ChatChunk>[];
      await for (final chunk in aiService.answerQuestionStream(history: history)) {
        chunks.add(chunk);
        if (chunk.done) break;
      }

      // ========== 3. 验证返回结果 ==========
      // 收集所有内容
      final allContent = <String>[];
      final allBlackboard = <String>[];
      
      for (final c in chunks) {
        if (c.content != null) allContent.add(c.content!);
        if (c.blackboardContent != null) allBlackboard.add(c.blackboardContent!);
      }

      final fullContent = allContent.join();
      final fullBlackboard = allBlackboard.join();

      print('\n========== 结果摘要 ==========');
      print('对话内容: ${fullContent.length} 字符');
      print('黑板内容: ${fullBlackboard.length} 字符');
      print('========================================\n');

      expect(fullContent.length + fullBlackboard.length,
             greaterThan(0),
             reason: 'Handler 应返回内容');
      expect(fullBlackboard.isEmpty, isTrue, reason: '出题模式不应有黑板内容');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
