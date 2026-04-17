import 'dart:convert';

class Conversation {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

enum MessageRole {
  system,
  user,
  assistant,
  tool,
}

class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final String? thinking; // 模型思考过程
  final List<Map<String, dynamic>>? toolCalls; // AI 请求调用的工具
  final String? toolCallId; // 对应 tool 角色的 ID
  final List<String>? images; // 多模态: base64 图片列表
  final List<Map<String, dynamic>>? toolCallEvents; // UI 显示的工具调用指标
  final DateTime timestamp;

  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.thinking,
    this.toolCalls,
    this.toolCallId,
    this.images,
    this.toolCallEvents,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role.name,
      'content': content,
      'thinking': thinking,
      'tool_calls': toolCalls != null ? jsonEncode(toolCalls) : null,
      'tool_call_id': toolCallId,
      'images': images != null ? jsonEncode(images) : null,
      'tool_call_events': toolCallEvents != null ? jsonEncode(toolCallEvents) : null,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      conversationId: map['conversation_id'],
      role: MessageRole.values.byName(map['role'] ?? 'user'),
      content: map['content'],
      thinking: map['thinking'],
      toolCalls: map['tool_calls'] != null ? List<Map<String, dynamic>>.from(jsonDecode(map['tool_calls'])) : null,
      toolCallId: map['tool_call_id'],
      images: map['images'] != null ? List<String>.from(jsonDecode(map['images'])) : null,
      toolCallEvents: map['tool_call_events'] != null ? List<Map<String, dynamic>>.from(jsonDecode(map['tool_call_events'])) : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

MessageRole _parseRole(String roleString) {
  // 保持向后兼容
  if (roleString.startsWith('MessageRole.')) {
    final name = roleString.split('.').last;
    return MessageRole.values.firstWhere((e) => e.name == name, orElse: () => MessageRole.user);
  }
  return MessageRole.values.firstWhere((e) => e.name == roleString, orElse: () => MessageRole.user);
}