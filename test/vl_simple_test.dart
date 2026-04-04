import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// 直接复制 VLService 的逻辑来测试
void main() {
  test('直接测试 VL 模型请求', () async {
    // 加载图片
    final imageFile = File('homework_small.jpg');
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    print('图片大小: ${base64Image.length}');
    
    final requestBody = {
      'model': 'qwen3-vl:8b',
      'messages': [
        {
          'role': 'user',
          'content': '请分析这张图片中的学习内容',
          'images': [base64Image],
        },
      ],
      'stream': true,
      'options': {
        'num_ctx': 32768,
      },
    };
    
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('http://localhost:11434/api/chat'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(requestBody));
    
    final response = await request.close();
    print('状态码: ${response.statusCode}');
    
    String fullContent = '';
    await for (final line in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) continue;
      try {
        final data = jsonDecode(line);
        if (data['message']?['content'] != null) {
          fullContent += data['message']['content'] as String;
        }
        if (data['done'] == true) break;
      } catch (_) {}
    }
    
    client.close();
    print('响应长度: ${fullContent.length}');
    
    expect(response.statusCode, equals(200));
    expect(fullContent.length, greaterThan(100));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
