/// 出题智能体提示词
/// 负责根据学生情况生成题目

const String questionGeneratorPrompt = '''
你是"小书童"的出题助手，专门负责为学生生成练习题目。

【你的任务】
根据学生的要求（学科、知识点、难度）生成合适的练习题。

【思考过程要求】
在thinking部分，你必须：
1. 分析学生的需求（学科、知识点、难度偏好）
2. 设计题目的核心考点
3. **计算出正确答案和完整解题步骤**
4. 设计干扰项（如果是选择题）
5. 验证答案的正确性

【响应格式要求】
你必须返回JSON格式，包含question和answer两部分：

```json
{
  "question": {
    "type": "choice|fill|calculation|application",
    "subject": "数学|语文|英语|物理|化学",
    "difficulty": "easy|medium|hard",
    "content": "题目内容（支持Markdown格式）",
    "options": ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "image_hint": "可选，如果需要图形可描述"
  },
  "answer": {
    "correct": "A",
    "explanation": "详细解题步骤，用于黑板讲解",
    "key_points": ["知识点1", "知识点2"],
    "common_mistakes": ["常见错误1", "常见错误2"]
  }
}
```

【注意事项】
1. 题目难度要适中，让学生有成就感
2. 选择题要有合理的干扰项
3. 答案必须经过验证，确保正确
4. explanation字段要详细，后续会用于黑板讲解
5. 不要在JSON之外输出额外文字
''';

/// 题目类型
enum QuestionType {
  choice,       // 选择题
  fill,         // 填空题
  calculation,  // 计算题
  application,  // 应用题
}

/// 题目难度
enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

/// 题目数据模型
class QuestionData {
  final QuestionType type;
  final String subject;
  final QuestionDifficulty difficulty;
  final String content;
  final List<String>? options;
  final String? imageHint;

  QuestionData({
    required this.type,
    required this.subject,
    required this.difficulty,
    required this.content,
    this.options,
    this.imageHint,
  });

  factory QuestionData.fromJson(Map<String, dynamic> json) {
    return QuestionData(
      type: QuestionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestionType.choice,
      ),
      subject: json['subject'] ?? '数学',
      difficulty: QuestionDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => QuestionDifficulty.medium,
      ),
      content: json['content'] ?? '',
      options: json['options'] != null 
          ? List<String>.from(json['options']) 
          : null,
      imageHint: json['image_hint'],
    );
  }
}

/// 答案数据模型
class AnswerData {
  final String correct;
  final String explanation;
  final List<String> keyPoints;
  final List<String> commonMistakes;

  AnswerData({
    required this.correct,
    required this.explanation,
    this.keyPoints = const [],
    this.commonMistakes = const [],
  });

  factory AnswerData.fromJson(Map<String, dynamic> json) {
    return AnswerData(
      correct: json['correct']?.toString() ?? '',
      explanation: json['explanation'] ?? '',
      keyPoints: json['key_points'] != null 
          ? List<String>.from(json['key_points']) 
          : [],
      commonMistakes: json['common_mistakes'] != null 
          ? List<String>.from(json['common_mistakes']) 
          : [],
    );
  }
}

/// 完整的题目响应
class QuestionResponse {
  final QuestionData question;
  final AnswerData answer;

  QuestionResponse({required this.question, required this.answer});

  factory QuestionResponse.fromJson(Map<String, dynamic> json) {
    return QuestionResponse(
      question: QuestionData.fromJson(json['question'] ?? {}),
      answer: AnswerData.fromJson(json['answer'] ?? {}),
    );
  }
}
