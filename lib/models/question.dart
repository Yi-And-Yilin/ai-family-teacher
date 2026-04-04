class Question {
  final String id;
  final String content; // 题目内容
  final QuestionType type;
  final String subject; // 科目，如"数学"
  final List<String> tags; // 标签，如["分数除法", "应用题"]
  final double difficulty; // 难度，0-1
  final List<String> answerOptions; // 选择题选项
  final String correctAnswer; // 正确答案
  final String explanation; // 答案解析
  final DateTime createdAt;
  
  Question({
    required this.id,
    required this.content,
    required this.type,
    required this.subject,
    required this.tags,
    required this.difficulty,
    this.answerOptions = const [],
    required this.correctAnswer,
    required this.explanation,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type.toString(),
      'subject': subject,
      'tags': tags.join(','),
      'difficulty': difficulty,
      'answer_options': answerOptions.join('|'),
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'],
      content: map['content'],
      type: _parseQuestionType(map['type']),
      subject: map['subject'],
      tags: map['tags'].split(',').where((t) => t.isNotEmpty).toList(),
      difficulty: map['difficulty'],
      answerOptions: map['answer_options'].split('|').where((a) => a.isNotEmpty).toList(),
      correctAnswer: map['correct_answer'],
      explanation: map['explanation'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

class UserAnswer {
  final String id;
  final String userId;
  final String questionId;
  final String userAnswer; // 用户答案
  final bool isCorrect;
  final DateTime answeredAt;
  final int timeSpent; // 用时（秒）
  final List<String>? feedback; // AI反馈
  
  UserAnswer({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.userAnswer,
    required this.isCorrect,
    required this.answeredAt,
    this.timeSpent = 0,
    this.feedback,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'user_answer': userAnswer,
      'is_correct': isCorrect ? 1 : 0,
      'answered_at': answeredAt.millisecondsSinceEpoch,
      'time_spent': timeSpent,
      'feedback': feedback?.join('|'),
    };
  }
  
  factory UserAnswer.fromMap(Map<String, dynamic> map) {
    return UserAnswer(
      id: map['id'],
      userId: map['user_id'],
      questionId: map['question_id'],
      userAnswer: map['user_answer'],
      isCorrect: map['is_correct'] == 1,
      answeredAt: DateTime.fromMillisecondsSinceEpoch(map['answered_at']),
      timeSpent: map['time_spent'],
      feedback: map['feedback']?.split('|').where((f) => f.isNotEmpty).toList(),
    );
  }
}

enum QuestionType {
  multipleChoice, // 选择题
  fillInBlank,    // 填空题
  calculation,     // 计算题
  application,    // 应用题
  proof,          // 证明题
}

QuestionType _parseQuestionType(String typeString) {
  switch (typeString) {
    case 'QuestionType.multipleChoice':
      return QuestionType.multipleChoice;
    case 'QuestionType.fillInBlank':
      return QuestionType.fillInBlank;
    case 'QuestionType.calculation':
      return QuestionType.calculation;
    case 'QuestionType.application':
      return QuestionType.application;
    case 'QuestionType.proof':
      return QuestionType.proof;
    default:
      return QuestionType.calculation;
  }
}