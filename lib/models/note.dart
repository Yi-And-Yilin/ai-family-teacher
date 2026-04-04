class Note {
  final String id;
  final String userId;
  final String title;
  final String content; // 文本内容
  final List<String> tags; // 标签
  final NoteType type; // 笔记类型
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived; // 是否归档
  
  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'tags': tags.join(','),
      'type': type.toString(),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_archived': isArchived ? 1 : 0,
    };
  }
  
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      content: map['content'],
      tags: map['tags'].split(',').where((t) => t.isNotEmpty).toList(),
      type: _parseNoteType(map['type']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      isArchived: map['is_archived'] == 1,
    );
  }
}

class HandwritingStroke {
  final String id;
  final String noteId;
  final List<StrokePoint> points; // 笔画点
  final ColorInfo color;
  final double width;
  final DateTime createdAt;
  
  HandwritingStroke({
    required this.id,
    required this.noteId,
    required this.points,
    required this.color,
    required this.width,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'note_id': noteId,
      'points': _pointsToString(points),
      'color_r': color.r,
      'color_g': color.g,
      'color_b': color.b,
      'color_a': color.a,
      'width': width,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  factory HandwritingStroke.fromMap(Map<String, dynamic> map) {
    return HandwritingStroke(
      id: map['id'],
      noteId: map['note_id'],
      points: _stringToPoints(map['points']),
      color: ColorInfo(
        r: map['color_r'],
        g: map['color_g'],
        b: map['color_b'],
        a: map['color_a'],
      ),
      width: map['width'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
  
  static String _pointsToString(List<StrokePoint> points) {
    return points.map((p) => '${p.x},${p.y},${p.pressure}').join(';');
  }
  
  static List<StrokePoint> _stringToPoints(String str) {
    if (str.isEmpty) return [];
    return str.split(';').map((pointStr) {
      final parts = pointStr.split(',');
      return StrokePoint(
        x: double.parse(parts[0]),
        y: double.parse(parts[1]),
        pressure: double.parse(parts[2]),
      );
    }).toList();
  }
}

class StrokePoint {
  final double x;
  final double y;
  final double pressure; // 压力值，0-1
  
  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });
}

class ColorInfo {
  final int r;
  final int g;
  final int b;
  final double a; // 透明度，0-1
  
  const ColorInfo({
    required this.r,
    required this.g,
    required this.b,
    this.a = 1.0,
  });
}

class AISummary {
  final String noteId;
  final List<String> keywords; // 关键词
  final String summary; // 摘要
  final List<String> relatedQuestions; // 相关题目ID
  final List<String> suggestedTags; // 建议标签
  final DateTime summarizedAt;
  
  AISummary({
    required this.noteId,
    required this.keywords,
    required this.summary,
    this.relatedQuestions = const [],
    this.suggestedTags = const [],
    required this.summarizedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'note_id': noteId,
      'keywords': keywords.join(','),
      'summary': summary,
      'related_questions': relatedQuestions.join(','),
      'suggested_tags': suggestedTags.join(','),
      'summarized_at': summarizedAt.millisecondsSinceEpoch,
    };
  }
  
  factory AISummary.fromMap(Map<String, dynamic> map) {
    return AISummary(
      noteId: map['note_id'],
      keywords: map['keywords'].split(',').where((k) => k.isNotEmpty).toList(),
      summary: map['summary'],
      relatedQuestions: map['related_questions'].split(',').where((q) => q.isNotEmpty).toList(),
      suggestedTags: map['suggested_tags'].split(',').where((t) => t.isNotEmpty).toList(),
      summarizedAt: DateTime.fromMillisecondsSinceEpoch(map['summarized_at']),
    );
  }
}

enum NoteType {
  math,      // 数学笔记
  chinese,   // 语文笔记
  english,   // 英语笔记
  science,   // 科学笔记
  general,   // 通用笔记
}

NoteType _parseNoteType(String typeString) {
  switch (typeString) {
    case 'NoteType.math':
      return NoteType.math;
    case 'NoteType.chinese':
      return NoteType.chinese;
    case 'NoteType.english':
      return NoteType.english;
    case 'NoteType.science':
      return NoteType.science;
    case 'NoteType.general':
      return NoteType.general;
    default:
      return NoteType.general;
  }
}