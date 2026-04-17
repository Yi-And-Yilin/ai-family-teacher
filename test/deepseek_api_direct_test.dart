import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_family_teacher/services/api_config.dart';

void main() {
  group('DeepSeek API 直接测试', () {
    setUpAll(() async {
      await APIConfigService.instance.init();
    });

    test('检查 DeepSeek API 配置是否正确', () {
      final config = APIConfigService.instance;

      print('\n========== DeepSeek 配置 ==========');
      print('Provider: ${config.currentProvider}');
      print('API URL: ${config.currentApiUrl}');
      print('Text Model: ${config.currentTextModel}');
      print('API Key 长度: ${config.deepseekApiKey.length}');
      print(
          'API Key 掩码: ${config.deepseekApiKey.isNotEmpty ? "****${config.deepseekApiKey.substring(config.deepseekApiKey.length - 4)}" : "空"}');
      print('是否有效: ${config.isConfigValid}');
      print('===================================\n');

      expect(config.deepseekApiKey.isNotEmpty, isTrue,
          reason: 'DeepSeek API Key 不应该为空');
      expect(config.currentApiUrl,
          equals('https://api.deepseek.com/chat/completions'));
    });

    test('直接调用 DeepSeek API 测试', () async {
      final config = APIConfigService.instance;

      print('\n========== 直接调用 DeepSeek API ==========');

      final requestBody = {
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'user',
            'content': '请说一句"你好"，只需要回复这两个字',
          },
        ],
        'stream': false, // 使用非流式方便测试
      };

      print('请求体: ${jsonEncode(requestBody)}');

      try {
        final response = await http
            .post(
              Uri.parse(config.currentApiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${config.deepseekApiKey}',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(minutes: 2));

        print('状态码: ${response.statusCode}');
        print('响应体: ${response.body}');

        expect(response.statusCode, equals(200),
            reason: 'DeepSeek API 应该返回 200');

        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        print('解析的内容: $content');

        expect(content.isNotEmpty, isTrue, reason: 'API 应该返回非空内容');
      } catch (e) {
        print('错误: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('流式调用 DeepSeek API 测试', () async {
      final config = APIConfigService.instance;

      print('\n========== 流式调用 DeepSeek API ==========');

      final requestBody = {
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'user',
            'content': '出一道小学三年级数学题',
          },
        ],
        'stream': true,
      };

      final httpRequest = http.Request('POST', Uri.parse(config.currentApiUrl));
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.headers['Authorization'] = 'Bearer ${config.deepseekApiKey}';
      httpRequest.bodyBytes = utf8.encode(jsonEncode(requestBody));

      final streamedResponse = await http.Client().send(httpRequest);

      print('状态码: ${streamedResponse.statusCode}');

      String fullContent = '';
      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr == '[DONE]') break;

          try {
            final json = jsonDecode(dataStr);
            final delta = json['choices']?[0]?['delta'];
            if (delta?['content'] != null) {
              fullContent += delta['content'];
            }
          } catch (e) {
            print('解析错误: $e, data: $dataStr');
          }
        }
      }

      print('完整内容: $fullContent');

      expect(streamedResponse.statusCode, equals(200));
      expect(fullContent.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
