import 'package:uuid/uuid.dart';

/// 教纲模型
class Syllabus {
  final String id;
  final String title;
  final String content;
  final bool isSystem; // true=系统预设, false=用户上传

  Syllabus({
    required this.id,
    required this.title,
    required this.content,
    this.isSystem = false,
  });
}

class RAGService {
  final List<Syllabus> _syllabi = [];
  final Uuid _uuid = const Uuid();

  RAGService() {
    _initSystemSyllabus();
  }

  void _initSystemSyllabus() {
    // 预设一年级数学教纲
    addSyllabus(
      title: '小学一年级数学教纲 (人教版)',
      content: '''
1. 数与代数
   - 认识 20 以内的数：会数、会读、会写 0-20 各数。
   - 20 以内的加减法：掌握凑十法，熟练口算。
   - 认识钟表：会看整时和半时。

2. 图形与几何
   - 认识图形：长方体、正方体、圆柱、球。
   - 位置：上下、前后、左右。

3. 综合与实践
   - 数学乐园：通过游戏感受数学的乐趣。
      ''',
      isSystem: true,
    );
  }

  void addSyllabus({required String title, required String content, bool isSystem = false}) {
    _syllabi.add(Syllabus(
      id: _uuid.v4(),
      title: title,
      content: content,
      isSystem: isSystem,
    ));
  }

  List<Syllabus> get allSyllabi => List.unmodifiable(_syllabi);

  /// 核心检索逻辑 (简化版: 关键词匹配)
  /// 根据用户问题，返回最相关的教纲片段
  String retrieveContext(String query) {
    if (_syllabi.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('【参考教纲信息】:');
    
    // 简单策略：如果 query 包含教纲中的关键词，就引入该教纲
    // 实际项目中应使用向量数据库 (Vector DB) 或 TF-IDF
    bool found = false;
    
    for (var syllabus in _syllabi) {
      // 这里的匹配逻辑非常简单，仅作演示
      if (syllabus.content.contains(query) || 
          query.contains('教纲') || 
          query.contains('数学') ||
          query.contains('一年级')) {
        buffer.writeln('--- ${syllabus.title} ---');
        buffer.writeln(syllabus.content);
        found = true;
      }
    }

    if (!found) return '';
    return buffer.toString();
  }
}
