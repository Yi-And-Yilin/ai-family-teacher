/// 行前缀流式解析器（已弃用，保留备用）
/// 
/// 这个文件包含旧的 C>/B>/N> 行前缀解析逻辑。
/// 现在系统使用 Function Calling 模式，此文件仅供参考。
/// 
/// 如果需要恢复行前缀模式，可以将此解析器重新集成到 AIService。

import 'dart:convert';

/// 渲染目标枚举
enum RenderTarget {
  chat,       // 聊天区
  blackboard, // B: 黑板
  notebook,   // N: 笔记本
}

/// 题目响应（兼容旧格式）
class QuestionResponse {
  final String question;
  final String answer;
  final List<String>? options;
  final String? explanation;

  QuestionResponse({
    required this.question,
    required this.answer,
    this.options,
    this.explanation,
  });

  factory QuestionResponse.fromJson(Map<String, dynamic> json) {
    return QuestionResponse(
      question: json['question'] as String,
      answer: json['answer'] as String,
      options: (json['options'] as List?)?.cast<String>(),
      explanation: json['explanation'] as String?,
    );
  }
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
          final text = _buffer.substring(0, idx);
          _processLinePrefixContent(text);
        }
        _buffer = _buffer.substring(idx + 3);
        
        if (_buffer.startsWith('json')) {
          _isJsonCodeBlock = true;
          _buffer = _buffer.substring(4);
        } else {
          _isJsonCodeBlock = true;
        }
        
        _inCodeBlock = true;
        _codeBlockBuffer = '';
        continue;
      }
      
      // 2. 按行处理
      final newlineIdx = _buffer.indexOf('\n');
      if (newlineIdx >= 0) {
        final line = _buffer.substring(0, newlineIdx);
        _buffer = _buffer.substring(newlineIdx + 1);
        _processLine(line);
      } else {
        if (_buffer.length > 100) {
          _processLinePrefixContent(_buffer);
          _buffer = '';
        }
        break;
      }
    }
  }
  
  void _processLine(String line) {
    if (line.startsWith('C>')) {
      _currentTarget = RenderTarget.chat;
      final content = line.substring(2);
      _routeContent(content);
    } else if (line.startsWith('B>')) {
      _currentTarget = RenderTarget.blackboard;
      final content = line.substring(2);
      _routeContent(content);
    } else if (line.startsWith('N>')) {
      _currentTarget = RenderTarget.notebook;
      final content = line.substring(2);
      _routeContent(content);
    } else {
      _routeContent(line);
    }
  }
  
  void _processLinePrefixContent(String content) {
    if (content.startsWith('C>')) {
      _currentTarget = RenderTarget.chat;
      _routeContent(content.substring(2));
    } else if (content.startsWith('B>')) {
      _currentTarget = RenderTarget.blackboard;
      _routeContent(content.substring(2));
    } else if (content.startsWith('N>')) {
      _currentTarget = RenderTarget.notebook;
      _routeContent(content.substring(2));
    } else {
      _routeContent(content);
    }
  }
  
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
  
  void _processCodeBlockContent() {
    if (_buffer.contains('```')) {
      final idx = _buffer.indexOf('```');
      _codeBlockBuffer += _buffer.substring(0, idx);
      
      if (_isJsonCodeBlock || _codeBlockBuffer.trimLeft().startsWith('{')) {
        _tryParseJson(_codeBlockBuffer.trim());
      }
      
      _buffer = _buffer.substring(idx + 3);
      _inCodeBlock = false;
      _isJsonCodeBlock = false;
      _codeBlockBuffer = '';
      return;
    }
    
    _codeBlockBuffer += _buffer;
    _buffer = '';
  }
  
  bool _tryParseJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr);
      _handleJsonResponse(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleJsonResponse(Map<String, dynamic> json) {
    if (json.containsKey('question') && json.containsKey('answer')) {
      try {
        final questionResponse = QuestionResponse.fromJson(json);
        onQuestion?.call(questionResponse);
      } catch (e) {
        // 解析失败
      }
    }
    
    if (json.containsKey('action') && json.containsKey('elements')) {
      final elements = json['elements'] as List;
      for (final element in elements) {
        if (element['type'] == 'text') {
          onBlackboard?.call(element['content'].toString());
        }
      }
    }
  }

  void finish() {
    if (_buffer.isNotEmpty) {
      _processLinePrefixContent(_buffer);
      _buffer = '';
    }
    
    if (_inCodeBlock && _codeBlockBuffer.isNotEmpty) {
      _tryParseJson(_codeBlockBuffer.trim());
      _codeBlockBuffer = '';
      _inCodeBlock = false;
    }
    
    onComplete?.call();
  }
  
  void reset() {
    _buffer = '';
    _currentTarget = RenderTarget.chat;
    _inCodeBlock = false;
    _isJsonCodeBlock = false;
    _codeBlockBuffer = '';
  }
}
