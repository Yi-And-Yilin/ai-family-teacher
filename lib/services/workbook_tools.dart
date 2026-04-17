/// 作业本系统的 LLM 工具定义
/// 用于 Function Calling / Tool Calling

class WorkbookTools {
  /// 获取所有工具定义
  static List<Map<String, dynamic>> get allTools => [
    createWorkbook,
    getWorkbooks,
    getWorkbook,
    createQuestion,
    getQuestions,
    getQuestion,
    updateQuestion,
    deleteQuestion,
    getUserAnswer,
    getAllUserAnswers,
    gradeAnswer,
    gradeAnswers,
    gradeWorkbook,
    explainSolution,
    uploadUserAnswer,
  ];
  
  // ========== 作业本管理 ==========
  
  static const Map<String, dynamic> createWorkbook = {
    'type': 'function',
    'function': {
      'name': 'create_workbook',
      'description': '创建新的作业本',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '作业本标题，如"五年级数学练习"',
          },
          'subject': {
            'type': 'string',
            'enum': ['数学', '语文', '英语', '科学'],
            'description': '科目',
          },
          'grade_level': {
            'type': 'integer',
            'description': '年级，如 3、4、5',
          },
          'description': {
            'type': 'string',
            'description': '作业本描述',
          },
        },
        'required': ['title'],
      },
    },
  };
  
  static const Map<String, dynamic> getWorkbooks = {
    'type': 'function',
    'function': {
      'name': 'get_workbooks',
      'description': '获取作业本列表',
      'parameters': {
        'type': 'object',
        'properties': {
          'subject': {
            'type': 'string',
            'description': '按科目筛选',
          },
          'grade_level': {
            'type': 'integer',
            'description': '按年级筛选',
          },
        },
      },
    },
  };
  
  static const Map<String, dynamic> getWorkbook = {
    'type': 'function',
    'function': {
      'name': 'get_workbook',
      'description': '获取单个作业本详情',
      'parameters': {
        'type': 'object',
        'properties': {
          'workbook_id': {
            'type': 'string',
            'description': '作业本ID',
          },
        },
        'required': ['workbook_id'],
      },
    },
  };
  
  // ========== 题目管理 ==========
  
  static const Map<String, dynamic> createQuestion = {
    'type': 'function',
    'function': {
      'name': 'create_question',
      'description': '在作业本中添加题目',
      'parameters': {
        'type': 'object',
        'properties': {
          'workbook_id': {
            'type': 'string',
            'description': '作业本ID',
          },
          'question_type': {
            'type': 'string',
            'enum': ['choice', 'fill_blank', 'essay'],
            'description': '题目类型：choice=选择题，fill_blank=填空题，essay=问答题',
          },
          'content': {
            'type': 'string',
            'description': '题干内容',
          },
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '选项列表（选择题用），如 ["A. 48支", "B. 54支", "C. 60支", "D. 72支"]',
          },
          'correct_answer': {
            'type': 'string',
            'description': '正确答案。选择题填选项字母如"A"，填空题填具体答案',
          },
          'solution': {
            'type': 'string',
            'description': '解答过程',
          },
          'difficulty': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 5,
            'description': '难度等级 1-5',
          },
        },
        'required': ['workbook_id', 'question_type', 'content', 'correct_answer'],
      },
    },
  };
  
  static const Map<String, dynamic> getQuestions = {
    'type': 'function',
    'function': {
      'name': 'get_questions',
      'description': '获取作业本的所有题目',
      'parameters': {
        'type': 'object',
        'properties': {
          'workbook_id': {
            'type': 'string',
            'description': '作业本ID',
          },
        },
        'required': ['workbook_id'],
      },
    },
  };
  
  static const Map<String, dynamic> getQuestion = {
    'type': 'function',
    'function': {
      'name': 'get_question',
      'description': '获取单道题目详情',
      'parameters': {
        'type': 'object',
        'properties': {
          'question_id': {
            'type': 'string',
            'description': '题目ID',
          },
        },
        'required': ['question_id'],
      },
    },
  };
  
  static const Map<String, dynamic> updateQuestion = {
    'type': 'function',
    'function': {
      'name': 'update_question',
      'description': '修改题目',
      'parameters': {
        'type': 'object',
        'properties': {
          'question_id': {
            'type': 'string',
            'description': '题目ID',
          },
          'content': {
            'type': 'string',
            'description': '新的题干内容',
          },
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '新的选项列表',
          },
          'correct_answer': {
            'type': 'string',
            'description': '新的正确答案',
          },
          'solution': {
            'type': 'string',
            'description': '新的解答过程',
          },
        },
        'required': ['question_id'],
      },
    },
  };
  
  static const Map<String, dynamic> deleteQuestion = {
    'type': 'function',
    'function': {
      'name': 'delete_question',
      'description': '删除题目',
      'parameters': {
        'type': 'object',
        'properties': {
          'question_id': {
            'type': 'string',
            'description': '题目ID',
          },
        },
        'required': ['question_id'],
      },
    },
  };
  
  // ========== 用户作答 ==========
  
  static const Map<String, dynamic> getUserAnswer = {
    'type': 'function',
    'function': {
      'name': 'get_user_answer',
      'description': '获取用户对某题的作答',
      'parameters': {
        'type': 'object',
        'properties': {
          'question_id': {
            'type': 'string',
            'description': '题目ID',
          },
        },
        'required': ['question_id'],
      },
    },
  };
  
  static const Map<String, dynamic> getAllUserAnswers = {
    'type': 'function',
    'function': {
      'name': 'get_all_user_answers',
      'description': '获取作业本所有题目的用户作答',
      'parameters': {
        'type': 'object',
        'properties': {
          'workbook_id': {
            'type': 'string',
            'description': '作业本ID',
          },
        },
        'required': ['workbook_id'],
      },
    },
  };
  
  // ========== 批改 ==========
  
  static const Map<String, dynamic> gradeAnswer = {
    'type': 'function',
    'function': {
      'name': 'grade_answer',
      'description': '批改单道题目，返回是否正确和反馈。UI会根据结果显示叉号或勾，错误时背景变浅红色。',
      'parameters': {
        'type': 'object',
        'properties': {
          'question_id': {
            'type': 'string',
            'description': '题目ID',
          },
          'is_correct': {
            'type': 'boolean',
            'description': '是否正确',
          },
          'feedback': {
            'type': 'string',
            'description': '反馈/讲解内容',
          },
        },
        'required': ['question_id', 'is_correct'],
      },
    },
  };
  
  static const Map<String, dynamic> gradeAnswers = {
    'type': 'function',
    'function': {
      'name': 'grade_answers',
      'description': '批改多道题目',
      'parameters': {
        'type': 'object',
        'properties': {
          'answers': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'question_id': {'type': 'string'},
                'is_correct': {'type': 'boolean'},
                'feedback': {'type': 'string'},
              },
              'required': ['question_id', 'is_correct'],
            },
            'description': '批改结果列表',
          },
        },
        'required': ['answers'],
      },
    },
  };
  
  static const Map<String, dynamic> gradeWorkbook = {
    'type': 'function',
    'function': {
      'name': 'grade_workbook',
      'description': '批改整个作业本，计算总分。UI会在作业本右上角显示百分制评分。',
      'parameters': {
        'type': 'object',
        'properties': {
          'workbook_id': {
            'type': 'string',
            'description': '作业本ID',
          },
        },
        'required': ['workbook_id'],
      },
    },
  };
  
  // ========== 讲解 ==========
  
  static const Map<String, dynamic> explainSolution = {
    'type': 'function',
    'function': {
      'name': 'explain_solution',
      'description': '讲解题目解答过程。会切换到黑板模式，在黑板上展示题目和解答步骤。',
      'parameters': {
        'type': 'object',
        'properties': {
          'question_id': {
            'type': 'string',
            'description': '要讲解的题目ID',
          },
        },
        'required': ['question_id'],
      },
    },
  };
  
  // ========== 上传 ==========
  
  static const Map<String, dynamic> uploadUserAnswer = {
    'type': 'function',
    'function': {
      'name': 'upload_user_answer',
      'description': '处理用户上传的作业照片。读取手写答案并更新到系统。用于用户打印作业本后手写完成再拍照上传的场景。',
      'parameters': {
        'type': 'object',
        'properties': {
          'workbook_id': {
            'type': 'string',
            'description': '作业本ID',
          },
          'image_base64': {
            'type': 'string',
            'description': '作业照片的base64编码',
          },
        },
        'required': ['workbook_id', 'image_base64'],
      },
    },
  };
}
