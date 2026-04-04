import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/services/ai_service.dart';
import 'package:ai_family_teacher/models/conversation.dart';

void main() {
  group('VL Model Tests', () {
    late AIService aiService;
    late String testImageBase64;

    setUpAll(() async {
      // 加载测试图片
      final imageFile = File('homework_small.jpg');
      final bytes = await imageFile.readAsBytes();
      testImageBase64 = base64Encode(bytes);
      print('测试图片已加载, 文件大小: ${bytes.length} bytes');
    });

    test('完整多模态流程测试', () async {
      aiService = AIService();
      
      print('\n========== 开始完整多模态测试 ==========');
      
      // 模拟用户消息
      final history = <Message>[];
      history.add(Message(
        id: 'test_1',
        conversationId: 'test_conv',
        role: MessageRole.user,
        content: '请帮我看看这道题做得对不对',
        images: [testImageBase64],
        timestamp: DateTime.now(),
      ));
      
      print('用户消息: ${history.last.content}');
      print('图片数量: ${history.last.images?.length ?? 0}');
      
      // 调用 AI 服务
      final chunks = <String>[];
      await for (final chunk in aiService.answerQuestionStream(
        history: history,
        images: [testImageBase64],
      )) {
        if (chunk.content != null) {
          chunks.add(chunk.content!);
          // 打印前 100 字符
          if (chunk.content!.length > 10) {
            print('收到chunk: ${chunk.content!.length > 100 ? chunk.content!.substring(0, 100) + "..." : chunk.content}');
          }
        }
      }
      
      final fullResponse = chunks.join();
      print('\n========== 完整响应 ==========');
      print('响应长度: ${fullResponse.length} 字符');
      print('响应前500字符: ${fullResponse.length > 500 ? fullResponse.substring(0, 500) + "..." : fullResponse}');
      
      // 验证响应不为空
      expect(fullResponse.length, greaterThan(100), reason: '响应应该包含内容');
      
      // 验证 VL 解析结果被包含在响应中
      // 如果成功，应该能看到题目相关的内容
      
      print('\n========== 测试通过 ==========');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
