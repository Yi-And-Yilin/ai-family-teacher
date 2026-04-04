import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/user.dart';
import '../models/question.dart';
import '../models/mistake_book.dart';
import '../models/note.dart';
import '../models/conversation.dart';

class DatabaseService {
  static const String _databaseName = 'ai_family_teacher.db';
  static const int _databaseVersion = 4;
  
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
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');
  }
  
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
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
  
  Future<List<UserAnswer>> getUserAnswers(String userId, {int limit = 50}) async {
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
  
  Future<MistakeRecord?> getMistakeRecord(String userId, String questionId) async {
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
      where: 'user_id = ? AND is_mastered = 0 AND (review_date IS NULL OR review_date <= ?)',
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
  
  Future<List<Note>> getNotes(String userId, {bool includeArchived = false}) async {
    final db = await database;
    final where = includeArchived ? 'user_id = ?' : 'user_id = ? AND is_archived = 0';
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
  
  Future<List<Conversation>> getConversations(String userId, {int limit = 50}) async {
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
    return await db.insert('messages', message.toMap());
  }
  
  Future<List<Message>> getMessages(String conversationId, {int limit = 100}) async {
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
  
  // ====================== 清理操作 ======================
  
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}