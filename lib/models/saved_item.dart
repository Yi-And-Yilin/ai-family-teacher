/// 已保存的内容项（黑板、作业本、笔记本）
class SavedItem {
  final String id;
  final String title;
  final String type; // 'blackboard', 'workbook', 'notebook'
  final String conversationId; // 关联的对话ID
  final DateTime createdAt;
  final String? thumbnail; // 缩略图或预览文本
  final String? description;

  SavedItem({
    required this.id,
    required this.title,
    required this.type,
    required this.conversationId,
    required this.createdAt,
    this.thumbnail,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'conversation_id': conversationId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'thumbnail': thumbnail,
      'description': description,
    };
  }

  factory SavedItem.fromMap(Map<String, dynamic> map) {
    return SavedItem(
      id: map['id'],
      title: map['title'],
      type: map['type'],
      conversationId: map['conversation_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      thumbnail: map['thumbnail'],
      description: map['description'],
    );
  }

  /// 获取类型图标
  String get icon {
    switch (type) {
      case 'blackboard':
        return '📋';
      case 'workbook':
        return '📝';
      case 'notebook':
        return '📖';
      default:
        return '📄';
    }
  }

  /// 获取类型显示名称
  String get typeName {
    switch (type) {
      case 'blackboard':
        return '黑板';
      case 'workbook':
        return '作业本';
      case 'notebook':
        return '笔记本';
      default:
        return '未知';
    }
  }
}
