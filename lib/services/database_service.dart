import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/user.dart';
import '../models/question.dart';
import '../models/mistake_book.dart';
import '../models/note.dart';
import '../models/conversation.dart';

class DatabaseService {
  static const String _databaseName = 'ai_family_teacher.db';
  static const int _databaseVersion = 8;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // 用户表
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        grade INTEGER NOT NULL,
        curriculum TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 对话组件状态表（版本8新增）
    await db.execute('''
      CREATE TABLE conversation_components (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id TEXT NOT NULL UNIQUE,
        active_component TEXT,
        workbook_content TEXT,
        blackboard_content TEXT,
        notebook_content TEXT,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');

    // 用户统计表
    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        questions_asked INTEGER DEFAULT 0,
        exercises_done INTEGER DEFAULT 0,
        accuracy_rate REAL DEFAULT 0,
        total_learning_time INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // 题目表
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        subject TEXT NOT NULL,
        tags TEXT,
        difficulty REAL DEFAULT 0.5,
        answer_options TEXT,
        correct_answer TEXT NOT NULL,
        explanation TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // 用户答案表
    await db.execute('''
      CREATE TABLE user_answers (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        user_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        answered_at INTEGER NOT NULL,
        time_spent INTEGER DEFAULT 0,
        feedback TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (question_id) REFERENCES questions (id)
      )
    ''');

    // 错题记录表
    await db.execute('''
      CREATE TABLE mistake_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        mistake_type TEXT NOT NULL,
        analysis TEXT,
        mistake_count INTEGER DEFAULT 1,
        first_mistake_at INTEGER NOT NULL,
        last_mistake_at INTEGER NOT NULL,
        mastery_level REAL DEFAULT 0,
        review_date INTEGER,
        is_mastered INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (question_id) REFERENCES questions (id)
      )
    ''');

    // 知识点表
    await db.execute('''
      CREATE TABLE knowledge_points (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        subject TEXT NOT NULL,
        description TEXT,
        related_points TEXT,
        difficulty REAL DEFAULT 0.5
      )
    ''');

    // 用户知识点进度表
    await db.execute('''
      CREATE TABLE user_knowledge_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        knowledge_point_id TEXT NOT NULL,
        total_questions INTEGER DEFAULT 0,
        correct_answers INTEGER DEFAULT 0,
        mistake_count INTEGER DEFAULT 0,
        mastery_level REAL DEFAULT 0,
        last_practiced_at INTEGER NOT NULL,
        next_review_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points (id)
      )
    ''');

    // 笔记表
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tags TEXT,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_archived INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // 手写笔画表
    await db.execute('''
      CREATE TABLE handwriting_strokes (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        points TEXT NOT NULL,
        color_r INTEGER NOT NULL,
        color_g INTEGER NOT NULL,
        color_b INTEGER NOT NULL,
        color_a REAL NOT NULL,
        width REAL NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes (id)
      )
    ''');

    // AI摘要表
    await db.execute('''
      CREATE TABLE ai_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        keywords TEXT,
        summary TEXT NOT NULL,
        related_questions TEXT,
        suggested_tags TEXT,
        summarized_at INTEGER NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes (id)
      )
    ''');

    // 对话会话表
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // 消息表
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        thinking TEXT,
        tool_calls TEXT,
        tool_call_id TEXT,
        images TEXT,
        tool_call_events TEXT,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');

    // 应用配置表（存储加密的 API Key 等）
    await db.execute('''
      CREATE TABLE app_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ========== 作业本系统 ==========

    // 作业本表
    await db.execute('''
      CREATE TABLE workbooks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        subject TEXT,
        grade_level INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 作业本题目表
    await db.execute('''
      CREATE TABLE workbook_questions (
        id TEXT PRIMARY KEY,
        workbook_id TEXT NOT NULL,
        question_number INTEGER NOT NULL,
        question_type TEXT NOT NULL,
        content TEXT NOT NULL,
        options TEXT,
        correct_answer TEXT NOT NULL,
        solution TEXT,
        difficulty INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (workbook_id) REFERENCES workbooks (id)
      )
    ''');

    // 用户作答表
    await db.execute('''
      CREATE TABLE workbook_user_answers (
        id TEXT PRIMARY KEY,
        question_id TEXT NOT NULL,
        user_answer TEXT NOT NULL,
        is_correct INTEGER,
        feedback TEXT,
        submitted_at INTEGER NOT NULL,
        graded_at INTEGER,
        FOREIGN KEY (question_id) REFERENCES workbook_questions (id)
      )
    ''');

    // 批改记录表
    await db.execute('''
      CREATE TABLE workbook_gradings (
        id TEXT PRIMARY KEY,
        workbook_id TEXT NOT NULL,
        total_questions INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        wrong_count INTEGER NOT NULL,
        score REAL NOT NULL,
        graded_at INTEGER NOT NULL,
        FOREIGN KEY (workbook_id) REFERENCES workbooks (id)
      )
    ''');
  }

  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 升级到版本2：添加对话和消息表
      await db.execute('''
        CREATE TABLE conversations (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          FOREIGN KEY (conversation_id) REFERENCES conversations (id)
        )
      ''');
    }

    if (oldVersion < 3) {
      // 升级到版本3：为消息表添加 AI 特性字段
      await db.execute('ALTER TABLE messages ADD COLUMN thinking TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN tool_calls TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN tool_call_id TEXT');
    }

    if (oldVersion < 4) {
      // 升级到版本4：添加图片支持
      await db.execute('ALTER TABLE messages ADD COLUMN images TEXT');
    }

    if (oldVersion < 5) {
      // 升级到版本5：添加应用配置表（存储加密的 API Key）
      await db.execute('''
        CREATE TABLE app_config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // 升级到版本6：添加作业本系统
      await db.execute('''
        CREATE TABLE workbooks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          subject TEXT,
          grade_level INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE workbook_questions (
          id TEXT PRIMARY KEY,
          workbook_id TEXT NOT NULL,
          question_number INTEGER NOT NULL,
          question_type TEXT NOT NULL,
          content TEXT NOT NULL,
          options TEXT,
          correct_answer TEXT NOT NULL,
          solution TEXT,
          difficulty INTEGER,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (workbook_id) REFERENCES workbooks (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE workbook_user_answers (
          id TEXT PRIMARY KEY,
          question_id TEXT NOT NULL,
          user_answer TEXT NOT NULL,
          is_correct INTEGER,
          feedback TEXT,
          submitted_at INTEGER NOT NULL,
          graded_at INTEGER,
          FOREIGN KEY (question_id) REFERENCES workbook_questions (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE workbook_gradings (
          id TEXT PRIMARY KEY,
          workbook_id TEXT NOT NULL,
          total_questions INTEGER NOT NULL,
          correct_count INTEGER NOT NULL,
          wrong_count INTEGER NOT NULL,
          score REAL NOT NULL,
          graded_at INTEGER NOT NULL,
          FOREIGN KEY (workbook_id) REFERENCES workbooks (id)
        )
      ''');
    }

    if (oldVersion < 7) {
      // 升级到版本7：添加工具调用指标列
      try {
        await db
            .execute('ALTER TABLE messages ADD COLUMN tool_call_events TEXT');
      } catch (e) {
        // 列可能已存在，忽略错误
        print('[Database] tool_call_events column may already exist: $e');
      }
    }

    if (oldVersion < 8) {
      // 升级到版本8：添加对话组件状态表
      await db.execute('''
        CREATE TABLE conversation_components (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conversation_id TEXT NOT NULL UNIQUE,
          active_component TEXT,
          workbook_content TEXT,
          blackboard_content TEXT,
          notebook_content TEXT,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (conversation_id) REFERENCES conversations (id)
        )
      ''');
    }

    try {
      final result = await db.rawQuery("PRAGMA table_info(messages)");
      bool columnExists = false;
      for (final row in result) {
        if (row['name'] == 'tool_call_events') {
          columnExists = true;
          break;
        }
      }
      if (!columnExists) {
        await db
            .execute('ALTER TABLE messages ADD COLUMN tool_call_events TEXT');
        print('[Database] Added tool_call_events column to messages table');
      }
    } catch (e) {
      print('[Database] tool_call_events column check/add error: $e');
    }
  }

  Future<bool> _columnsExist(Database db, String table, String column) async {
    final result = await db.rawQuery("PRAGMA table_info($table)");
    for (final row in result) {
      if (row['name'] == column) return true;
    }
    return false;
  }

  // ====================== 用户操作 ======================

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser(String userId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // ====================== 用户统计操作 ======================

  Future<int> insertUserStats(UserStats stats) async {
    final db = await database;
    return await db.insert('user_stats', stats.toMap());
  }

  Future<UserStats?> getTodayStats(String userId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final maps = await db.query(
      'user_stats',
      where: 'user_id = ? AND date >= ?',
      whereArgs: [userId, startOfDay.millisecondsSinceEpoch],
    );

    if (maps.isEmpty) return null;
    return UserStats.fromMap(maps.first);
  }

  Future<int> updateUserStats(UserStats stats) async {
    final db = await database;
    return await db.update(
      'user_stats',
      stats.toMap(),
      where: 'user_id = ? AND date = ?',
      whereArgs: [stats.userId, stats.date.millisecondsSinceEpoch],
    );
  }

  // ====================== 题目操作 ======================

  Future<int> insertQuestion(Question question) async {
    final db = await database;
    return await db.insert('questions', question.toMap());
  }

  Future<Question?> getQuestion(String questionId) async {
    final db = await database;
    final maps = await db.query(
      'questions',
      where: 'id = ?',
      whereArgs: [questionId],
    );
    if (maps.isEmpty) return null;
    return Question.fromMap(maps.first);
  }

  Future<List<Question>> getQuestionsByTags(List<String> tags) async {
    if (tags.isEmpty) return [];

    final db = await database;
    final tagCondition = tags.map((_) => 'tags LIKE ?').join(' OR ');
    final tagArgs = tags.map((tag) => '%$tag%').toList();

    final maps = await db.query(
      'questions',
      where: tagCondition,
      whereArgs: tagArgs,
    );

    return maps.map((map) => Question.fromMap(map)).toList();
  }

  // ====================== 用户答案操作 ======================

  Future<int> insertUserAnswer(UserAnswer answer) async {
    final db = await database;
    return await db.insert('user_answers', answer.toMap());
  }

  Future<List<UserAnswer>> getUserAnswers(String userId,
      {int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'user_answers',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'answered_at DESC',
      limit: limit,
    );

    return maps.map((map) => UserAnswer.fromMap(map)).toList();
  }

  // ====================== 错题操作 ======================

  Future<int> insertMistakeRecord(MistakeRecord record) async {
    final db = await database;
    return await db.insert('mistake_records', record.toMap());
  }

  Future<MistakeRecord?> getMistakeRecord(
      String userId, String questionId) async {
    final db = await database;
    final maps = await db.query(
      'mistake_records',
      where: 'user_id = ? AND question_id = ?',
      whereArgs: [userId, questionId],
    );

    if (maps.isEmpty) return null;
    return MistakeRecord.fromMap(maps.first);
  }

  Future<List<MistakeRecord>> getMistakeRecordsToReview(String userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final maps = await db.query(
      'mistake_records',
      where:
          'user_id = ? AND is_mastered = 0 AND (review_date IS NULL OR review_date <= ?)',
      whereArgs: [userId, now],
      orderBy: 'mastery_level ASC, last_mistake_at DESC',
    );

    return maps.map((map) => MistakeRecord.fromMap(map)).toList();
  }

  // ====================== 笔记操作 ======================

  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes(String userId,
      {bool includeArchived = false}) async {
    final db = await database;
    final where =
        includeArchived ? 'user_id = ?' : 'user_id = ? AND is_archived = 0';
    final maps = await db.query(
      'notes',
      where: where,
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // ====================== 手写笔画操作 ======================

  Future<int> insertHandwritingStroke(HandwritingStroke stroke) async {
    final db = await database;
    return await db.insert('handwriting_strokes', stroke.toMap());
  }

  Future<List<HandwritingStroke>> getHandwritingStrokes(String noteId) async {
    final db = await database;
    final maps = await db.query(
      'handwriting_strokes',
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => HandwritingStroke.fromMap(map)).toList();
  }

  // ====================== 对话操作 ======================

  Future<int> insertConversation(Conversation conversation) async {
    final db = await database;
    return await db.insert('conversations', conversation.toMap());
  }

  Future<List<Conversation>> getConversations(String userId,
      {int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
      limit: limit,
    );

    return maps.map((map) => Conversation.fromMap(map)).toList();
  }

  Future<Conversation?> getConversation(String conversationId) async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    if (maps.isEmpty) return null;
    return Conversation.fromMap(maps.first);
  }

  Future<int> updateConversation(Conversation conversation) async {
    final db = await database;
    return await db.update(
      'conversations',
      conversation.toMap(),
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
  }

  Future<int> deleteConversation(String conversationId) async {
    final db = await database;
    // 先删除关联的消息
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    return await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // ====================== 消息操作 ======================

  Future<int> insertMessage(Message message) async {
    final db = await database;
    // 使用 INSERT OR REPLACE 避免唯一约束冲突
    return await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String conversationId,
      {int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return maps.map((map) => Message.fromMap(map)).toList();
  }

  Future<int> deleteMessages(String conversationId) async {
    final db = await database;
    return await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  // ====================== 对话组件状态操作 ======================

  /// 保存对话组件状态
  Future<void> saveConversationComponentState({
    required String conversationId,
    required String? activeComponent,
    String? workbookContent,
    String? blackboardContent,
    String? notebookContent,
  }) async {
    final db = await database;
    await db.insert(
      'conversation_components',
      {
        'conversation_id': conversationId,
        'active_component': activeComponent,
        'workbook_content': workbookContent,
        'blackboard_content': blackboardContent,
        'notebook_content': notebookContent,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取对话组件状态
  Future<Map<String, dynamic>?> getConversationComponentState(
      String conversationId) async {
    final db = await database;
    final maps = await db.query(
      'conversation_components',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// 删除对话组件状态
  Future<int> deleteConversationComponentState(String conversationId) async {
    final db = await database;
    return await db.delete(
      'conversation_components',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  // ====================== 清理操作 ======================

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// 清空所有数据（用于测试）
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('conversation_components');
    await db.delete('messages');
    await db.delete('conversations');
    print('[DEBUG] Database: all data cleared');
  }

  // ====================== 应用配置操作 ======================

  /// 保存配置值（如加密的 API Key）
  Future<int> setConfig(String key, String value) async {
    final db = await database;
    return await db.insert(
      'app_config',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取配置值
  Future<String?> getConfig(String key) async {
    final db = await database;
    final maps = await db.query(
      'app_config',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  /// 删除配置值
  Future<int> deleteConfig(String key) async {
    final db = await database;
    return await db.delete(
      'app_config',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // ====================== 作业本系统操作 ======================

  // ----- Workbook 操作 -----

  Future<String> insertWorkbook({
    required String title,
    String? description,
    String? subject,
    int? gradeLevel,
  }) async {
    final db = await database;
    final id = 'wb_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('workbooks', {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'grade_level': gradeLevel,
      'created_at': now,
      'updated_at': now,
    });

    return id;
  }

  Future<List<Map<String, dynamic>>> getWorkbooks(
      {String? subject, int? gradeLevel}) async {
    final db = await database;

    String where = '';
    List<dynamic> whereArgs = [];

    if (subject != null && gradeLevel != null) {
      where = 'subject = ? AND grade_level = ?';
      whereArgs = [subject, gradeLevel];
    } else if (subject != null) {
      where = 'subject = ?';
      whereArgs = [subject];
    } else if (gradeLevel != null) {
      where = 'grade_level = ?';
      whereArgs = [gradeLevel];
    }

    final maps = await db.query(
      'workbooks',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    return maps;
  }

  Future<Map<String, dynamic>?> getWorkbook(String workbookId) async {
    final db = await database;
    final maps = await db.query(
      'workbooks',
      where: 'id = ?',
      whereArgs: [workbookId],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> updateWorkbook(String workbookId,
      {String? title, String? description}) async {
    final db = await database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;

    return await db.update(
      'workbooks',
      updates,
      where: 'id = ?',
      whereArgs: [workbookId],
    );
  }

  Future<int> deleteWorkbook(String workbookId) async {
    final db = await database;
    // 先删除关联的题目和答案
    await db.delete('workbook_user_answers',
        where:
            'question_id IN (SELECT id FROM workbook_questions WHERE workbook_id = ?)',
        whereArgs: [workbookId]);
    await db.delete('workbook_questions',
        where: 'workbook_id = ?', whereArgs: [workbookId]);
    await db.delete('workbook_gradings',
        where: 'workbook_id = ?', whereArgs: [workbookId]);
    return await db
        .delete('workbooks', where: 'id = ?', whereArgs: [workbookId]);
  }

  // ----- Question 操作 -----

  Future<String> insertWorkbookQuestion({
    required String workbookId,
    required int questionNumber,
    required String questionType, // choice, fill_blank, essay
    required String content,
    String? options, // JSON 字符串
    required String correctAnswer,
    String? solution,
    int? difficulty,
  }) async {
    final db = await database;
    final id = 'q_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('workbook_questions', {
      'id': id,
      'workbook_id': workbookId,
      'question_number': questionNumber,
      'question_type': questionType,
      'content': content,
      'options': options,
      'correct_answer': correctAnswer,
      'solution': solution,
      'difficulty': difficulty,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // 更新 workbook 的 updated_at
    await db.update(
      'workbooks',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [workbookId],
    );

    return id;
  }

  Future<List<Map<String, dynamic>>> getWorkbookQuestions(
      String workbookId) async {
    final db = await database;
    return await db.query(
      'workbook_questions',
      where: 'workbook_id = ?',
      whereArgs: [workbookId],
      orderBy: 'question_number ASC',
    );
  }

  Future<Map<String, dynamic>?> getWorkbookQuestion(String questionId) async {
    final db = await database;
    final maps = await db.query(
      'workbook_questions',
      where: 'id = ?',
      whereArgs: [questionId],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> updateWorkbookQuestion(
    String questionId, {
    String? content,
    String? options,
    String? correctAnswer,
    String? solution,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};

    if (content != null) updates['content'] = content;
    if (options != null) updates['options'] = options;
    if (correctAnswer != null) updates['correct_answer'] = correctAnswer;
    if (solution != null) updates['solution'] = solution;

    if (updates.isEmpty) return 0;

    return await db.update(
      'workbook_questions',
      updates,
      where: 'id = ?',
      whereArgs: [questionId],
    );
  }

  Future<int> deleteWorkbookQuestion(String questionId) async {
    final db = await database;
    await db.delete('workbook_user_answers',
        where: 'question_id = ?', whereArgs: [questionId]);
    return await db
        .delete('workbook_questions', where: 'id = ?', whereArgs: [questionId]);
  }

  // ----- User Answer 操作 -----

  Future<String> insertWorkbookUserAnswer({
    required String questionId,
    required String userAnswer,
  }) async {
    final db = await database;
    final id = 'ua_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('workbook_user_answers', {
      'id': id,
      'question_id': questionId,
      'user_answer': userAnswer,
      'submitted_at': DateTime.now().millisecondsSinceEpoch,
    });

    return id;
  }

  Future<Map<String, dynamic>?> getWorkbookUserAnswer(String questionId) async {
    final db = await database;
    final maps = await db.query(
      'workbook_user_answers',
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'submitted_at DESC',
      limit: 1,
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllWorkbookUserAnswers(
      String workbookId) async {
    final db = await database;

    final maps = await db.rawQuery('''
      SELECT ua.*, q.question_number, q.content, q.correct_answer
      FROM workbook_user_answers ua
      JOIN workbook_questions q ON ua.question_id = q.id
      WHERE q.workbook_id = ?
      ORDER BY q.question_number ASC
    ''', [workbookId]);

    return maps;
  }

  Future<int> gradeWorkbookAnswer(String questionId,
      {required bool isCorrect, String? feedback}) async {
    final db = await database;
    return await db.update(
      'workbook_user_answers',
      {
        'is_correct': isCorrect ? 1 : 0,
        'feedback': feedback,
        'graded_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
  }

  // ----- Grading 操作 -----

  Future<String> insertGrading({
    required String workbookId,
    required int totalQuestions,
    required int correctCount,
    required int wrongCount,
    required double score,
  }) async {
    final db = await database;
    final id = 'gr_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('workbook_gradings', {
      'id': id,
      'workbook_id': workbookId,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'score': score,
      'graded_at': DateTime.now().millisecondsSinceEpoch,
    });

    return id;
  }

  Future<Map<String, dynamic>?> getLatestGrading(String workbookId) async {
    final db = await database;
    final maps = await db.query(
      'workbook_gradings',
      where: 'workbook_id = ?',
      whereArgs: [workbookId],
      orderBy: 'graded_at DESC',
      limit: 1,
    );

    return maps.isNotEmpty ? maps.first : null;
  }
}
