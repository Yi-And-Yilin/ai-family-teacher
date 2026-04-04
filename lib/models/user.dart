class User {
  final String id;
  final String name;
  final int grade; // 年级，如5表示五年级
  final String curriculum; // 教材版本，如"人教版"
  final DateTime createdAt;
  
  User({
    required this.id,
    required this.name,
    required this.grade,
    required this.curriculum,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'curriculum': curriculum,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      grade: map['grade'],
      curriculum: map['curriculum'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

class UserStats {
  final String userId;
  final DateTime date;
  int questionsAsked; // 今日提问次数
  int exercisesDone; // 今日练习次数
  double accuracyRate; // 正确率
  int totalLearningTime; // 总学习时长（分钟）
  
  UserStats({
    required this.userId,
    required this.date,
    this.questionsAsked = 0,
    this.exercisesDone = 0,
    this.accuracyRate = 0.0,
    this.totalLearningTime = 0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'date': date.millisecondsSinceEpoch,
      'questions_asked': questionsAsked,
      'exercises_done': exercisesDone,
      'accuracy_rate': accuracyRate,
      'total_learning_time': totalLearningTime,
    };
  }
  
  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      userId: map['user_id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      questionsAsked: map['questions_asked'],
      exercisesDone: map['exercises_done'],
      accuracyRate: map['accuracy_rate'],
      totalLearningTime: map['total_learning_time'],
    );
  }
}