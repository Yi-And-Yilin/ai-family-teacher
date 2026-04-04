class MistakeRecord {
  final String id;
  final String userId;
  final String questionId;
  final String mistakeType; // 错误类型
  final String analysis; // 错误分析
  final int mistakeCount; // 错误次数
  final DateTime firstMistakeAt;
  final DateTime lastMistakeAt;
  final double masteryLevel; // 掌握度，0-1
  final DateTime? reviewDate; // 下次复习时间
  final bool isMastered; // 是否已掌握
  
  MistakeRecord({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.mistakeType,
    required this.analysis,
    required this.mistakeCount,
    required this.firstMistakeAt,
    required this.lastMistakeAt,
    this.masteryLevel = 0.0,
    this.reviewDate,
    this.isMastered = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'mistake_type': mistakeType,
      'analysis': analysis,
      'mistake_count': mistakeCount,
      'first_mistake_at': firstMistakeAt.millisecondsSinceEpoch,
      'last_mistake_at': lastMistakeAt.millisecondsSinceEpoch,
      'mastery_level': masteryLevel,
      'review_date': reviewDate?.millisecondsSinceEpoch,
      'is_mastered': isMastered ? 1 : 0,
    };
  }
  
  factory MistakeRecord.fromMap(Map<String, dynamic> map) {
    return MistakeRecord(
      id: map['id'],
      userId: map['user_id'],
      questionId: map['question_id'],
      mistakeType: map['mistake_type'],
      analysis: map['analysis'],
      mistakeCount: map['mistake_count'],
      firstMistakeAt: DateTime.fromMillisecondsSinceEpoch(map['first_mistake_at']),
      lastMistakeAt: DateTime.fromMillisecondsSinceEpoch(map['last_mistake_at']),
      masteryLevel: map['mastery_level'],
      reviewDate: map['review_date'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(map['review_date'])
        : null,
      isMastered: map['is_mastered'] == 1,
    );
  }
}

class KnowledgePoint {
  final String id;
  final String name; // 知识点名称
  final String subject; // 科目
  final String description; // 描述
  final List<String> relatedPoints; // 相关知识点
  final double difficulty; // 难度
  
  KnowledgePoint({
    required this.id,
    required this.name,
    required this.subject,
    required this.description,
    this.relatedPoints = const [],
    this.difficulty = 0.5,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'description': description,
      'related_points': relatedPoints.join(','),
      'difficulty': difficulty,
    };
  }
  
  factory KnowledgePoint.fromMap(Map<String, dynamic> map) {
    return KnowledgePoint(
      id: map['id'],
      name: map['name'],
      subject: map['subject'],
      description: map['description'],
      relatedPoints: map['related_points'].split(',').where((p) => p.isNotEmpty).toList(),
      difficulty: map['difficulty'],
    );
  }
}

class UserKnowledgeProgress {
  final String userId;
  final String knowledgePointId;
  final int totalQuestions; // 总题数
  final int correctAnswers; // 正确数
  final int mistakeCount; // 错误次数
  final double masteryLevel; // 掌握度
  final DateTime lastPracticedAt;
  final DateTime? nextReviewAt; // 下次复习时间
  
  UserKnowledgeProgress({
    required this.userId,
    required this.knowledgePointId,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.mistakeCount = 0,
    this.masteryLevel = 0.0,
    required this.lastPracticedAt,
    this.nextReviewAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'knowledge_point_id': knowledgePointId,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'mistake_count': mistakeCount,
      'mastery_level': masteryLevel,
      'last_practiced_at': lastPracticedAt.millisecondsSinceEpoch,
      'next_review_at': nextReviewAt?.millisecondsSinceEpoch,
    };
  }
  
  factory UserKnowledgeProgress.fromMap(Map<String, dynamic> map) {
    return UserKnowledgeProgress(
      userId: map['user_id'],
      knowledgePointId: map['knowledge_point_id'],
      totalQuestions: map['total_questions'],
      correctAnswers: map['correct_answers'],
      mistakeCount: map['mistake_count'],
      masteryLevel: map['mastery_level'],
      lastPracticedAt: DateTime.fromMillisecondsSinceEpoch(map['last_practiced_at']),
      nextReviewAt: map['next_review_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['next_review_at'])
        : null,
    );
  }
}