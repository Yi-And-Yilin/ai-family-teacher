import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../services/database_service.dart';
import '../services/api_config.dart';
import '../models/conversation.dart';
import '../prompts/question_generator_prompt.dart';
import '../prompts/answer_explainer_prompt.dart';

class AppProvider with ChangeNotifier {
  // 当前显示的组件类型
  ComponentType _currentComponent = ComponentType.landing;
  ComponentType get currentComponent => _currentComponent;
  
  // 黑板+聊天模式
  bool _showBlackboardWithChat = false;
  bool get showBlackboardWithChat => _showBlackboardWithChat;
  
  // 数据库服务
  final DatabaseService _databaseService = DatabaseService();
  DatabaseService get databaseService => _databaseService;
  
  // API 配置服务
  late final APIConfigService _apiConfig;
  APIConfigService get apiConfig => _apiConfig;
  
  AppProvider() {
    // 监听 APIConfigService 的变化，转发通知
    _apiConfig = APIConfigService()..addListener(_onApiConfigChanged);
  }
  
  void _onApiConfigChanged() {
    notifyListeners();
  }
  
  @override
  void dispose() {
    _apiConfig.removeListener(_onApiConfigChanged);
    _apiConfig.dispose();
    super.dispose();
  }

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
  
  // 对话列表
  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;
  
  String? _currentThinking;
  String? get currentThinking => _currentThinking;
  
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  String _currentConversationId = 'default_conv';
  String get currentConversationId => _currentConversationId;

  // 当前题目
  QuestionData? _currentQuestionData;
  QuestionData? get currentQuestionData => _currentQuestionData;
  
  // 当前答案
  AnswerData? _currentAnswerData;
  AnswerData? get currentAnswerData => _currentAnswerData;
  
  // 用户答案
  String? _userAnswer;
  String? get userAnswer => _userAnswer;
  
  // 是否显示答案
  bool _showAnswer = false;
  bool get showAnswer => _showAnswer;

  // 初始化数据库和API配置
  Future<void> initDatabase() async {
    // 初始化 API 配置
    await _apiConfig.init();
    
    if (kIsWeb) return;
    await _databaseService.database;
    
    // 加载历史对话列表
    await loadConversations();
    
    // 创建新的对话
    await createNewConversation();
  }

  Future<void> loadMessages() async {
    _messages = await _databaseService.getMessages(_currentConversationId);
    notifyListeners();
  }
  
  // 加载历史对话列表
  Future<void> loadConversations() async {
    _conversations = await _databaseService.getConversations('default_user');
    notifyListeners();
  }
  
  // 创建新对话
  Future<void> createNewConversation() async {
    final newConversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'default_user',
      title: '新对话',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _databaseService.insertConversation(newConversation);
    _currentConversationId = newConversation.id;
    _messages = [];
    _conversations.insert(0, newConversation);
    notifyListeners();
  }
  
  // 切换到指定对话
  Future<void> switchConversation(String conversationId) async {
    if (_currentConversationId == conversationId) return;
    
    _currentConversationId = conversationId;
    await loadMessages();
    notifyListeners();
  }
  
  // 删除对话
  Future<void> deleteConversation(String conversationId) async {
    await _databaseService.deleteConversation(conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    
    // 如果删除的是当前对话，创建新对话
    if (_currentConversationId == conversationId) {
      await createNewConversation();
    }
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
  
  // 开启/关闭黑板+聊天模式
  void setBlackboardWithChatMode(bool enabled) {
    _showBlackboardWithChat = enabled;
    if (enabled) {
      _currentComponent = ComponentType.blackboardChat;
    } else if (_currentComponent == ComponentType.blackboardChat) {
      _currentComponent = ComponentType.dialog;
    }
    notifyListeners();
  }
  
  // 设置当前题目
  void setCurrentQuestionData(QuestionData? question, {AnswerData? answer}) {
    _currentQuestionData = question;
    _currentAnswerData = answer;
    _showAnswer = false;
    _userAnswer = null;
    notifyListeners();
  }
  
  // 设置用户答案
  void setUserAnswer(String answer) {
    _userAnswer = answer;
    notifyListeners();
  }
  
  // 显示答案
  void revealAnswer() {
    _showAnswer = true;
    notifyListeners();
  }
  
  // 清除当前题目
  void clearQuestion() {
    _currentQuestionData = null;
    _currentAnswerData = null;
    _userAnswer = null;
    _showAnswer = false;
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
  
  // 自动播放语音设置
  bool _autoSpeak = true;
  bool get autoSpeak => _autoSpeak;
  void setAutoSpeak(bool value) {
    _autoSpeak = value;
    notifyListeners();
  }
  
  // 黑板内容（手写笔迹层）
  List<Map<String, dynamic>> _blackboardElements = [];
  List<Map<String, dynamic>> get blackboardElements => _blackboardElements;
  void updateBlackboard(List<Map<String, dynamic>> elements) {
    _blackboardElements = elements;
    notifyListeners();
  }
  
  // 添加黑板元素（用于手写笔迹）
  void appendBlackboardElements(List<BlackboardElement> elements) {
    for (final element in elements) {
      _blackboardElements.add(element.toJson());
    }
    notifyListeners();
  }
  
  // 清空黑板（手写笔迹）
  void clearBlackboard() {
    _blackboardElements.clear();
    notifyListeners();
  }
  
  // === 流式黑板内容（AI输出的文本/公式） ===
  String _streamingBlackboardContent = '';
  String get streamingBlackboardContent => _streamingBlackboardContent;
  
  // 流式追加黑板内容
  void appendToBlackboardContent(String content) {
    _streamingBlackboardContent += content;
    notifyListeners();
  }
  
  // 清空流式黑板内容
  void clearStreamingBlackboardContent() {
    _streamingBlackboardContent = '';
    notifyListeners();
  }
  
  // 做题册内容
  String _streamingWorkbookContent = '';
  String get streamingWorkbookContent => _streamingWorkbookContent;
  
  void appendToWorkbookContent(String content) {
    _streamingWorkbookContent += content + '\n';
    notifyListeners();
  }
  
  void clearWorkbookContent() {
    _streamingWorkbookContent = '';
    notifyListeners();
  }
  
  // 笔记本内容
  String _streamingNotebookContent = '';
  String get streamingNotebookContent => _streamingNotebookContent;
  
  void appendToNotebookContent(String content) {
    _streamingNotebookContent += content + '\n';
    notifyListeners();
  }
  
  void clearNotebookContent() {
    _streamingNotebookContent = '';
    notifyListeners();
  }
  
  // 清空所有流式内容
  void clearAllStreamingContent() {
    _streamingBlackboardContent = '';
    _streamingWorkbookContent = '';
    _streamingNotebookContent = '';
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
  landing,        // 首页（默认）
  blackboard,     // 黑板
  workbook,       // 作业本  
  notebook,       // 笔记本
  dialog,         // 对话框
  blackboardChat, // 黑板+聊天模式
}
