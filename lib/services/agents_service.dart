import 'dart:convert';
import 'dart:async';
import '../prompts/prompts.dart';

/// 智能体类型
enum AgentType {
  studyBuddy,      // 通用学习伙伴
  questionGenerator, // 出题智能体
  answerExplainer,  // 讲解智能体
}

/// 智能体配置
class AgentConfig {
  final AgentType type;
  final String systemPrompt;
  final List<String> tools;
  final bool requiresThinking;
  final bool requiresJsonResponse;

  const AgentConfig({
    required this.type,
    required this.systemPrompt,
    this.tools = const [],
    this.requiresThinking = false,
    this.requiresJsonResponse = false,
  });
}

/// 智能体工厂
class AgentFactory {
  static AgentConfig getConfig(AgentType type) {
    switch (type) {
      case AgentType.studyBuddy:
        return AgentConfig(
          type: type,
          systemPrompt: baseSystemPrompt,
          tools: ['calculator', 'update_blackboard', 'clear_blackboard'],
        );
      
      case AgentType.questionGenerator:
        return AgentConfig(
          type: type,
          systemPrompt: questionGeneratorPrompt,
          tools: ['show_question_ui'],
          requiresThinking: true,
          requiresJsonResponse: true,
        );
      
      case AgentType.answerExplainer:
        return AgentConfig(
          type: type,
          systemPrompt: answerExplainerPrompt,
          tools: ['update_blackboard', 'clear_blackboard', 'show_answer_input'],
          requiresThinking: false,
          requiresJsonResponse: false,
        );
    }
  }
}

/// 渲染目标枚举
enum RenderTarget {
  chat,       // C: 聊天区
  blackboard, // B: 黑板
  notebook,   // N: 笔记本
}

/// 流式响应解析器
/// 采用行前缀方式实现多组件流式输出路由
class StreamingResponseParser {
  final void Function(String text)? onText;
  final void Function(String content)? onBlackboard;
  final void Function(String content)? onNotebook;
  final void Function(QuestionResponse? question)? onQuestion;
  final void Function(String? thinking)? onThinking;
  final void Function()? onComplete;

  StreamingResponseParser({
    this.onText,
    this.onBlackboard,
    this.onNotebook,
    this.onQuestion,
    this.onThinking,
    this.onComplete,
  });

  String _buffer = '';
  RenderTarget _currentTarget = RenderTarget.chat;
  
  // JSON 解析相关
  bool _inCodeBlock = false;
  bool _isJsonCodeBlock = false;
  String _codeBlockBuffer = '';
  
  /// 解析流式文本
  void parse(String chunk) {
    _buffer += chunk;
    _processBuffer();
  }

  void _processBuffer() {
    while (_buffer.isNotEmpty) {
      // 1. 处理代码块（用于JSON题目）
      if (_inCodeBlock) {
        _processCodeBlockContent();
        continue;
      }

      // 检测代码块开始
      if (_buffer.contains('```')) {
        final idx = _buffer.indexOf('```');
        if (idx > 0) {
          // 先处理代码块前的内容
          final text = _buffer.substring(0, idx);
          _processLinePrefixContent(text);
        }
        _buffer = _buffer.substring(idx + 3);

        // 检查是否是JSON代码块
        if (_buffer.startsWith('json')) {
          _isJsonCodeBlock = true;
          _buffer = _buffer.substring(4);
        } else {
          _isJsonCodeBlock = true; // 默认当作JSON处理
        }

        _inCodeBlock = true;
        _codeBlockBuffer = '';
        continue;
      }

      // 2. 按行处理（行前缀检测）
      final newlineIdx = _buffer.indexOf('\n');
      if (newlineIdx >= 0) {
        // 提取一行
        final line = _buffer.substring(0, newlineIdx);
        _buffer = _buffer.substring(newlineIdx + 1);

        // 处理这一行
        _processLine(line);
      } else {
        // 没有换行符，立即处理缓冲区内容（不要等待！）
        if (_buffer.length > 10) {
          _processLinePrefixContent(_buffer);
          _buffer = '';
        }
        break;
      }
    }
  }
  
  /// 处理单行内容
  void _processLine(String line) {
    // 检测行首前缀（B>/N>，不再有 C>/W>）
    if (line.startsWith('B>')) {
      _currentTarget = RenderTarget.blackboard;
      final content = line.substring(2);
      _routeContent(content);
    } else if (line.startsWith('N>')) {
      _currentTarget = RenderTarget.notebook;
      final content = line.substring(2);
      _routeContent(content);
    } else {
      // 无前缀，默认聊天
      _currentTarget = RenderTarget.chat;
      _routeContent(line);
    }
  }
  
  /// 处理可能包含行前缀的内容（流式输出场景）
  void _processLinePrefixContent(String content) {
    // 检查内容开头是否有行前缀（B>/N>）
    if (content.startsWith('B>')) {
      _currentTarget = RenderTarget.blackboard;
      _routeContent(content.substring(2));
    } else if (content.startsWith('N>')) {
      _currentTarget = RenderTarget.notebook;
      _routeContent(content.substring(2));
    } else {
      // 无前缀，默认聊天
      _currentTarget = RenderTarget.chat;
      _routeContent(content);
    }
  }
  
  /// 路由内容到对应组件
  void _routeContent(String content) {
    if (content.isEmpty) return;

    switch (_currentTarget) {
      case RenderTarget.chat:
        onText?.call(content);
        break;
      case RenderTarget.blackboard:
        onBlackboard?.call(content);
        break;
      case RenderTarget.notebook:
        onNotebook?.call(content);
        break;
    }
  }
  
  /// 处理代码块内容
  void _processCodeBlockContent() {
    // 检测代码块结束
    if (_buffer.contains('```')) {
      final idx = _buffer.indexOf('```');
      _codeBlockBuffer += _buffer.substring(0, idx);
      
      print('[LINE_PREFIX_PARSER] 检测到代码块结束，内容长度: ${_codeBlockBuffer.length}');
      
      // 尝试解析JSON
      if (_isJsonCodeBlock || _codeBlockBuffer.trimLeft().startsWith('{')) {
        _tryParseJson(_codeBlockBuffer.trim());
      }
      
      _buffer = _buffer.substring(idx + 3);
      _inCodeBlock = false;
      _isJsonCodeBlock = false;
      _codeBlockBuffer = '';
      return;
    }
    
    // 累积代码块内容
    _codeBlockBuffer += _buffer;
    _buffer = '';
  }
  
  /// 尝试解析JSON
  bool _tryParseJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr);
      print('[LINE_PREFIX_PARSER] JSON解析成功，keys: ${json is Map ? json.keys.toList() : 'not a map'}');
      _handleJsonResponse(json);
      return true;
    } catch (e) {
      print('[LINE_PREFIX_PARSER] JSON解析失败: $e');
      return false;
    }
  }

  void _handleJsonResponse(Map<String, dynamic> json) {
    print('[LINE_PREFIX_PARSER] 检测到JSON响应');
    print('[LINE_PREFIX_PARSER] JSON keys: ${json.keys.toList()}');
    
    // 检查是否是题目响应
    if (json.containsKey('question') && json.containsKey('answer')) {
      print('[LINE_PREFIX_PARSER] ✓ 检测到题目响应格式');
      try {
        final questionResponse = QuestionResponse.fromJson(json);
        print('[LINE_PREFIX_PARSER] ✓ 题目解析成功');
        onQuestion?.call(questionResponse);
      } catch (e) {
        print('[LINE_PREFIX_PARSER] ✗ 题目解析失败: $e');
      }
    }
    
    // 检查是否是黑板命令（兼容旧格式）
    if (json.containsKey('action') && json.containsKey('elements')) {
      print('[LINE_PREFIX_PARSER] ✓ 检测到黑板命令');
      // 将黑板命令转换为文本内容输出
      final elements = json['elements'] as List;
      for (final element in elements) {
        if (element['type'] == 'text') {
          onBlackboard?.call(element['content'].toString());
        }
      }
    }
  }

  /// 完成解析
  void finish() {
    // 处理剩余buffer
    if (_buffer.isNotEmpty) {
      _processLinePrefixContent(_buffer);
      _buffer = '';
    }
    
    // 处理未完成的代码块
    if (_inCodeBlock && _codeBlockBuffer.isNotEmpty) {
      _tryParseJson(_codeBlockBuffer.trim());
      _codeBlockBuffer = '';
    }
    
    onComplete?.call();
  }

  /// 重置解析器
  void reset() {
    _buffer = '';
    _currentTarget = RenderTarget.chat;
    _inCodeBlock = false;
    _isJsonCodeBlock = false;
    _codeBlockBuffer = '';
  }
}

/// 流式响应块
class StreamChunk {
  final String? text;
  final QuestionResponse? question;
  final String? thinking;
  final bool done;

  StreamChunk({
    this.text,
    this.question,
    this.thinking,
    this.done = false,
  });
}

/// 解析流式响应的高级接口
Stream<StreamChunk> parseStreamResponse(Stream<String> rawStream) async* {
  final completer = Completer<void>();
  final chunks = <StreamChunk>[];
  
  final parser = StreamingResponseParser(
    onText: (text) {
      chunks.add(StreamChunk(text: text));
    },
    onBlackboard: (content) {
      chunks.add(StreamChunk(text: '[黑板] $content'));
    },
    onNotebook: (content) {
      chunks.add(StreamChunk(text: '[笔记本] $content'));
    },
    onQuestion: (question) {
      chunks.add(StreamChunk(question: question));
    },
    onThinking: (thinking) {
      chunks.add(StreamChunk(thinking: thinking));
    },
    onComplete: () {
      completer.complete();
    },
  );

  // 并行处理流
  rawStream.listen(
    (chunk) => parser.parse(chunk),
    onDone: () {
      parser.finish();
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    },
  );

  // 等待解析完成
  await completer.future;
  
  // 输出所有块
  for (final chunk in chunks) {
    yield chunk;
  }
  yield StreamChunk(done: true);
}
