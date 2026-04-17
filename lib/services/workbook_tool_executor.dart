import 'dart:convert';
import 'database_service.dart';
import '../models/workbook.dart';

/// 作业本工具执行器
/// 处理 LLM 的 Function Calling 调用
class WorkbookToolExecutor {
  final DatabaseService _db = DatabaseService();
  
  /// 当前活跃的作业本ID（用于上下文）
  String? _currentWorkbookId;
  String? get currentWorkbookId => _currentWorkbookId;
  
  /// 执行工具调用
  Future<Map<String, dynamic>> execute(String toolName, Map<String, dynamic> arguments) async {
    print('[WorkbookTool] 执行工具: $toolName, 参数: $arguments');
    
    try {
      switch (toolName) {
        // 作业本管理
        case 'create_workbook':
          return await _createWorkbook(arguments);
        case 'get_workbooks':
          return await _getWorkbooks(arguments);
        case 'get_workbook':
          return await _getWorkbook(arguments);
        
        // 题目管理
        case 'create_question':
          return await _createQuestion(arguments);
        case 'get_questions':
          return await _getQuestions(arguments);
        case 'get_question':
          return await _getQuestion(arguments);
        case 'update_question':
          return await _updateQuestion(arguments);
        case 'delete_question':
          return await _deleteQuestion(arguments);
        
        // 用户作答
        case 'get_user_answer':
          return await _getUserAnswer(arguments);
        case 'get_all_user_answers':
          return await _getAllUserAnswers(arguments);
        
        // 批改
        case 'grade_answer':
          return await _gradeAnswer(arguments);
        case 'grade_answers':
          return await _gradeAnswers(arguments);
        case 'grade_workbook':
          return await _gradeWorkbook(arguments);
        
        // 讲解
        case 'explain_solution':
          return await _explainSolution(arguments);
        
        // 上传
        case 'upload_user_answer':
          return await _uploadUserAnswer(arguments);
        
        default:
          return {'error': '未知工具: $toolName'};
      }
    } catch (e) {
      print('[WorkbookTool] 执行错误: $e');
      return {'error': e.toString()};
    }
  }
  
  // ========== 作业本管理 ==========
  
  Future<Map<String, dynamic>> _createWorkbook(Map<String, dynamic> args) async {
    final id = await _db.insertWorkbook(
      title: args['title'] as String,
      description: args['description'] as String?,
      subject: args['subject'] as String?,
      gradeLevel: args['grade_level'] as int?,
    );

    _currentWorkbookId = id;

    return {
      'success': true,
      'workbook_id': id,
      'message': '作业本创建成功',
      'ui_action': 'append_to_workbook',
      'workbook_content': '📝 ${args['title'] ?? '新作业本'}',
    };
  }
  
  Future<Map<String, dynamic>> _getWorkbooks(Map<String, dynamic> args) async {
    final workbooks = await _db.getWorkbooks(
      subject: args['subject'] as String?,
      gradeLevel: args['grade_level'] as int?,
    );
    
    return {
      'success': true,
      'workbooks': workbooks,
      'count': workbooks.length,
    };
  }
  
  Future<Map<String, dynamic>> _getWorkbook(Map<String, dynamic> args) async {
    final workbookId = args['workbook_id'] as String;
    final workbook = await _db.getWorkbook(workbookId);

    if (workbook == null) {
      return {'error': '作业本不存在'};
    }

    // 同时获取题目列表
    final questions = await _db.getWorkbookQuestions(workbookId);

    return {
      'success': true,
      'workbook': workbook,
      'questions': questions,
      'question_count': questions.length,
    };
  }
  
  // ========== 题目管理 ==========
  
  Future<Map<String, dynamic>> _createQuestion(Map<String, dynamic> args) async {
    final workbookId = args['workbook_id'] as String? ?? _currentWorkbookId;
    
    if (workbookId == null) {
      return {'error': '需要指定作业本ID'};
    }
    
    // 获取当前题目数量作为题号
    final existingQuestions = await _db.getWorkbookQuestions(workbookId);
    final questionNumber = existingQuestions.length + 1;

    // 处理选项
    String? optionsJson;
    if (args['options'] != null) {
      optionsJson = jsonEncode(args['options']);
    }

    final id = await _db.insertWorkbookQuestion(
      workbookId: workbookId,
      questionNumber: questionNumber,
      questionType: args['question_type'] as String,
      content: args['content'] as String,
      options: optionsJson,
      correctAnswer: args['correct_answer'] as String,
      solution: args['solution'] as String?,
      difficulty: args['difficulty'] as int?,
    );
    
    return {
      'success': true,
      'question_id': id,
      'question_number': questionNumber,
      'message': '题目添加成功',
      'ui_action': 'append_to_workbook',
      'workbook_content': _formatQuestionForDisplay(args),
    };
  }

  /// 格式化题目为做题册显示文本
  String _formatQuestionForDisplay(Map<String, dynamic> args) {
    final content = args['content'] as String? ?? '';
    final options = args['options'] as List<dynamic>?;
    final questionType = args['question_type'] as String?;

    final buffer = StringBuffer();
    buffer.writeln('【题目】$content');

    if (questionType == 'choice' && options != null && options.isNotEmpty) {
      for (final opt in options) {
        buffer.writeln(opt.toString());
      }
    }
    buffer.writeln();
    return buffer.toString();
  }

  Future<Map<String, dynamic>> _getQuestions(Map<String, dynamic> args) async {
    final workbookId = args['workbook_id'] as String? ?? _currentWorkbookId;

    if (workbookId == null) {
      return {'error': '需要指定作业本ID'};
    }

    final questions = await _db.getWorkbookQuestions(workbookId);

    return {
      'success': true,
      'questions': questions,
      'count': questions.length,
    };
  }
  
  Future<Map<String, dynamic>> _getQuestion(Map<String, dynamic> args) async {
    final questionId = args['question_id'] as String;
    final question = await _db.getWorkbookQuestion(questionId);

    if (question == null) {
      return {'error': '题目不存在'};
    }

    return {
      'success': true,
      'question': question,
    };
  }
  
  Future<Map<String, dynamic>> _updateQuestion(Map<String, dynamic> args) async {
    final questionId = args['question_id'] as String;

    String? optionsJson;
    if (args['options'] != null) {
      optionsJson = jsonEncode(args['options']);
    }

    final count = await _db.updateWorkbookQuestion(
      questionId,
      content: args['content'] as String?,
      options: optionsJson,
      correctAnswer: args['correct_answer'] as String?,
      solution: args['solution'] as String?,
    );

    return {
      'success': count > 0,
      'updated': count,
    };
  }
  
  Future<Map<String, dynamic>> _deleteQuestion(Map<String, dynamic> args) async {
    final questionId = args['question_id'] as String;
    final count = await _db.deleteWorkbookQuestion(questionId);

    return {
      'success': count > 0,
      'deleted': count,
    };
  }
  
  // ========== 用户作答 ==========
  
  Future<Map<String, dynamic>> _getUserAnswer(Map<String, dynamic> args) async {
    final questionId = args['question_id'] as String;
    final answer = await _db.getWorkbookUserAnswer(questionId);

    return {
      'success': true,
      'answer': answer,
      'has_answer': answer != null,
    };
  }

  Future<Map<String, dynamic>> _getAllUserAnswers(Map<String, dynamic> args) async {
    final workbookId = args['workbook_id'] as String? ?? _currentWorkbookId;

    if (workbookId == null) {
      return {'error': '需要指定作业本ID'};
    }

    final answers = await _db.getAllWorkbookUserAnswers(workbookId);

    return {
      'success': true,
      'answers': answers,
      'count': answers.length,
    };
  }
  
  // ========== 批改 ==========
  
  Future<Map<String, dynamic>> _gradeAnswer(Map<String, dynamic> args) async {
    final questionId = args['question_id'] as String;
    final isCorrect = args['is_correct'] as bool;
    final feedback = args['feedback'] as String?;

    // 先确保有用户答案记录
    final existingAnswer = await _db.getWorkbookUserAnswer(questionId);

    if (existingAnswer == null) {
      // 如果没有用户答案，创建一个占位记录
      // 实际场景中用户应该先作答
      return {'error': '用户尚未作答此题'};
    }

    final count = await _db.gradeWorkbookAnswer(
      questionId,
      isCorrect: isCorrect,
      feedback: feedback,
    );

    return {
      'success': count > 0,
      'is_correct': isCorrect,
      'feedback': feedback,
      'ui_action': isCorrect ? 'show_correct_mark' : 'show_wrong_mark',
    };
  }
  
  Future<Map<String, dynamic>> _gradeAnswers(Map<String, dynamic> args) async {
    final answersList = args['answers'] as List;
    final results = <Map<String, dynamic>>[];
    
    for (final answer in answersList) {
      final result = await _gradeAnswer({
        'question_id': answer['question_id'],
        'is_correct': answer['is_correct'],
        'feedback': answer['feedback'],
      });
      results.add(result);
    }
    
    return {
      'success': true,
      'graded_count': results.where((r) => r['success'] == true).length,
      'results': results,
    };
  }
  
  Future<Map<String, dynamic>> _gradeWorkbook(Map<String, dynamic> args) async {
    final workbookId = args['workbook_id'] as String? ?? _currentWorkbookId;
    
    if (workbookId == null) {
      return {'error': '需要指定作业本ID'};
    }
    
    // 获取所有题目和答案
    final questions = await _db.getWorkbookQuestions(workbookId);
    final answers = await _db.getAllWorkbookUserAnswers(workbookId);
    
    // 统计
    int correctCount = 0;
    int wrongCount = 0;
    
    for (final answer in answers) {
      if (answer['is_correct'] == 1) {
        correctCount++;
      } else if (answer['is_correct'] == 0) {
        wrongCount++;
      }
    }
    
    final totalQuestions = questions.length;
    final answeredCount = correctCount + wrongCount;
    final score = totalQuestions > 0 
        ? (correctCount / totalQuestions * 100) 
        : 0.0;
    
    // 保存批改记录
    final gradingId = await _db.insertGrading(
      workbookId: workbookId,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      wrongCount: wrongCount,
      score: score,
    );
    
    return {
      'success': true,
      'grading_id': gradingId,
      'total_questions': totalQuestions,
      'answered_count': answeredCount,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'unanswered_count': totalQuestions - answeredCount,
      'score': score,
      'ui_action': 'show_score',
    };
  }
  
  // ========== 讲解 ==========
  
  Future<Map<String, dynamic>> _explainSolution(Map<String, dynamic> args) async {
    final questionId = args['question_id'] as String;
    final question = await _db.getWorkbookQuestion(questionId);

    if (question == null) {
      return {'error': '题目不存在'};
    }

    return {
      'success': true,
      'question': question,
      'ui_action': 'switch_to_blackboard',
      'content': question['content'],
      'solution': question['solution'],
    };
  }
  
  // ========== 上传 ==========
  
  Future<Map<String, dynamic>> _uploadUserAnswer(Map<String, dynamic> args) async {
    final workbookId = args['workbook_id'] as String? ?? _currentWorkbookId;
    
    if (workbookId == null) {
      return {'error': '需要指定作业本ID'};
    }
    
    // 这个方法需要配合 VL Service 来识别手写答案
    // 这里先返回提示，实际实现在 AIService 中处理
    return {
      'success': false,
      'message': '需要调用 VL Service 识别手写答案',
      'image_base64': args['image_base64'] != null ? '已接收' : '未提供',
    };
  }
}
