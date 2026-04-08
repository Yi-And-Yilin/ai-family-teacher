import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/conversation.dart';
import '../prompts/prompts.dart';
import '../prompts/question_generator_prompt.dart';
import '../prompts/answer_explainer_prompt.dart';
import 'rag_service.dart';
import 'api_config.dart';
import 'agents_service.dart';

/// --- 0. 日志工具 ---
class AILogger {
  static File? _logFile;
  static bool _initialized = false;
  static const int _maxLogSize = 5 * 1024 * 1024; // 5MB 最大日志大小
  
  /// 初始化日志文件
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      // 获取项目根目录（通过查找 pubspec.yaml）
      Directory currentDir = Directory.current;
      _logFile = File('${currentDir.path}/log.txt');
      
      // 如果日志文件太大，清空它
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxLogSize) {
          await _logFile!.writeAsString('');
        }
      }
      
      _initialized = true;
      
      // 写入会话分隔符
      await _writeToFile('\n${'='*60}\n新会话开始: ${DateTime.now().toIso8601String()}\n${'='*60}\n');
    } catch (e) {
      // 初始化失败，仅使用控制台输出
      print('[AILogger] 日志文件初始化失败: $e');
    }
  }
  
  /// 写入日志到文件
  static Future<void> _writeToFile(String content) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString(
        content,
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // 忽略写入错误
    }
  }

  static void log(String tag, String message, {Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp][$tag] $message';
    
    // 输出到控制台
    print(logMessage);
    
    // 写入文件（异步，不阻塞）
    _writeToFile('$logMessage\n');
    
    // 如果有额外数据，也打印
    if (data != null) {
      final dataStr = jsonEncode(data);
      final dataLog = dataStr.length > 2000 
          ? '[$timestamp][$tag] DATA(truncated): ${dataStr.substring(0, 2000)}...'
          : '[$timestamp][$tag] DATA: $dataStr';
      print(dataLog);
      _writeToFile('$dataLog\n');
    }
  }

  static void logRequest(String model, Map<String, dynamic> request, {String? provider}) {
    log('REQUEST', '发送请求到模型: $model (Provider: ${provider ?? "unknown"})');
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
        // GLM 格式的图片
        if (msg is Map && msg['content'] is List) {
          final content = List.from(msg['content']);
          for (var item in content) {
            if (item is Map && item['type'] == 'image_url') {
              item['image_url'] = {'url': '[IMAGE_DATA_HIDDEN]'};
            }
          }
        }
      }
      sanitized['messages'] = messages;
    }
    return sanitized;
  }
}

/// --- 1. 智能体定义 (纯行前缀协议，无工具调用) ---
class StudyBuddyAgent {
  final AgentType agentType;
  
  StudyBuddyAgent({
    this.agentType = AgentType.studyBuddy,
  });

  String get systemPrompt {
    switch (agentType) {
      case AgentType.studyBuddy:
        return baseSystemPrompt;
      case AgentType.questionGenerator:
        return questionGeneratorPrompt;
      case AgentType.answerExplainer:
        return answerExplainerPrompt;
    }
  }
  
  // 不再使用工具调用，完全依赖行前缀协议
  // C> 聊天区, B> 黑板, W> 做题册, N> 笔记本
}

/// --- 3. 视觉模型服务 ---
class VLService {
  final APIConfigService _config;
  
  VLService(this._config);

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
    if (_config.isGLM) {
      return _analyzeWithGLM(base64Image, userMessage: userMessage);
    } else {
      return _analyzeWithOllama(base64Image, userMessage: userMessage);
    }
  }

  /// 使用 GLM API 分析图片
  Future<String> _analyzeWithGLM(String base64Image, {String? userMessage}) async {
    final requestBody = {
      'model': _config.currentVisionModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': userMessage ?? '请分析这张图片中的学习内容，提取题目、学生答案和批改标记。',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': base64Image.startsWith('data:') 
                    ? base64Image 
                    : 'data:image/jpeg;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'stream': false,
    };

    try {
      final client = http.Client();
      
      try {
        final response = await client.post(
          Uri.parse(_config.currentApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_config.glmApiKey}',
          },
          body: jsonEncode(requestBody),
        ).timeout(const Duration(minutes: 5));
        
        if (response.statusCode != 200) {
          final errorBody = jsonDecode(response.body);
          return '图片解析失败：${errorBody['error']?['message'] ?? response.statusCode}';
        }
        
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        
        return content.isEmpty ? '无法解析图片内容' : content;
      } finally {
        client.close();
      }
    } catch (e) {
      return '图片解析失败：$e';
    }
  }

  /// 使用 Ollama API 分析图片
  Future<String> _analyzeWithOllama(String base64Image, {String? userMessage}) async {
    final requestBody = {
      'model': _config.currentVisionModel,
      'messages': [
        {
          'role': 'user',
          'content': userMessage ?? '请分析这张图片中的学习内容，提取题目、学生答案和批改标记。',
          'images': [base64Image],
        },
      ],
      'stream': false,
      'options': {
        'num_ctx': 32768,
      },
    };

    try {
      final client = http.Client();
      
      try {
        final response = await client.post(
          Uri.parse(_config.currentApiUrl),
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
  final APIConfigService _config;
  late final StudyBuddyAgent _agent;
  late final VLService _vlService;
  final RAGService _ragService = RAGService();

  final Future<bool> Function(String title, String message)? onRequireConfirmation;

  AIService({
    required APIConfigService config,
    Function(String)? onBlackboardUpdate,
    Function(List<Map<String, dynamic>>)? onWorkbookMark,
    Function()? onBlackboardClear,
    this.onRequireConfirmation,
  }) : _config = config {
    _agent = StudyBuddyAgent();
    _vlService = VLService(_config);
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

    if (_config.isGLM) {
      // 使用 GLM API - 不再处理工具调用
      await for (final text in _processWithGLM(currentHistory)) {
        yield text;
      }
    } else {
      // 使用 Ollama API - 不再处理工具调用
      await for (final text in _processWithOllama(currentHistory)) {
        yield text;
      }
    }
  }

  /// 使用 GLM API 处理对话
  Stream<String> _processWithGLM(List<Message> history) async* {
    final messages = <Map<String, dynamic>>[];
    
    for (final m in history) {
      if (m.role == MessageRole.system) {
        messages.add({'role': 'system', 'content': m.content});
      } else if (m.role == MessageRole.user) {
        messages.add({'role': 'user', 'content': m.content});
      } else if (m.role == MessageRole.assistant) {
        if (m.toolCalls != null) {
          messages.add({
            'role': 'assistant',
            'content': m.content,
            'tool_calls': m.toolCalls,
          });
        } else {
          messages.add({'role': 'assistant', 'content': m.content});
        }
      } else if (m.role == MessageRole.tool) {
        messages.add({
          'role': 'tool',
          'tool_call_id': m.toolCallId,
          'content': m.content,
        });
      }
    }

    final requestBody = {
      'model': _config.currentTextModel,
      'messages': messages,
      // 不再使用 tools，完全依赖行前缀协议
      'stream': true,
    };

    AILogger.logRequest(_config.currentTextModel, requestBody, provider: 'GLM');

    // ========== 调试日志：打印完整的 API 请求信息 ==========
    debugPrint('');
    debugPrint('========== GLM API 请求调试 ==========');
    debugPrint('API URL: ${_config.currentApiUrl}');
    debugPrint('Model: ${_config.currentTextModel}');
    debugPrint('API Key (明文前8位): ${_config.glmApiKey.substring(0, _config.glmApiKey.length > 8 ? 8 : _config.glmApiKey.length)}...');
    debugPrint('API Key 完整长度: ${_config.glmApiKey.length}');
    debugPrint('API Key 完整明文: ${_config.glmApiKey}');
    debugPrint('请求头: Content-Type: application/json');
    debugPrint('请求头: Authorization: Bearer ${_config.glmApiKey}');
    debugPrint('请求体 (JSON): ${jsonEncode(requestBody)}');
    debugPrint('========================================');
    debugPrint('');

    final httpRequest = http.Request('POST', Uri.parse(_config.currentApiUrl));
    httpRequest.headers['Content-Type'] = 'application/json';
    httpRequest.headers['Authorization'] = 'Bearer ${_config.glmApiKey}';
    httpRequest.bodyBytes = utf8.encode(jsonEncode(requestBody));
    
    final streamedResponse = await http.Client().send(httpRequest);
    String fullContent = '';
    List<Map<String, dynamic>>? pendingToolCalls;
    String? toolCallId;
    String? toolCallName;
    String toolCallArgs = '';

    await for (final line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      // 打印每一行原始数据
      print('[GLM_RAW] $line');
      
      if (line.isEmpty) continue;
      
      // GLM SSE 格式: data: {...}
      if (line.startsWith('data:')) {
        final dataStr = line.substring(5).trim();
        if (dataStr == '[DONE]') continue;
        
        try {
          final data = jsonDecode(dataStr);
          print('[GLM_DECODED] ${jsonEncode(data)}');
          
          final delta = data['choices']?[0]?['delta'];
          
          if (delta != null) {
            // 处理文本内容
            if (delta['content'] != null) {
              final content = delta['content'];
              print('[GLM_CONTENT] $content');
              fullContent += content;
              yield content;
            }
            
            // 处理工具调用
            if (delta['tool_calls'] != null) {
              final toolCalls = List.from(delta['tool_calls']);
              for (final tc in toolCalls) {
                if (tc['id'] != null) {
                  toolCallId = tc['id'];
                  pendingToolCalls ??= [];
                }
                if (tc['function']?['name'] != null) {
                  toolCallName = tc['function']['name'];
                }
                if (tc['function']?['arguments'] != null) {
                  toolCallArgs += tc['function']['arguments'];
                }
                
                // 当工具调用完成时
                if (toolCallId != null && toolCallName != null && toolCallArgs.isNotEmpty) {
                  // 检查参数是否是完整的 JSON
                  try {
                    jsonDecode(toolCallArgs);
                    pendingToolCalls!.add({
                      'id': toolCallId,
                      'type': 'function',
                      'function': {
                        'name': toolCallName,
                        'arguments': toolCallArgs,
                      },
                    });
                    toolCallId = null;
                    toolCallName = null;
                    toolCallArgs = '';
                  } catch (_) {
                    // 参数还未完整，继续累积
                  }
                }
              }
            }
          }
        } catch (e) {
          print('[GLM_PARSE_ERROR] $e, line: $dataStr');
        }
      }
    }

    AILogger.logResponse(_config.currentTextModel, fullContent);

    if (pendingToolCalls != null && pendingToolCalls!.isNotEmpty) {
      yield '__TOOL_CALLS__:${jsonEncode(pendingToolCalls)}';
    } else {
      yield '__DONE__';
    }
  }

  /// 使用 Ollama API 处理对话
  Stream<String> _processWithOllama(List<Message> history) async* {
    final messages = history.map((m) {
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
      'model': _config.currentTextModel,
      'messages': messages,
      // 不再使用 tools，完全依赖行前缀协议
      'stream': true,
      'options': {
        'num_ctx': 131072,
      },
    };

    AILogger.logRequest(_config.currentTextModel, requestBody, provider: 'Ollama');

    final httpRequest = http.Request('POST', Uri.parse(_config.currentApiUrl));
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

    AILogger.logResponse(_config.currentTextModel, fullContent);

    if (pendingToolCalls != null) {
      yield '__TOOL_CALLS__:${jsonEncode(pendingToolCalls)}';
    } else {
      yield '__DONE__';
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
      'provider': _config.isGLM ? 'GLM' : 'Ollama',
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
      await for (final chunk in _processWithStreamingParser(newHistory)) {
        yield chunk;
      }
    } else {
      // 没有图片，直接用文本模型处理
      await for (final chunk in _processWithStreamingParser(history)) {
        yield chunk;
      }
    }
  }
  
  /// 使用流式解析器处理响应
  /// 核心改进：chatContent 现在只包含 C> 的内容（已去掉前缀）
  /// blackboardContent 等只包含对应前缀的内容（已去掉前缀）
  Stream<ChatChunk> _processWithStreamingParser(List<Message> history) async* {
    String fullContent = '';
    String currentChatContent = '';      // 当前 chunk 的聊天内容（已去掉 C> 前缀）
    String currentBlackboardContent = '';
    String currentWorkbookContent = '';
    String currentNotebookContent = '';
    QuestionResponse? questionResponse;
    
    AILogger.log('STREAM_PARSER', '开始流式解析（行前缀协议）');
    
    // 创建流式解析器
    final parser = StreamingResponseParser(
      onText: (text) {
        // onText 只被 C> 行调用，text 已经去掉了 C> 前缀
        fullContent += text;
        currentChatContent += text;
      },
      onBlackboard: (content) {
        AILogger.log('LINE_PREFIX', 'B: $content');
        currentBlackboardContent += content;
      },
      onWorkbook: (content) {
        AILogger.log('LINE_PREFIX', 'W: $content');
        currentWorkbookContent += content + '\n';
      },
      onNotebook: (content) {
        AILogger.log('LINE_PREFIX', 'N: $content');
        currentNotebookContent += content + '\n';
      },
      onQuestion: (question) {
        AILogger.log('STREAM_PARSER', '✓ 收到题目响应');
        questionResponse = question;
      },
    );
    
    await for (final text in processDialogue(history)) {
      // 处理内部标记
      if (text == '__DONE__') {
        AILogger.log('STREAM_PARSER', '流式解析完成', data: {
          'has_question': questionResponse != null,
          'has_blackboard': currentBlackboardContent.isNotEmpty,
          'has_workbook': currentWorkbookContent.isNotEmpty,
          'has_notebook': currentNotebookContent.isNotEmpty,
          'content_length': fullContent.length,
        });
        
        // 输出最后的完整响应
        if (questionResponse != null) {
          yield ChatChunk(
            content: fullContent,
            questionResponse: questionResponse,
          );
        }
        yield ChatChunk(done: true);
        break;
      }
      
      if (text.startsWith('__TOOL_CALLS__:')) {
        AILogger.log('STREAM_PARSER', '检测到工具调用（已弃用，忽略）');
        // 不再处理工具调用
        continue;
      }
      
      // 将文本传递给解析器
      parser.parse(text);
      
      // 输出流式块
      // 注意：chatContent 已经去掉了 C> 前缀
      // blackboardContent 等已经去掉了对应的前缀
      if (currentChatContent.isNotEmpty || 
          currentBlackboardContent.isNotEmpty ||
          currentWorkbookContent.isNotEmpty ||
          currentNotebookContent.isNotEmpty) {
        yield ChatChunk(
          content: currentChatContent.isNotEmpty ? currentChatContent : null,
          blackboardContent: currentBlackboardContent.isNotEmpty ? currentBlackboardContent : null,
          workbookContent: currentWorkbookContent.isNotEmpty ? currentWorkbookContent : null,
          notebookContent: currentNotebookContent.isNotEmpty ? currentNotebookContent : null,
        );
        // 重置当前 chunk 的内容
        currentChatContent = '';
        currentBlackboardContent = '';
        currentWorkbookContent = '';
        currentNotebookContent = '';
      }
    }
    
    parser.finish();
  }
}

class ChatChunk {
  final String? content;
  final String? thinking;
  final List<Map<String, dynamic>>? toolCalls;
  final BlackboardCommand? blackboardCommand; // 保留兼容旧格式
  final QuestionResponse? questionResponse;
  final bool done;
  
  // 行前缀协议新增字段
  final String? blackboardContent;  // B: 黑板内容
  final String? workbookContent;    // W: 做题册内容
  final String? notebookContent;    // N: 笔记本内容
  
  ChatChunk({
    this.content,
    this.thinking,
    this.toolCalls,
    this.blackboardCommand,
    this.questionResponse,
    this.done = false,
    this.blackboardContent,
    this.workbookContent,
    this.notebookContent,
  });
  
  /// 是否包含黑板命令（旧格式）
  bool get hasBlackboardCommand => blackboardCommand != null;
  
  /// 是否包含黑板内容（新格式）
  bool get hasBlackboardContent => blackboardContent != null && blackboardContent!.isNotEmpty;
  
  /// 是否包含做题册内容
  bool get hasWorkbookContent => workbookContent != null && workbookContent!.isNotEmpty;
  
  /// 是否包含笔记本内容
  bool get hasNotebookContent => notebookContent != null && notebookContent!.isNotEmpty;
  
  /// 是否包含题目响应
  bool get hasQuestionResponse => questionResponse != null;
}
