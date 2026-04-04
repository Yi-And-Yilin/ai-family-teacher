import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import 'rag_service.dart';

/// --- 0. 日志工具 ---
class AILogger {
  static void log(String tag, String message, {Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp][$tag] $message';
    
    // 输出到控制台（会被捕获到 log.txt）
    print(logMessage);
    
    // 如果有额外数据，也打印
    if (data != null) {
      final dataStr = jsonEncode(data);
      // 如果数据太长，截断显示
      if (dataStr.length > 2000) {
        print('[$timestamp][$tag] DATA(truncated): ${dataStr.substring(0, 2000)}...');
      } else {
        print('[$timestamp][$tag] DATA: $dataStr');
      }
    }
  }

  static void logRequest(String model, Map<String, dynamic> request) {
    log('REQUEST', '发送请求到模型: $model');
    log('REQUEST_BODY', '', data: _sanitizeRequest(request));
  }

  static void logResponse(String model, String response) {
    log('RESPONSE', '收到模型 $model 的响应');
    // 如果响应太长，截断显示
    if (response.length > 2000) {
      log('RESPONSE_BODY', '${response.substring(0, 2000)}...(共${response.length}字符)');
    } else {
      log('RESPONSE_BODY', response);
    }
  }

  static Map<String, dynamic> _sanitizeRequest(Map<String, dynamic> request) {
    final sanitized = Map<String, dynamic>.from(request);
    if (sanitized['messages'] != null) {
      final messages = List.from(sanitized['messages']);
      for (var msg in messages) {
        if (msg is Map && msg['images'] != null) {
          // 截断 base64 图片数据，只显示前后 50 个字符
          final images = List.from(msg['images']);
          msg['images'] = images.map((img) => 
            '${(img as String).substring(0, img.length > 50 ? 50 : img.length)}...(${img.length} chars)'
          ).toList();
        }
      }
      sanitized['messages'] = messages;
    }
    return sanitized;
  }
}

/// --- 1. 工具定义 ---
abstract class AICommandHandler {
  String get name;
  String get description;
  Map<String, dynamic> get parameters;
  bool get needsConfirmation => false;
  Future<String> execute(Map<String, dynamic> arguments);
}

class CalculatorTool extends AICommandHandler {
  @override String get name => 'calculator';
  @override String get description => '执行数学计算。';
  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {'expression': {'type': 'string'}},
    'required': ['expression'],
  };
  @override Future<String> execute(Map<String, dynamic> arguments) async => '计算结果: ${arguments['expression']}';
}

class BlackboardTool extends AICommandHandler {
  final Function(String) onUpdate;
  BlackboardTool(this.onUpdate);
  @override String get name => 'update_blackboard';
  @override String get description => '在黑板上显示信息。';
  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {'content': {'type': 'string'}},
    'required': ['content'],
  };
  @override Future<String> execute(Map<String, dynamic> arguments) async {
    onUpdate(arguments['content']);
    return '黑板已更新。';
  }
}

class ClearBlackboardTool extends AICommandHandler {
  final Function() onClear;
  ClearBlackboardTool(this.onClear);
  @override String get name => 'clear_blackboard';
  @override String get description => '清空黑板上的所有内容。这是不可逆的操作。';
  @override Map<String, dynamic> get parameters => {'type': 'object', 'properties': {}};
  @override bool get needsConfirmation => true;
  @override Future<String> execute(Map<String, dynamic> arguments) async {
    onClear();
    return '黑板已清空。';
  }
}

class MarkWorkbookTool extends AICommandHandler {
  final Function(List<Map<String, dynamic>>) onMark;
  MarkWorkbookTool(this.onMark);
  @override String get name => 'mark_workbook';
  @override String get description => '在作业本上进行红色批改。';
  @override Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'marks': {
        'type': 'array',
        'items': {'type': 'object', 'properties': {'type': {'type': 'string'}, 'content': {'type': 'string'}, 'position': {'type': 'object'}}}
      }
    },
    'required': ['marks'],
  };
  @override Future<String> execute(Map<String, dynamic> arguments) async {
    onMark(List<Map<String, dynamic>>.from(arguments['marks']));
    return '作业本已批改。';
  }
}

/// --- 2. 智能体定义 ---
class StudyBuddyAgent {
  final Function(String) onBlackboardUpdate;
  final Function(List<Map<String, dynamic>>) onWorkbookMark;
  final Function() onBlackboardClear;
  StudyBuddyAgent(this.onBlackboardUpdate, this.onWorkbookMark, this.onBlackboardClear);

  String get systemPrompt => '''你是"小书童"，一个亲切、耐心的AI学习伙伴。

【你的身份】
- 你是学生的好朋友和学习助手
- 你擅长用简单易懂的方式讲解知识
- 你会鼓励学生，帮助他们建立学习信心

【你的能力】
- 解答各学科问题（数学、语文、英语、科学等）
- 批改作业并给出详细讲解
- 根据学生的错题出变式题帮助巩固
- 给出个性化的学习建议

【你的风格】
- 语言亲切自然，像朋友一样交流
- 讲解时循序渐进，不跳步骤
- 发现错误时先肯定对的，再指出问题
- 多用鼓励的话语

【可用工具】
- calculator: 执行数学计算
- update_blackboard: 在黑板显示讲解内容
- mark_workbook: 批改作业
- clear_blackboard: 清空黑板（需用户确认）''';

  List<AICommandHandler> get tools => [
    CalculatorTool(), 
    BlackboardTool(onBlackboardUpdate), 
    MarkWorkbookTool(onWorkbookMark),
    ClearBlackboardTool(onBlackboardClear)
  ];
}

/// --- 3. 视觉模型服务 ---
class VLService {
  // 修改为电脑的局域网 IP，手机也能访问
  final String _ollamaUrl = 'http://192.168.4.22:11434/api/chat';
  final String _vlModel = 'qwen3-vl:8b';

  static const String _vlSystemPrompt = '''你是"小书童"学习助手的图像解析模块。你的任务是解析学生上传的图片，提取其中的关键信息。

【背景信息】
- 小书童是一个面向中小学生的AI学习助手
- 学生会拍照上传题目、作业、笔记等
- 你的解析结果将交给另一个AI模型进行批改和讲解

【你的任务】
请仔细分析图片，提取以下信息（如果存在）：

1. 【题目内容】
   - 完整的题目文字
   - 题目类型（选择题/填空题/解答题/应用题等）
   - 学科（数学/语文/英语/物理/化学等）

2. 【学生答案】（如果有）
   - 学生的解答过程
   - 学生的最终答案
   - 学生做的标记或圈画

3. 【图形/图表】（如果有）
   - 几何图形的关键信息（点、线、角、形状、垂直、平行等）
   - 图表数据
   - 坐标系信息

4. 【其他信息】
   - 批改痕迹（红色勾叉等）
   - 老师评语
   - 其他重要标记

【输出要求】
请以JSON格式输出，结构如下：
```json
{
  "has_question": true或false,
  "has_student_answer": true或false,
  "subject": "学科",
  "question_type": "题型",
  "question_content": "题目完整内容",
  "student_answer": "学生最终答案",
  "student_process": "学生解答过程",
  "graphics_info": {
    "type": "图形类型",
    "elements": ["关键元素列表"]
  },
  "correction_marks": "批改痕迹描述",
  "other_info": "其他重要信息",
  "raw_text": "图片中识别到的所有文字"
}
```

注意：
- 如果某些信息不存在，对应字段填 null
- 数学公式尽量用文字描述清楚
- 图形信息要描述具体，便于后续理解''';

  Future<String> analyzeImage(String base64Image, {String? userMessage}) async {
    final requestBody = {
      'model': _vlModel,
      'messages': [
        {
          'role': 'user',
          'content': userMessage ?? '请分析这张图片中的学习内容，提取题目、学生答案和批改标记。',
          'images': [base64Image],
        },
      ],
      'stream': false,  // 使用非流式请求，更稳定
      'options': {
        'num_ctx': 32768,
      },
    };

    try {
      final client = http.Client();
      
      try {
        final response = await client.post(
          Uri.parse(_ollamaUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(const Duration(minutes: 5));
        
        if (response.statusCode != 200) {
          return '图片解析失败：服务器错误 ${response.statusCode}';
        }
        
        final data = jsonDecode(response.body);
        final content = data['message']?['content'] ?? '';
        
        return content.isEmpty ? '无法解析图片内容' : content;
      } finally {
        client.close();
      }
    } catch (e) {
      return '图片解析失败：$e';
    }
  }
}

/// --- 4. 核心服务 (多模态支持) ---
class AIService {
  // 修改为电脑的局域网 IP，手机也能访问
  final String _ollamaUrl = 'http://192.168.4.22:11434/api/chat';
  final String _model = 'qwen3.5:9b';
  late final StudyBuddyAgent _agent;
  late final VLService _vlService;
  final RAGService _ragService = RAGService();

  final Future<bool> Function(String title, String message)? onRequireConfirmation;

  AIService({
    Function(String)? onBlackboardUpdate,
    Function(List<Map<String, dynamic>>)? onWorkbookMark,
    Function()? onBlackboardClear,
    this.onRequireConfirmation,
  }) {
    _agent = StudyBuddyAgent(
      onBlackboardUpdate ?? (s) {},
      onWorkbookMark ?? (m) {},
      onBlackboardClear ?? () {},
    );
    _vlService = VLService();
  }

  /// 处理包含图片的消息（多模态流程）
  Future<String> processImageFirst(List<String> base64Images, {String? userMessage}) async {
    final results = <String>[];
    
    for (int i = 0; i < base64Images.length; i++) {
      final result = await _vlService.analyzeImage(
        base64Images[i],
        userMessage: userMessage ?? '请分析这张图片中的学习内容',
      );
      results.add('【图片${i + 1}解析结果】\n$result');
    }
    
    return results.join('\n\n');
  }

  Stream<String> processDialogue(List<Message> history) async* {
    final currentHistory = List<Message>.from(history);
    currentHistory.insert(0, Message(
      id: 'sys',
      conversationId: 'current',
      role: MessageRole.system,
      content: _agent.systemPrompt,
      timestamp: DateTime.now(),
    ));

    bool isDone = false;
    int safetyCounter = 0;

    while (!isDone && safetyCounter < 5) {
      safetyCounter++;
      
      final messages = currentHistory.map((m) {
        final map = <String, dynamic>{
          'role': m.role.name,
          'content': m.content,
        };
        if (m.toolCalls != null) {
          map['tool_calls'] = m.toolCalls;
        }
        if (m.toolCallId != null) {
          map['tool_call_id'] = m.toolCallId!;
        }
        return map;
      }).toList();

      final requestBody = {
        'model': _model,
        'messages': messages,
        'tools': _agent.tools.map((t) => {
          'type': 'function',
          'function': {
            'name': t.name,
            'description': t.description,
            'parameters': t.parameters,
          },
        }).toList(),
        'stream': true,
        'options': {
          'num_ctx': 131072,  // 128K context window
        },
      };

      // 记录请求日志
      AILogger.logRequest(_model, requestBody);

      // 使用 http 包发送请求
      final httpRequest = http.Request('POST', Uri.parse(_ollamaUrl));
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.bodyBytes = utf8.encode(jsonEncode(requestBody));
      
      final streamedResponse = await http.Client().send(httpRequest);
      String fullContent = '';
      List<Map<String, dynamic>>? pendingToolCalls;

      await for (final line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        try {
          final data = jsonDecode(line);
          if (data['message']?['content'] != null) {
            fullContent += data['message']['content'];
            yield data['message']['content'];
          }
          if (data['message']?['tool_calls'] != null) {
            pendingToolCalls = List<Map<String, dynamic>>.from(data['message']['tool_calls']);
          }
          if (data['done'] == true) break;
        } catch (_) {
          // 忽略解析错误
        }
      }

      // 记录响应日志
      AILogger.logResponse(_model, fullContent);

      if (pendingToolCalls != null) {
        currentHistory.add(Message(
          id: 'ai_$safetyCounter',
          conversationId: 'current',
          role: MessageRole.assistant,
          content: fullContent,
          toolCalls: pendingToolCalls,
          timestamp: DateTime.now(),
        ));
        
        for (final call in pendingToolCalls) {
          final funcName = call['function']['name'];
          final funcArgsStr = call['function']['arguments'];
          final funcArgs = funcArgsStr is String ? jsonDecode(funcArgsStr) : funcArgsStr;
          
          final tool = _agent.tools.firstWhere((t) => t.name == funcName);

          if (tool.needsConfirmation && onRequireConfirmation != null) {
            yield '\n[等待用户确认操作: $funcName...]\n';
            final confirmed = await onRequireConfirmation!(
              '确认操作',
              'AI 想要执行 $funcName，描述为：${tool.description}。你同意吗？',
            );
            if (!confirmed) {
              final result = '用户拒绝了此操作。';
              currentHistory.add(Message(
                id: 'tool_$safetyCounter',
                conversationId: 'current',
                role: MessageRole.tool,
                content: result,
                toolCallId: call['id'],
                timestamp: DateTime.now(),
              ));
              continue;
            }
          }

          final result = await tool.execute(funcArgs);
          yield '\n[工具 $funcName 执行结果: $result]\n';
          currentHistory.add(Message(
            id: 'tool_$safetyCounter',
            conversationId: 'current',
            role: MessageRole.tool,
            content: result,
            toolCallId: call['id'],
            timestamp: DateTime.now(),
          ));
        }
      } else {
        isDone = true;
      }
    }
  }

  /// 主入口：根据是否有图片选择处理流程
  Stream<ChatChunk> answerQuestionStream({
    required List<Message> history,
    List<String>? images,
    Map<String, dynamic>? envContext,
  }) async* {
    AILogger.log('ENTRY', '收到用户请求', data: {
      'has_images': images != null && images.isNotEmpty,
      'image_count': images?.length ?? 0,
      'history_count': history.length,
    });

    // 如果有图片，先调用 VL 模型
    if (images != null && images.isNotEmpty) {
      AILogger.log('FLOW', '检测到图片，启动多模态流程');
      yield ChatChunk(content: '[正在分析图片...]\n');
      
      final vlResult = await processImageFirst(images);
      
      AILogger.log('VL_RESULT', 'VL模型解析结果', data: {'result': vlResult});
      
      yield ChatChunk(content: '[图片分析完成]\n\n');
      
      // 将 VL 结果作为用户消息添加到历史
      final lastUserMsg = history.lastWhere(
        (m) => m.role == MessageRole.user,
        orElse: () => Message(
          id: 'temp',
          conversationId: 'current',
          role: MessageRole.user,
          content: '',
          timestamp: DateTime.now(),
        ),
      );
      
      // 创建包含图片解析结果的新消息
      final enrichedMessage = Message(
        id: lastUserMsg.id,
        conversationId: lastUserMsg.conversationId,
        role: MessageRole.user,
        content: '${lastUserMsg.content}\n\n$vlResult',
        timestamp: lastUserMsg.timestamp,
      );
      
      // 替换最后一条用户消息
      final newHistory = List<Message>.from(history);
      final lastIndex = newHistory.lastIndexWhere((m) => m.role == MessageRole.user);
      if (lastIndex != -1) {
        newHistory[lastIndex] = enrichedMessage;
      }
      
      AILogger.log('FLOW', '开始调用文本模型进行推理');
      
      // 继续用文本模型处理
      await for (final text in processDialogue(newHistory)) {
        yield ChatChunk(content: text);
      }
    } else {
      // 没有图片，直接用文本模型处理
      await for (final text in processDialogue(history)) {
        yield ChatChunk(content: text);
      }
    }
  }
}

class ChatChunk {
  final String? content;
  final String? thinking;
  final List<Map<String, dynamic>>? toolCalls;
  final bool done;
  
  ChatChunk({
    this.content,
    this.thinking,
    this.toolCalls,
    this.done = false,
  });
}