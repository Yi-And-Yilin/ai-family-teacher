import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/conversation.dart';
import '../prompts/prompts.dart';
import '../prompts/question_generator_prompt.dart';
import '../prompts/answer_explainer_prompt.dart';
import '../i18n/translations.dart';
import 'rag_service.dart';
import 'api_config.dart';
import 'agents_service.dart';
import 'workbook_tools.dart';
import 'workbook_tool_executor.dart';
import 'prompt_loader.dart';

/// --- 0. 日志工具 ---
class AILogger {
  static File? _logFile;
  static IOSink? _sink; // 使用流式写入，更安全且防并发冲突
  static bool _initialized = false;
  static const int _maxLogSize = 5 * 1024 * 1024; // 5MB 最大日志大小

  /// 初始化日志文件
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // 获取项目根目录
      Directory currentDir = Directory.current;
      final logPath = '${currentDir.path}${Platform.pathSeparator}log.txt';
      _logFile = File(logPath);

      bool shouldWriteBom = false;

      // 检查文件状态
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxLogSize) {
          // 文件太大，清空并标记需要写入 BOM
          await _logFile!.writeAsString('');
          shouldWriteBom = true;
        }
      } else {
        // 文件不存在，标记需要写入 BOM
        shouldWriteBom = true;
      }

      // 打开文件流 (IOSink)，指定 UTF-8 编码
      // mode: append 保证追加模式
      _sink = _logFile!.openWrite(mode: FileMode.append, encoding: utf8);

      // 如果需要，写入 UTF-8 BOM (解决 Windows 记事本乱码问题)
      if (shouldWriteBom) {
        _sink!.write('\uFEFF'); // BOM
        // 写入初始分隔符
        _sink!.write(
            '\n${'=' * 60}\n新会话开始: ${DateTime.now().toIso8601String()}\n${'=' * 60}\n');
      }

      _initialized = true;
    } catch (e) {
      print('[AILogger] 日志文件初始化失败: $e');
    }
  }

  /// 写入日志到文件 (使用 IOSink，线程安全)
  static void _writeToFile(String content) {
    _sink?.write(content);
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

  static void logRequest(String model, Map<String, dynamic> request,
      {String? provider}) {
    log('REQUEST', '发送请求到模型: $model (Provider: ${provider ?? "unknown"})');

    // 打印完整的 messages 列表，不截断
    if (request['messages'] != null) {
      final messages = request['messages'] as List;
      log('REQUEST_MESSAGES', '共 ${messages.length} 条消息:');
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        if (msg is Map) {
          final role = msg['role'] ?? 'unknown';
          final content = msg['content'] ?? '';
          final hasToolCalls = msg['tool_calls'] != null;
          final hasToolCallId = msg['tool_call_id'] != null;

          String msgSummary = '[$i] role=$role';
          if (content is String && content.isNotEmpty) {
            msgSummary += ', content(${content.length}字符)';
          }
          if (hasToolCalls) {
            msgSummary += ', tool_calls=${jsonEncode(msg['tool_calls'])}';
          }
          if (hasToolCallId) {
            msgSummary += ', tool_call_id=${msg['tool_call_id']}';
          }
          log('MSG', msgSummary);

          // 打印完整 content 内容
          if (content is String && content.isNotEmpty) {
            log('MSG_CONTENT', '--- Message $i content (role=$role) ---');
            // 分块打印，避免单行太长
            const chunkSize = 3000;
            for (int offset = 0; offset < content.length; offset += chunkSize) {
              final end = (offset + chunkSize < content.length)
                  ? offset + chunkSize
                  : content.length;
              log('MSG_CONTENT', content.substring(offset, end));
            }
            log('MSG_CONTENT', '--- End of Message $i ---');
          }
        }
      }
    }

    // 打印 tools 定义
    if (request['tools'] != null) {
      final tools = request['tools'] as List;
      final toolNames =
          tools.map((t) => t['function']['name'] as String).toList();
      log('REQUEST_TOOLS', '可用工具: $toolNames');
    }
  }

  static void logResponse(String model, String response) {
    log('RESPONSE', '收到模型 $model 的响应 (${response.length} 字符)');

    // 打印摘要（使用 startsWith 确保准确统计 B>/N> 前缀，不再有 C>/W>）
    final lines = response.split('\n');
    final bLines = lines.where((l) => l.trim().startsWith('B>')).length;
    final nLines = lines.where((l) => l.trim().startsWith('N>')).length;
    final noPrefixLines = lines.where((l) {
      final t = l.trim();
      return !t.startsWith('B>') && !t.startsWith('N>') && t.isNotEmpty;
    }).length;
    log('RESPONSE_SUMMARY', 'Chat>$noPrefixLines行 B>$bLines行 N>$nLines行');

    // 打印原始响应内容，换行符显示为可见的 \n
    final escaped = response.replaceAll('\n', '\\n\n').replaceAll('\r', '\\r');
    log('RESPONSE_BODY', escaped);
  }

  static Map<String, dynamic> _sanitizeRequest(Map<String, dynamic> request) {
    final sanitized = Map<String, dynamic>.from(request);
    if (sanitized['messages'] != null) {
      final messages = List.from(sanitized['messages']);
      for (var msg in messages) {
        if (msg is Map && msg['images'] != null) {
          // 截断 base64 图片数据，只显示前后 50 个字符
          final images = List.from(msg['images']);
          msg['images'] = images
              .map((img) =>
                  '${(img as String).substring(0, img.length > 50 ? 50 : img.length)}...(${img.length} chars)')
              .toList();
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

  /// 等待所有挂起的日志写入完成
  /// 用于测试结束时确保日志全部落盘
  static Future<void> flush() async {
    if (_sink != null) {
      await _sink!.flush();
      print('[AILogger] 所有日志缓冲区已刷入文件');
    }
  }
}

/// --- 1. 智能体定义 (纯行前缀协议，无工具调用) ---
class StudyBuddyAgent {
  final AgentType agentType;
  final String language; // 任意语言代码（如 'zh', 'en', 'es'）

  /// 已缓存的系统提示词（由 init() 异步加载）
  String? _cachedSystemPrompt;

  StudyBuddyAgent({
    this.agentType = AgentType.studyBuddy,
    this.language = 'zh',
  });

  /// 初始化：加载系统提示词
  Future<void> init() async {
    _cachedSystemPrompt = await _loadSystemPrompt();
  }

  /// 获取系统提示词（必须先调用 init()）
  String get systemPrompt {
    if (_cachedSystemPrompt != null) {
      return _cachedSystemPrompt!;
    }
    // 回退：如果尚未加载，尝试同步加载（可能在初始化前调用）
    switch (agentType) {
      case AgentType.studyBuddy:
        return baseSystemPrompt; // 回退到默认中文
      case AgentType.questionGenerator:
        return questionGeneratorPrompt;
      case AgentType.answerExplainer:
        return answerExplainerPrompt;
    }
  }

  Future<String> _loadSystemPrompt() async {
    switch (agentType) {
      case AgentType.studyBuddy:
        return await PromptLoader().getSystemPrompt(
          language: language,
          agentType: 'study_buddy',
        );
      case AgentType.questionGenerator:
        return questionGeneratorPrompt; // TODO: 迁移到 JSON
      case AgentType.answerExplainer:
        return answerExplainerPrompt; // TODO: 迁移到 JSON
    }
  }

  // 不再使用工具调用，完全依赖行前缀协议
  // C> 聊天区, B> 黑板, N> 笔记本（W> 已废弃，做题册通过工具调用）
}

/// --- 3. 视觉模型服务 ---
class VLService {
  final APIConfigService _config;

  VLService(this._config);

  static const String _vlSystemPrompt =
      '''你是"小书童"学习助手的图像解析模块。你的任务是解析学生上传的图片，提取其中的关键信息。

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
    } else if (_config.isDeepSeek) {
      return _analyzeWithDeepSeek(base64Image, userMessage: userMessage);
    } else {
      return _analyzeWithOllama(base64Image, userMessage: userMessage);
    }
  }

  /// 使用 GLM API 分析图片
  Future<String> _analyzeWithGLM(String base64Image,
      {String? userMessage}) async {
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
        final response = await client
            .post(
              Uri.parse(_config.currentApiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${_config.glmApiKey}',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(minutes: 5));

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
  Future<String> _analyzeWithOllama(String base64Image,
      {String? userMessage}) async {
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
        final response = await client
            .post(
              Uri.parse(_config.currentApiUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(minutes: 5));

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

  /// 使用 DeepSeek API 分析图片（OpenAI 兼容格式）
  Future<String> _analyzeWithDeepSeek(String base64Image,
      {String? userMessage}) async {
    // 注意：DeepSeek 可能不支持视觉模型，这里提供基础实现
    // 如果 DeepSeek 不支持视觉任务，可以回退到 GLM 或 Ollama
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
        final response = await client
            .post(
              Uri.parse(_config.currentApiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${_config.deepseekApiKey}',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(minutes: 5));

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
}

/// --- 4. 核心服务 (多模态支持) ---
class AIService {
  final APIConfigService _config;
  late StudyBuddyAgent _agent;
  late final VLService _vlService;
  final RAGService _ragService = RAGService();
  String _language = 'zh'; // 默认中文

  final Future<bool> Function(String title, String message)?
      onRequireConfirmation;

  AIService({
    APIConfigService? config,
    Function(String)? onBlackboardUpdate,
    Function(List<Map<String, dynamic>>)? onWorkbookMark,
    Function()? onBlackboardClear,
    this.onRequireConfirmation,
  }) : _config = config ?? APIConfigService.instance {
    _agent = StudyBuddyAgent(language: _language);
    _vlService = VLService(_config);
    // 异步初始化 agent（加载系统提示词）
    _agent.init();
  }

  /// 设置语言（由 AppProvider 调用）
  Future<void> setLanguage(String lang) async {
    _language = lang;
    // 重新创建 agent 以应用新语言
    _agent = StudyBuddyAgent(language: _language);
    await _agent.init(); // 加载新语言的提示词
  }

  /// 处理包含图片的消息（多模态流程）
  Future<String> processImageFirst(List<String> base64Images,
      {String? userMessage}) async {
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
    currentHistory.insert(
        0,
        Message(
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
    } else if (_config.isDeepSeek) {
      // 使用 DeepSeek API - OpenAI 兼容格式
      await for (final text in _processWithDeepSeek(currentHistory)) {
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
  /// 使用循环模式：持续调用 LLM → 执行工具 → 再次调用 LLM，直到 finish_reason == 'stop'
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

    int roundCount = 0;

    while (true) {
      roundCount++;
      final isFollowUp = roundCount > 1;
      final requestBody = {
        'model': _config.currentTextModel,
        'messages': List<Map<String, dynamic>>.from(messages),
        'tools': WorkbookTools.allTools,
        'stream': true,
      };

      AILogger.logRequest(_config.currentTextModel, requestBody,
          provider: isFollowUp ? 'GLM (round $roundCount)' : 'GLM');

      final httpRequest =
          http.Request('POST', Uri.parse(_config.currentApiUrl));
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.headers['Authorization'] = 'Bearer ${_config.glmApiKey}';
      httpRequest.bodyBytes = utf8.encode(jsonEncode(requestBody));

      if (isFollowUp) {
        yield '__PROGRESS__:${Translations().t('tool_fetching_response')}';
      }

      final streamedResponse = await http.Client().send(httpRequest);
      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        yield '__ERROR__:网络请求失败 (${streamedResponse.statusCode}): $errorBody';
        return;
      }
      String roundContent = '';
      String roundReasoning = '';
      List<Map<String, dynamic>>? pendingToolCalls;
      String? toolCallId;
      String? toolCallName;
      String toolCallArgs = '';
      String? finishReason;
      bool hasPrintedThinking = false;
      bool hasPrintedAnswer = false;

      AILogger.log('ROUND', '=== 第 $roundCount 轮 API 调用 (GLM) ===');

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr == '[DONE]') continue;

          try {
            final json = jsonDecode(dataStr);
            final delta = json['choices']?[0]?['delta'];
            final fr = json['choices']?[0]?['finish_reason'];
            if (fr != null) finishReason = fr;

            if (delta != null) {
              if (delta['reasoning_content'] != null) {
                final rc = delta['reasoning_content'];
                roundReasoning += rc;
                if (!hasPrintedThinking) {
                  print('\n========== AI 思考过程 ==========');
                  hasPrintedThinking = true;
                }
                stdout.write(rc);
                // 关键修复：reasoning_content 单独 yield 为 THINKING: 标记，不作为 content
                yield '__THINKING__:$rc';
              }

              if (delta['content'] != null) {
                final content = delta['content'];
                // 诊断日志：记录每块原始内容，换行符显示为可见 \n
                final escapedContent =
                    content.replaceAll('\n', '\\n').replaceAll('\r', '\\r');
                AILogger.log('LLM_CHUNK',
                    '[Round $roundCount] delta content: "$escapedContent"');
                if (!hasPrintedAnswer && !hasPrintedThinking) {
                  print('\n========== AI 回答 ==========');
                  hasPrintedAnswer = true;
                } else if (!hasPrintedAnswer && hasPrintedThinking) {
                  print('\n========== 正式回答 ==========');
                  hasPrintedAnswer = true;
                }
                roundContent += content;
                yield content;
              }

              if (delta['tool_calls'] != null) {
                final toolCalls = List.from(delta['tool_calls']);
                for (final tc in toolCalls) {
                  if (tc['id'] != null) {
                    if (toolCallId != null &&
                        toolCallName != null &&
                        toolCallArgs.isNotEmpty) {
                      try {
                        jsonDecode(toolCallArgs);
                        pendingToolCalls ??= [];
                        pendingToolCalls!.add({
                          'id': toolCallId,
                          'type': 'function',
                          'function': {
                            'name': toolCallName,
                            'arguments': toolCallArgs,
                          },
                        });
                      } catch (e) {
                        yield '__ERROR__:工具参数解析失败: $e';
                      }
                    }
                    toolCallId = tc['id'];
                    toolCallName = null;
                    toolCallArgs = '';
                    pendingToolCalls ??= [];
                  }
                  if (tc['function']?['name'] != null) {
                    toolCallName = tc['function']['name'];
                  }
                  if (tc['function']?['arguments'] != null) {
                    toolCallArgs += tc['function']['arguments'];
                  }
                }
              }

              if (fr != null &&
                  toolCallId != null &&
                  toolCallName != null &&
                  toolCallArgs.isNotEmpty) {
                try {
                  jsonDecode(toolCallArgs);
                  pendingToolCalls ??= [];
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
                } catch (e) {
                  toolCallId = null;
                  toolCallName = null;
                  toolCallArgs = '';
                  yield '__ERROR__:工具参数解析失败: $e';
                }
              }
            }
          } catch (e) {
            print('[GLM_PARSE_ERROR] $e, line: $dataStr');
          }
        }
      }

      AILogger.logResponse(
          _config.currentTextModel,
          roundReasoning.isNotEmpty
              ? 'reasoning(${roundReasoning.length}) + content(${roundContent.length})'
              : roundContent);

      if (pendingToolCalls != null && pendingToolCalls!.isNotEmpty) {
        messages.add({
          'role': 'assistant',
          'content': roundContent,
          'tool_calls': pendingToolCalls,
        });

        AILogger.log(
            'TOOL_CALL', '第 $roundCount 轮检测到 ${pendingToolCalls!.length} 个工具调用',
            data: {'tool_calls': pendingToolCalls});

        final executor = WorkbookToolExecutor();

        for (final tc in pendingToolCalls!) {
          final toolName = tc['function']['name'] as String;
          final args = jsonDecode(tc['function']['arguments'] as String)
              as Map<String, dynamic>;

          // 关键修复：在工具执行进度消息前插入换行，确保前后文字分段
          yield '\n';
          yield '__PROGRESS__:${Translations().t('tool_executing')}: $toolName...';

          AILogger.log('TOOL_EXEC', '执行工具: $toolName', data: {'args': args});
          final result = await executor.execute(toolName, args);
          AILogger.log('TOOL_EXEC', '工具执行结果: $toolName',
              data: {'result': result});

          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'],
            'content': jsonEncode(result),
          });

          // 通知 UI：工具执行完成，让 UI 做相应切换
          yield '__TOOL_RESULT__:${jsonEncode({
                'tool_name': toolName,
                'result': result,
              })}';
        }

        // 关键修复：在继续下一轮 LLM 调用前插入换行，分隔前后文字
        yield '\n';
        AILogger.log('ROUND', '工具执行完毕，进入第 ${roundCount + 1} 轮 LLM 调用');
        continue;
      }

      AILogger.log('ROUND',
          '第 $roundCount 轮结束，finish_reason: $finishReason，无更多工具调用，退出循环');
      print('\n========== 正式回答结束 ==========\n');
      break;
    }

    yield '__DONE__';
  }

  /// 使用 DeepSeek API 处理对话（OpenAI 兼容格式）
  /// 使用循环模式：持续调用 LLM → 执行工具 → 再次调用 LLM，直到 finish_reason == 'stop'
  Stream<String> _processWithDeepSeek(List<Message> history) async* {
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

    int roundCount = 0;

    while (true) {
      roundCount++;
      final isFollowUp = roundCount > 1;
      final requestBody = {
        'model': _config.currentTextModel,
        'messages': List<Map<String, dynamic>>.from(messages),
        'tools': WorkbookTools.allTools,
        'stream': true,
      };

      AILogger.logRequest(_config.currentTextModel, requestBody,
          provider: isFollowUp ? 'DeepSeek (round $roundCount)' : 'DeepSeek');

      final httpRequest =
          http.Request('POST', Uri.parse(_config.currentApiUrl));
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.headers['Authorization'] = 'Bearer ${_config.deepseekApiKey}';
      httpRequest.bodyBytes = utf8.encode(jsonEncode(requestBody));

      if (isFollowUp) {
        yield '__PROGRESS__:${Translations().t('tool_fetching_response')}';
      }

      final streamedResponse = await http.Client().send(httpRequest);
      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        yield '__ERROR__:网络请求失败 (${streamedResponse.statusCode}): $errorBody';
        return;
      }
      String roundContent = '';
      String roundReasoning = '';
      List<Map<String, dynamic>>? pendingToolCalls;
      String? toolCallId;
      String? toolCallName;
      String toolCallArgs = '';
      String? finishReason;
      bool hasPrintedThinking = false;
      bool hasPrintedAnswer = false;

      AILogger.log('ROUND', '=== 第 $roundCount 轮 API 调用 ===');

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr == '[DONE]') continue;

          try {
            final json = jsonDecode(dataStr);
            final delta = json['choices']?[0]?['delta'];
            final fr = json['choices']?[0]?['finish_reason'];
            if (fr != null) finishReason = fr;

            if (delta != null) {
              if (delta['reasoning_content'] != null) {
                final rc = delta['reasoning_content'];
                roundReasoning += rc;
                if (!hasPrintedThinking) {
                  print('\n========== AI 思考过程 ==========');
                  hasPrintedThinking = true;
                }
                stdout.write(rc);
                // 关键修复：reasoning_content 单独 yield 为 THINKING: 标记，不作为 content
                yield '__THINKING__:$rc';
              }

              if (delta['content'] != null) {
                final content = delta['content'];
                // 诊断日志：记录每块原始内容，换行符显示为可见 \n
                final escapedContent =
                    content.replaceAll('\n', '\\n').replaceAll('\r', '\\r');
                AILogger.log('LLM_CHUNK',
                    '[Round $roundCount] delta content: "$escapedContent"');
                if (!hasPrintedAnswer && !hasPrintedThinking) {
                  print('\n========== AI 回答 ==========');
                  hasPrintedAnswer = true;
                } else if (!hasPrintedAnswer && hasPrintedThinking) {
                  print('\n========== 正式回答 ==========');
                  hasPrintedAnswer = true;
                }
                roundContent += content;
                yield content;
              }

              if (delta['tool_calls'] != null) {
                final toolCalls = List.from(delta['tool_calls']);
                for (final tc in toolCalls) {
                  if (tc['id'] != null) {
                    if (toolCallId != null &&
                        toolCallName != null &&
                        toolCallArgs.isNotEmpty) {
                      try {
                        jsonDecode(toolCallArgs);
                        pendingToolCalls ??= [];
                        pendingToolCalls!.add({
                          'id': toolCallId,
                          'type': 'function',
                          'function': {
                            'name': toolCallName,
                            'arguments': toolCallArgs,
                          },
                        });
                      } catch (e) {
                        yield '__ERROR__:工具参数解析失败: $e';
                      }
                    }
                    toolCallId = tc['id'];
                    toolCallName = null;
                    toolCallArgs = '';
                    pendingToolCalls ??= [];
                  }
                  if (tc['function']?['name'] != null) {
                    toolCallName = tc['function']['name'];
                  }
                  if (tc['function']?['arguments'] != null) {
                    toolCallArgs += tc['function']['arguments'];
                  }
                }
              }

              if (fr != null &&
                  toolCallId != null &&
                  toolCallName != null &&
                  toolCallArgs.isNotEmpty) {
                try {
                  jsonDecode(toolCallArgs);
                  pendingToolCalls ??= [];
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
                } catch (e) {
                  toolCallId = null;
                  toolCallName = null;
                  toolCallArgs = '';
                  yield '__ERROR__:工具参数解析失败: $e';
                }
              }
            }
          } catch (e) {
            print('[DeepSeek_PARSE_ERROR] $e, line: $dataStr');
          }
        }
      }

      AILogger.logResponse(
          _config.currentTextModel,
          roundReasoning.isNotEmpty
              ? 'reasoning(${roundReasoning.length}) + content(${roundContent.length})'
              : roundContent);

      // 将 assistant 回复加入 messages
      if (pendingToolCalls != null && pendingToolCalls!.isNotEmpty) {
        messages.add({
          'role': 'assistant',
          'content': roundContent,
          'tool_calls': pendingToolCalls,
        });

        AILogger.log(
            'TOOL_CALL', '第 $roundCount 轮检测到 ${pendingToolCalls!.length} 个工具调用',
            data: {'tool_calls': pendingToolCalls});

        final executor = WorkbookToolExecutor();

        for (final tc in pendingToolCalls!) {
          final toolName = tc['function']['name'] as String;
          final args = jsonDecode(tc['function']['arguments'] as String)
              as Map<String, dynamic>;

          // 关键修复：在工具执行进度消息前插入换行，确保前后文字分段
          yield '\n';
          yield '__PROGRESS__:${Translations().t('tool_executing')}: $toolName...';

          AILogger.log('TOOL_EXEC', '执行工具: $toolName', data: {'args': args});
          final result = await executor.execute(toolName, args);
          AILogger.log('TOOL_EXEC', '工具执行结果: $toolName',
              data: {'result': result});

          // 将 tool result 加入 messages
          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'],
            'content': jsonEncode(result),
          });

          // 通知 UI：工具执行完成，让 UI 做相应切换
          yield '__TOOL_RESULT__:${jsonEncode({
                'tool_name': toolName,
                'result': result,
              })}';
        }

        // 关键修复：在继续下一轮 LLM 调用前插入换行，分隔前后文字
        yield '\n';
        AILogger.log('ROUND', '工具执行完毕，进入第 ${roundCount + 1} 轮 LLM 调用');
        continue;
      }

      // 没有工具调用，结束循环
      AILogger.log('ROUND',
          '第 $roundCount 轮结束，finish_reason: $finishReason，无更多工具调用，退出循环');
      print('\n========== 正式回答结束 ==========\n');
      break;
    }

    yield '__DONE__';
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

    AILogger.logRequest(_config.currentTextModel, requestBody,
        provider: 'Ollama');

    final httpRequest = http.Request('POST', Uri.parse(_config.currentApiUrl));
    httpRequest.headers['Content-Type'] = 'application/json';
    httpRequest.bodyBytes = utf8.encode(jsonEncode(requestBody));

    final streamedResponse = await http.Client().send(httpRequest);
    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      yield '__ERROR__:网络请求失败 (${streamedResponse.statusCode}): $errorBody';
      return;
    }
    String fullContent = '';
    List<Map<String, dynamic>>? pendingToolCalls;

    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) continue;
      try {
        final data = jsonDecode(line);
        if (data['message']?['content'] != null) {
          fullContent += data['message']['content'];
          yield data['message']['content'];
        }
        if (data['message']?['tool_calls'] != null) {
          pendingToolCalls =
              List<Map<String, dynamic>>.from(data['message']['tool_calls']);
        }
        if (data['done'] == true) break;
      } catch (e) {
        yield '__ERROR__:工具参数解析失败: $e';
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
      final lastIndex =
          newHistory.lastIndexWhere((m) => m.role == MessageRole.user);
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
  /// 核心：零延迟状态机，逐字符实时发出，不等待整行
  /// 维护最多 2 字符的前缀缓冲区，确认 B>/N> 后切换目标组件
  /// 无前缀 → 默认聊天区

  /// 将进度消息解析为 ToolCallEvent
  ToolCallEvent _parseProgressToToolCallEvent(String progressMsg) {
    // 格式: "__PROGRESS__:{Translations().t('tool_executing')}: create_workbook..." → 提取工具名
    print('[AI_SERVICE] 🔍 解析进度消息: $progressMsg');

    String toolName = '';
    // 匹配 ": toolName" 或 "：toolName" 模式
    final match = RegExp(r'[:：]\s*([a-zA-Z_]+)').firstMatch(progressMsg);
    if (match != null) {
      toolName = match.group(1) ?? '';
      print('[AI_SERVICE] ✓ 提取到工具名: $toolName');
    } else {
      print('[AI_SERVICE] ⚠️ 未能从进度消息中提取工具名');
    }

    final displayText = _getToolCallProgressText(toolName);
    print('[AI_SERVICE] 📝 进度显示文字: $displayText');

    return ToolCallEvent(
      toolName: toolName,
      state: ToolCallState.progress,
      progressText: displayText,
    );
  }

  /// 将工具结果解析为 ToolCallEvent (done state)
  ToolCallEvent _parseResultToToolCallEvent(
      String toolName, Map<String, dynamic> wrapperResult) {
    // 关键修复：wrapperResult 的结构是 {tool_name, result: {actual_result}}
    // 我们需要提取嵌套的 result 字段作为实际的工结果
    final actualResult =
        wrapperResult['result'] as Map<String, dynamic>? ?? wrapperResult;
    final displayText = _getToolCallDoneText(toolName, actualResult);
    return ToolCallEvent(
      toolName: toolName,
      state: ToolCallState.done,
      progressText: displayText,
      result: actualResult, // 存储实际的工具结果，而不是包装对象
    );
  }

  /// 根据工具名获取进度显示文字（使用翻译）
  String _getToolCallProgressText(String toolName) {
    final key = 'tool_${toolName}_progress';
    final translated = Translations().t(key);
    // 如果翻译返回了 key 本身（未找到），回退到默认中文
    if (translated == key) {
      switch (toolName) {
        case 'create_workbook':
          return '📝 正在创建作业簿...';
        case 'create_question':
          return '✏️ 正在添加题目...';
        case 'grade_answer':
          return '🔍 正在批改答案...';
        case 'grade_workbook':
          return '📊 正在批改作业簿...';
        case 'explain_solution':
          return '💡 正在生成讲解...';
        default:
          return '⚙️ 正在处理...';
      }
    }
    // 添加适当的图标前缀
    String icon = '⚙️';
    if (toolName.contains('create')) icon = '📝';
    if (toolName.contains('question')) icon = '✏️';
    if (toolName.contains('grade')) icon = '🔍';
    if (toolName.contains('explain')) icon = '💡';
    return '$icon $translated...';
  }

  /// 根据工具名获取完成显示文字（使用翻译）
  String _getToolCallDoneText(String toolName, Map<String, dynamic> result) {
    final key = 'tool_${toolName}_done';
    final translated = Translations().t(key);
    // 如果翻译返回了 key 本身（未找到），回退到默认中文
    if (translated == key) {
      switch (toolName) {
        case 'create_workbook':
          return result['success'] == true ? '✅ 作业簿已创建' : '❌ 作业簿创建失败';
        case 'create_question':
          return result['success'] == true ? '✅ 题目已添加' : '❌ 题目添加失败';
        case 'grade_answer':
          return '✅ 批改完成';
        case 'grade_workbook':
          return '✅ 作业簿批改完成';
        case 'explain_solution':
          return '✅ 讲解已生成';
        default:
          return result['success'] == true ? '✅ 处理完成' : '❌ 处理失败';
      }
    }
    // 添加成功/失败图标
    if (result['success'] == true) {
      return '✅ $translated';
    } else {
      return '❌ $translated';
    }
  }

  Stream<ChatChunk> _processWithStreamingParser(List<Message> history) async* {
    String fullContent = '';
    String fullThinking = '';

    // 状态机：前缀缓冲区（最多存 2 字符用于 B>/N> 确认）
    final prefixBuffer = <String>[];
    RenderTarget currentTarget = RenderTarget.chat;

    AILogger.log('STREAM_PARSER', '开始流式解析（零延迟状态机 - 无前缀=默认chat）');

    await for (final text in processDialogue(history)) {
      // 处理内部标记
      if (text == '__DONE__') {
        // 刷新前缀缓冲区中剩余的字符
        for (final ch in prefixBuffer) {
          fullContent += ch;
          yield ChatChunk(
              backendTimestamp: DateTime.now(),
              content: ch,
              roundCharCount: fullContent.length,
              thinking: fullThinking.isNotEmpty ? fullThinking : null);
        }
        prefixBuffer.clear();

        AILogger.log('STREAM_PARSER', '流式解析完成', data: {
          'content_length': fullContent.length,
          'thinking_length': fullThinking.length,
        });

        yield ChatChunk(
            backendTimestamp: DateTime.now(),
            done: true,
            thinking: fullThinking.isNotEmpty ? fullThinking : null);
        break;
      }

      if (text.startsWith('__TOOL_CALLS__:')) {
        AILogger.log('STREAM_PARSER', '检测到工具调用（已弃用，忽略）');
        continue;
      }

      // 处理 thinking 内容（来自 GLM/DeepSeek 的 reasoning_content）
      if (text.startsWith('__THINKING__:')) {
        final thinkingText = text.substring('__THINKING__:'.length);
        fullThinking += thinkingText;
        continue;
      }

      // 处理进度事件
      if (text.startsWith('__PROGRESS__:')) {
        final progressMsg = text.substring('__PROGRESS__:'.length);
        print('[STREAM_PARSER] 📡 收到PROGRESS标记: $progressMsg');
        AILogger.log('PROGRESS', progressMsg);
        // 解析工具名和状态，生成 ToolCallEvent
        final toolCallEvent = _parseProgressToToolCallEvent(progressMsg);
        print('[STREAM_PARSER]  发出包含toolCallEvent的ChatChunk (progress)');
        yield ChatChunk(
          backendTimestamp: DateTime.now(),
          progressMessage: progressMsg,
          thinking: fullThinking.isNotEmpty ? fullThinking : null,
          toolCallEvent: toolCallEvent,
        );
        continue;
      }

      // 处理工具结果
      if (text.startsWith('__TOOL_RESULT__:')) {
        final resultJson = text.substring('__TOOL_RESULT__:'.length);
        final result = jsonDecode(resultJson) as Map<String, dynamic>;
        print('[STREAM_PARSER] 📡 收到TOOL_RESULT标记');
        AILogger.log('TOOL_RESULT', '工具执行结果', data: result);
        // 生成 ToolCallEvent (done state)
        final toolName = result['tool_name'] as String? ?? '';
        print('[STREAM_PARSER] 🔧 工具名: $toolName');
        final doneEvent = _parseResultToToolCallEvent(toolName, result);
        print('[STREAM_PARSER] 📤 发出包含toolCallEvent的ChatChunk (done)');
        yield ChatChunk(
          backendTimestamp: DateTime.now(),
          toolResult: result,
          thinking: fullThinking.isNotEmpty ? fullThinking : null,
          toolCallEvent: doneEvent,
        );
        continue;
      }

      // 零延迟状态机：逐字符处理
      for (int i = 0; i < text.length; i++) {
        final ch = text[i];

        // 换行符：重置状态，发出换行
        if (ch == '\n') {
          currentTarget = RenderTarget.chat;
          prefixBuffer.clear();
          fullContent += '\n';
          yield ChatChunk(
              backendTimestamp: DateTime.now(),
              content: '\n',
              roundCharCount: fullContent.length,
              thinking: fullThinking.isNotEmpty ? fullThinking : null);
          continue;
        }

        // 如果前缀缓冲区有待决字符
        if (prefixBuffer.isNotEmpty) {
          if (prefixBuffer.length == 1) {
            // 缓冲区有 1 个字符（可能是 B/N/W），等待第 2 个字符确认
            prefixBuffer.add(ch);

            if (ch == '>') {
              // 确认是前缀！切换目标组件，前缀本身不发出
              final prefixChar = prefixBuffer[0];
              switch (prefixChar) {
                case 'B':
                  currentTarget = RenderTarget.blackboard;
                  break;
                case 'N':
                  currentTarget = RenderTarget.notebook;
                  break;
                default:
                  // 非 B/N 开头的 > 不当前缀处理，当作聊天
                  currentTarget = RenderTarget.chat;
                  for (final c in prefixBuffer) {
                    fullContent += c;
                    yield ChatChunk(
                        backendTimestamp: DateTime.now(),
                        content: c,
                        roundCharCount: fullContent.length,
                        thinking:
                            fullThinking.isNotEmpty ? fullThinking : null);
                  }
              }
              prefixBuffer.clear();
            } else {
              // 第 2 个字符不是 >，说明不是前缀
              // 把缓冲区的字符当作聊天内容发出
              for (final c in prefixBuffer) {
                fullContent += c;
                yield ChatChunk(
                    backendTimestamp: DateTime.now(),
                    content: c,
                    roundCharCount: fullContent.length,
                    thinking: fullThinking.isNotEmpty ? fullThinking : null);
              }
              prefixBuffer.clear();
              // 当前字符 ch 重新进入状态机判断
              i--;
            }
          } else {
            // 缓冲区已满，直接发出
            for (final c in prefixBuffer) {
              fullContent += c;
              yield ChatChunk(
                  backendTimestamp: DateTime.now(),
                  content: c,
                  roundCharCount: fullContent.length,
                  thinking: fullThinking.isNotEmpty ? fullThinking : null);
            }
            prefixBuffer.clear();
            i--;
          }
          continue;
        }

        // 前缀缓冲区为空，判断当前字符
        if (ch == 'B' || ch == 'N') {
          // 可能是前缀，存入缓冲区等待下一个字符确认
          prefixBuffer.add(ch);
        } else {
          // 不是前缀字符，直接发出到当前目标
          fullContent += ch;
          switch (currentTarget) {
            case RenderTarget.chat:
              yield ChatChunk(
                  backendTimestamp: DateTime.now(),
                  content: ch,
                  roundCharCount: fullContent.length,
                  thinking: fullThinking.isNotEmpty ? fullThinking : null);
              break;
            case RenderTarget.blackboard:
              yield ChatChunk(
                  backendTimestamp: DateTime.now(),
                  blackboardContent: ch,
                  roundCharCount: fullContent.length);
              break;
            case RenderTarget.notebook:
              yield ChatChunk(
                  backendTimestamp: DateTime.now(),
                  notebookContent: ch,
                  roundCharCount: fullContent.length);
              break;
          }
        }
      }
    }
  }
}

/// 渲染目标枚举（与 agents_service.dart 保持一致）
enum RenderTarget {
  chat,
  blackboard,
  notebook,
}

class ChatChunk {
  final String? content;
  final String? thinking;
  final List<Map<String, dynamic>>? toolCalls;
  final BlackboardCommand? blackboardCommand; // 保留兼容旧格式
  final QuestionResponse? questionResponse;
  final bool done;

  // 行前缀协议新增字段
  final String? blackboardContent; // B> 黑板内容
  final String? notebookContent; // N> 笔记本内容

  // 工具结果
  final Map<String, dynamic>? toolResult;

  // 进度消息（工具执行状态、LLM状态等）
  final String? progressMessage;

  // 当前轮次已接收的字符数（用于实时进度显示）
  final int? roundCharCount;

  // 工具调用事件（用于在聊天中显示可折叠指标）
  final ToolCallEvent? toolCallEvent;

  // 时间戳：后端yield这个chunk的时间（用于延迟分析）
  final DateTime? backendTimestamp;

  ChatChunk({
    this.content,
    this.thinking,
    this.toolCalls,
    this.blackboardCommand,
    this.questionResponse,
    this.done = false,
    this.blackboardContent,
    this.notebookContent,
    this.toolResult,
    this.progressMessage,
    this.roundCharCount,
    this.toolCallEvent,
    this.backendTimestamp,
  });

  /// 是否包含黑板命令（旧格式）
  bool get hasBlackboardCommand => blackboardCommand != null;

  /// 是否包含黑板内容（新格式）
  bool get hasBlackboardContent =>
      blackboardContent != null && blackboardContent!.isNotEmpty;

  /// 是否包含笔记本内容
  bool get hasNotebookContent =>
      notebookContent != null && notebookContent!.isNotEmpty;

  /// 是否包含题目响应
  bool get hasQuestionResponse => questionResponse != null;

  /// 是否包含工具结果
  bool get hasToolResult => toolResult != null;

  /// 是否包含进度消息
  bool get hasProgressMessage => progressMessage != null;

  /// 是否包含工具调用事件
  bool get hasToolCallEvent => toolCallEvent != null;
}

/// 工具调用事件 — 用于在聊天中显示可折叠指标
class ToolCallEvent {
  final String toolName;
  final ToolCallState state; // 'progress' or 'done'
  final String progressText; // 显示给用户的友好文字
  final Map<String, dynamic>? arguments; // 工具调用参数
  final Map<String, dynamic>? result; // 工具执行结果

  ToolCallEvent({
    required this.toolName,
    required this.state,
    required this.progressText,
    this.arguments,
    this.result,
  });
}

enum ToolCallState { progress, done }
