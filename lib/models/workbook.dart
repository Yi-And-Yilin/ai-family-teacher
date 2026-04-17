/// 作业本模型
class Workbook {
  final String id;
  final String title;
  final String? description;
  final String? subject;
  final int? gradeLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workbook({
    required this.id,
    required this.title,
    this.description,
    this.subject,
    this.gradeLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Workbook.fromMap(Map<String, dynamic> map) {
    return Workbook(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      subject: map['subject'] as String?,
      gradeLevel: map['grade_level'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'grade_level': gradeLevel,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// 题目类型
enum QuestionType {
  choice,      // 选择题
  fillBlank,   // 填空题
  essay,       // 问答题
}

/// 题目模型
class WorkbookQuestion {
  final String id;
  final String workbookId;
  final int questionNumber;
  final QuestionType questionType;
  final String content;
  final List<String>? options;      // 选项（选择题用）
  final String correctAnswer;
  final String? solution;
  final int? difficulty;            // 难度 1-5
  final DateTime createdAt;

  WorkbookQuestion({
    required this.id,
    required this.workbookId,
    required this.questionNumber,
    required this.questionType,
    required this.content,
    this.options,
    required this.correctAnswer,
    this.solution,
    this.difficulty,
    required this.createdAt,
  });

  factory WorkbookQuestion.fromMap(Map<String, dynamic> map) {
    return WorkbookQuestion(
      id: map['id'] as String,
      workbookId: map['workbook_id'] as String,
      questionNumber: map['question_number'] as int,
      questionType: QuestionType.values.firstWhere(
        (e) => e.name == map['question_type'],
        orElse: () => QuestionType.choice,
      ),
      content: map['content'] as String,
      options: map['options'] != null 
          ? (map['options'] as String).split('|||')
          : null,
      correctAnswer: map['correct_answer'] as String,
      solution: map['solution'] as String?,
      difficulty: map['difficulty'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workbook_id': workbookId,
      'question_number': questionNumber,
      'question_type': questionType.name,
      'content': content,
      'options': options?.join('|||'),
      'correct_answer': correctAnswer,
      'solution': solution,
      'difficulty': difficulty,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

/// 用户作答模型
class WorkbookUserAnswer {
  final String id;
  final String questionId;
  final String userAnswer;
  final bool? isCorrect;
  final String? feedback;
  final DateTime submittedAt;
  final DateTime? gradedAt;

  WorkbookUserAnswer({
    required this.id,
    required this.questionId,
    required this.userAnswer,
    this.isCorrect,
    this.feedback,
    required this.submittedAt,
    this.gradedAt,
  });

  factory WorkbookUserAnswer.fromMap(Map<String, dynamic> map) {
    return WorkbookUserAnswer(
      id: map['id'] as String,
      questionId: map['question_id'] as String,
      userAnswer: map['user_answer'] as String,
      isCorrect: map['is_correct'] != null 
          ? map['is_correct'] == 1 
          : null,
      feedback: map['feedback'] as String?,
      submittedAt: DateTime.fromMillisecondsSinceEpoch(map['submitted_at'] as int),
      gradedAt: map['graded_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['graded_at'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'user_answer': userAnswer,
      'is_correct': isCorrect == true ? 1 : (isCorrect == false ? 0 : null),
      'feedback': feedback,
      'submitted_at': submittedAt.millisecondsSinceEpoch,
      'graded_at': gradedAt?.millisecondsSinceEpoch,
    };
  }
}

/// 批改记录模型
class WorkbookGrading {
  final String id;
  final String workbookId;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final double score;           // 0-100
  final DateTime gradedAt;

  WorkbookGrading({
    required this.id,
    required this.workbookId,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.score,
    required this.gradedAt,
  });

  factory WorkbookGrading.fromMap(Map<String, dynamic> map) {
    return WorkbookGrading(
      id: map['id'] as String,
      workbookId: map['workbook_id'] as String,
      totalQuestions: map['total_questions'] as int,
      correctCount: map['correct_count'] as int,
      wrongCount: map['wrong_count'] as int,
      score: map['score'] as double,
      gradedAt: DateTime.fromMillisecondsSinceEpoch(map['graded_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workbook_id': workbookId,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'score': score,
      'graded_at': gradedAt.millisecondsSinceEpoch,
    };
  }
}
