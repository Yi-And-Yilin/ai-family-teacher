import 'dart:convert';
import 'dart:io';

void main() async {
  // 加载图片
  final imageFile = File('homework_small.jpg');
  final bytes = await imageFile.readAsBytes();
  final imageBase64 = base64Encode(bytes);
  
  print('图片大小: ${imageBase64.length} bytes (base64)');
  
  // 构建请求
  final requestBody = {
    'model': 'qwen3-vl:8b',
    'messages': [
      {
        'role': 'user',
        'content': '请描述这张图片的内容',
        'images': [imageBase64],
      },
    ],
    'stream': true,
    'options': {
      'num_ctx': 32768,
    },
  };
  
  print('发送请求...');
  
  final client = HttpClient();
  try {
    final request = await HttpClient().postUrl(Uri.parse('http://localhost:11434/api/chat'));
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
          final content = data['message']['content'] as String;
          fullContent += content;
          stdout.write(content);
        }
        if (data['done'] == true) break;
      } catch (e) {
        print('解析错误: $e');
      }
    }
    
    print('\n\n==========');
    print('响应长度: ${fullContent.length} 字符');
  } catch (e) {
    print('错误: $e');
  } finally {
    client.close();
  }
}
