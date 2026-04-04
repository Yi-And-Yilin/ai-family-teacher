import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../models/conversation.dart';

class AppProvider with ChangeNotifier {
  // 当前显示的组件类型
  ComponentType _currentComponent = ComponentType.landing;
  ComponentType get currentComponent => _currentComponent;
  
  // 数据库服务
  final DatabaseService _databaseService = DatabaseService();
  DatabaseService get databaseService => _databaseService;

  // 头像颜色索引
  int _avatarGradientIndex = 0;
  int get avatarGradientIndex => _avatarGradientIndex;
  
  // 预设头像渐变色
  static final List<List<Color>> avatarGradients = [
    [const Color(0xFFFFB74D), const Color(0xFFF06292)], // 橙粉
    [const Color(0xFF64B5F6), const Color(0xFF4DD0E1)], // 蓝青
    [const Color(0xFF81C784), const Color(0xFF4DB6AC)], // 绿青
    [const Color(0xFFBA68C8), const Color(0xFF7986CB)], // 紫蓝
    [const Color(0xFFE57373), const Color(0xFFFFB74D)], // 红橙
    [const Color(0xFFF06292), const Color(0xFFBA68C8)], // 粉紫
  ];
  
  List<Color> get currentAvatarGradient => avatarGradients[_avatarGradientIndex];

  // 对话数据
  List<Message> _messages = [];
  List<Message> get messages => _messages;
  
  String? _currentThinking;
  String? get currentThinking => _currentThinking;
  
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  String _currentConversationId = 'default_conv';

  // 初始化数据库
  Future<void> initDatabase() async {
    if (kIsWeb) return;
    await _databaseService.database;
    await loadMessages();
  }

  Future<void> loadMessages() async {
    _messages = await _databaseService.getMessages(_currentConversationId);
    notifyListeners();
  }

  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void updateThinking(String? thinking) {
    _currentThinking = thinking;
    notifyListeners();
  }

  Future<void> addMessage(Message message) async {
    _messages.add(message);
    if (!kIsWeb) {
      // 检查是否已存在
      // 为简化，我们先尝试插入
      await _databaseService.insertMessage(message);
    }
    notifyListeners();
  }

  Future<void> updateLastAIMessage(String content, {String? thinking, List<Map<String, dynamic>>? toolCalls}) async {
    if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
      final last = _messages.last;
      _messages[_messages.length - 1] = Message(
        id: last.id,
        conversationId: last.conversationId,
        role: last.role,
        content: content,
        thinking: thinking ?? last.thinking,
        toolCalls: toolCalls ?? last.toolCalls,
        timestamp: last.timestamp,
      );
      notifyListeners();
    }
  }

  Future<void> finalizeLastMessage() async {
    if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
      if (!kIsWeb) {
        // 更新数据库（这里简单删了再插，或者你需要实现 updateMessage）
        // 暂时先这样，确保 UI 能够正确保存
        await _databaseService.insertMessage(_messages.last); 
      }
    }
  }
  
  void switchTo(ComponentType type) {
    _currentComponent = type;
    notifyListeners();
  }
  
  // 用户信息
  String _studentName = '小明';
  String get studentName => _studentName;
  void setStudentName(String name) {
    _studentName = name;
    notifyListeners();
  }
  
  // 设置头像颜色
  void setAvatarGradient(int index) {
    _avatarGradientIndex = index.clamp(0, avatarGradients.length - 1);
    notifyListeners();
  }
  
  // 学习统计
  int _todayQuestions = 0;
  int get todayQuestions => _todayQuestions;
  void incrementQuestions() {
    _todayQuestions++;
    notifyListeners();
  }
  
  // 黑板内容
  List<Map<String, dynamic>> _blackboardElements = [];
  List<Map<String, dynamic>> get blackboardElements => _blackboardElements;
  void updateBlackboard(List<Map<String, dynamic>> elements) {
    _blackboardElements = elements;
    notifyListeners();
  }

  // 作业本批改标记
  List<Map<String, dynamic>> _workbookMarks = [];
  List<Map<String, dynamic>> get workbookMarks => _workbookMarks;
  void updateWorkbookMarks(List<Map<String, dynamic>> marks) {
    _workbookMarks = marks;
    notifyListeners();
  }
  
  // 作业本当前题目
  String _currentQuestion = '';
  String get currentQuestion => _currentQuestion;
  void setCurrentQuestion(String question) {
    _currentQuestion = question;
    notifyListeners();
  }
  
  // 笔记本内容
  String _noteContent = '';
  String get noteContent => _noteContent;
  void updateNoteContent(String content) {
    _noteContent = content;
    notifyListeners();
  }
}

enum ComponentType {
  landing,      // 首页（默认）
  blackboard,   // 黑板
  workbook,     // 作业本  
  notebook,     // 笔记本
  dialog,       // 对话框
}
