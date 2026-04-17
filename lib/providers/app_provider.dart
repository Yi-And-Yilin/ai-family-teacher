import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../services/database_service.dart';
import '../services/api_config.dart';
import '../services/ai_service.dart';
import '../models/conversation.dart';
import '../prompts/question_generator_prompt.dart';
import '../prompts/answer_explainer_prompt.dart';
import '../i18n/translations.dart';

class AppProvider with ChangeNotifier {
  // AI 服务引用（用于同步语言设置）
  AIService? _aiService;
  void setAIService(AIService service) {
    _aiService = service;
    _aiService?.setLanguage(_language);
  }

  // 当前显示的组件类型
  ComponentType _currentComponent = ComponentType.chat;
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

  List<Color> get currentAvatarGradient =>
      avatarGradients[_avatarGradientIndex];

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

  String? _progressMessage;
  String? get progressMessage => _progressMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  int _streamCharCount = 0;
  int get streamCharCount => _streamCharCount;

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
    await _saveComponentState();

    final newConversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'default_user',
      title: '新对话',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _databaseService.insertConversation(newConversation);
    } catch (e) {
      print('[DEBUG] createNewConversation: insertConversation failed: $e');
      _errorMessage = '创建对话失败';
      notifyListeners();
      return;
    }
    _currentConversationId = newConversation.id;
    _messages = [];
    _activeComponentType = ActiveComponentType.none;
    _streamingWorkbookContent = '';
    _streamingBlackboardContent = '';
    _streamingNotebookContent = '';
    _conversations.insert(0, newConversation);
    notifyListeners();
  }

  // 切换到指定对话
  Future<void> switchConversation(String conversationId) async {
    print(
        '[DEBUG] switchConversation START: conversationId=$conversationId, currentId=$_currentConversationId');
    if (_currentConversationId == conversationId) {
      print('[DEBUG] switchConversation END (same id): returning early');
      return;
    }

    print('[DEBUG] switchConversation: calling _saveComponentState');
    await _saveComponentState();
    _currentConversationId = conversationId;
    print('[DEBUG] switchConversation: calling loadMessages');
    try {
      await loadMessages();
    } catch (e) {
      print('[DEBUG] switchConversation: loadMessages failed: $e');
      _messages = [];
      _errorMessage = '加载消息失败';
      notifyListeners();
      return;
    }
    print('[DEBUG] switchConversation: calling _restoreComponentState');
    await _restoreComponentState(conversationId);
    print('[DEBUG] switchConversation: calling notifyListeners');
    notifyListeners();
    print('[DEBUG] switchConversation END');
  }

  // 删除对话
  Future<void> deleteConversation(String conversationId) async {
    print('[DEBUG] deleteConversation START: conversationId=$conversationId');
    try {
      await _databaseService.deleteConversation(conversationId);
      print('[DEBUG] deleteConversation: deleted conversation');
    } catch (e) {
      print('[DEBUG] deleteConversation: deleteConversation failed: $e');
    }
    try {
      await _databaseService.deleteConversationComponentState(conversationId);
      print('[DEBUG] deleteConversation: deleted component state');
    } catch (e) {
      print(
          '[DEBUG] deleteConversation: deleteConversationComponentState failed: $e');
    }
    _conversations.removeWhere((c) => c.id == conversationId);

    // 如果删除的是当前对话，创建新对话
    if (_currentConversationId == conversationId) {
      print(
          '[DEBUG] deleteConversation: deleted current conversation, creating new');
      await createNewConversation();
    }
    notifyListeners();
    print('[DEBUG] deleteConversation END');
  }

  /// 清空所有数据（用于测试）
  Future<void> clearAllData() async {
    print('[DEBUG] clearAllData START');
    await _databaseService.clearAllData();
    _messages = [];
    _activeComponentType = ActiveComponentType.none;
    _streamingWorkbookContent = '';
    _streamingBlackboardContent = '';
    _streamingNotebookContent = '';
    _conversations = [];
    _currentConversationId = 'default_conv';
    notifyListeners();
    print('[DEBUG] clearAllData END');
  }

  void setProcessing(bool processing) {
    _isProcessing = processing;
    if (!processing) {
      // 处理完成时清除进度消息
      _progressMessage = null;
      _streamCharCount = 0;
    }
    notifyListeners();
  }

  void updateProgress(String? message, {int? charCount}) {
    _progressMessage = message;
    if (charCount != null) {
      _streamCharCount = charCount;
    }
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

  Future<void> updateLastAIMessage(String content,
      {String? thinking,
      List<Map<String, dynamic>>? toolCalls,
      List<Map<String, dynamic>>? toolCallEvents}) async {
    if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
      print('[APP_PROVIDER] 📝 更新最后一条AI消息:');
      print('  - content长度: ${content.length}');
      print('  - thinking长度: ${thinking?.length ?? 0}');
      print('  - toolCalls数量: ${toolCalls?.length ?? 0}');
      print('  - toolCallEvents数量: ${toolCallEvents?.length ?? 0}');

      final last = _messages.last;
      _messages[_messages.length - 1] = Message(
        id: last.id,
        conversationId: last.conversationId,
        role: last.role,
        content: content,
        thinking: thinking ?? last.thinking,
        toolCalls: toolCalls ?? last.toolCalls,
        toolCallEvents: toolCallEvents ?? last.toolCallEvents,
        timestamp: last.timestamp,
      );

      print(
          '[APP_PROVIDER] ✓ 消息已更新，toolCallEvents: ${_messages.last.toolCallEvents?.length ?? 0}');
      notifyListeners();
      print('[APP_PROVIDER] 🔔 已通知监听器重建UI');
    } else {
      print('[APP_PROVIDER] ⚠️ 无法更新消息: messages.isEmpty 或最后一条消息不是assistant');
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

  // 设置黑板内嵌模式
  bool _showBlackboardInline = false;
  bool get showBlackboardInline => _showBlackboardInline;

  void setBlackboardInlineMode(bool enabled) {
    _showBlackboardInline = enabled;
    notifyListeners();
  }

// 加载历史对话（用于查看已保存的内容）
  Future<void> loadHistoricalConversation(String conversationId) async {
    print(
        '[DEBUG] loadHistoricalConversation START: conversationId=$conversationId, currentId=$_currentConversationId');
    if (_currentConversationId == conversationId) {
      print('[DEBUG] loadHistoricalConversation: same id, setting chat mode');
      _currentComponent = ComponentType.chat;
      notifyListeners();
      print('[DEBUG] loadHistoricalConversation END (early return)');
      return;
    }

    print('[DEBUG] loadHistoricalConversation: setting new conversationId');
    _currentConversationId = conversationId;

    try {
      print('[DEBUG] loadHistoricalConversation: calling getMessages');
      _messages = await _databaseService.getMessages(conversationId);
      print(
          '[DEBUG] loadHistoricalConversation: messages loaded: ${_messages.length}');
    } catch (e) {
      print('[DEBUG] loadHistoricalConversation: getMessages failed: $e');
      _messages = [];
      _errorMessage = '加载历史对话失败';
      notifyListeners();
      return;
    }

    _currentComponent = ComponentType.chat;
    print('[DEBUG] loadHistoricalConversation: calling _restoreComponentState');
    await _restoreComponentState(conversationId);
    print('[DEBUG] loadHistoricalConversation: calling notifyListeners');
    notifyListeners();
    print('[DEBUG] loadHistoricalConversation END');
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
  bool _autoSpeak = false;
  bool get autoSpeak => _autoSpeak;
  void setAutoSpeak(bool value) {
    _autoSpeak = value;
    notifyListeners();
  }

  // 语言设置（支持任意语言代码，如 'zh', 'en', 'es'）
  String _language = 'zh';
  String get language => _language;

  /// 设置语言并持久化到 SQLite
  Future<void> setLanguage(String lang) async {
    // 验证语言代码格式（简单的字母代码，如 'zh', 'en', 'es'）
    if (lang.isEmpty || lang.contains(RegExp(r'[^a-zA-Z]'))) {
      debugPrint('[AppProvider] Invalid language code: $lang');
      return;
    }
    _language = lang;
    await _databaseService.setConfig('app_language', lang);
    await _aiService?.setLanguage(lang); // 异步同步到 AIService
    await Translations().setLanguage(lang); // 同步到翻译系统
    notifyListeners();
  }

  /// 从 SQLite 加载语言设置（并同步到 Translations 和 AIService）
  Future<void> loadLanguage() async {
    final lang = await _databaseService.getConfig('app_language');
    if (lang != null) {
      _language = lang;
      // 同步到翻译系统
      await Translations().setLanguage(lang);
      // 同步到 AI 服务
      await _aiService?.setLanguage(lang);
      notifyListeners();
    }
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
    print(
        '[E2E-DEBUG] AppProvider.appendToBlackboardContent("${content.length > 50 ? content.substring(0, 50) + "..." : content}")');
    _streamingBlackboardContent += content;
    notifyListeners();
    _saveComponentState();
  }

  // 清空流式黑板内容
  void clearStreamingBlackboardContent() {
    print('[E2E-DEBUG] AppProvider.clearStreamingBlackboardContent()');
    _streamingBlackboardContent = '';
    notifyListeners();
    _saveComponentState();
  }

  // 做题册内容
  String _streamingWorkbookContent = '';
  String get streamingWorkbookContent => _streamingWorkbookContent;

  void appendToWorkbookContent(String content) {
    print(
        '[E2E-DEBUG] AppProvider.appendToWorkbookContent("${content.length > 50 ? content.substring(0, 50) + "..." : content}")');
    _streamingWorkbookContent += content + '\n';
    notifyListeners();
    _saveComponentState();
  }

  void clearWorkbookContent() {
    print('[E2E-DEBUG] AppProvider.clearWorkbookContent()');
    _streamingWorkbookContent = '';
    notifyListeners();
    _saveComponentState();
  }

  // 笔记本内容
  String _streamingNotebookContent = '';
  String get streamingNotebookContent => _streamingNotebookContent;

  void appendToNotebookContent(String content) {
    print(
        '[E2E-DEBUG] AppProvider.appendToNotebookContent("${content.length > 50 ? content.substring(0, 50) + "..." : content}")');
    _streamingNotebookContent += content + '\n';
    notifyListeners();
    _saveComponentState();
  }

  void clearNotebookContent() {
    print('[E2E-DEBUG] AppProvider.clearNotebookContent()');
    _streamingNotebookContent = '';
    notifyListeners();
    _saveComponentState();
  }

  // 清空所有流式内容
  void clearAllStreamingContent() {
    _streamingBlackboardContent = '';
    _streamingWorkbookContent = '';
    _streamingNotebookContent = '';
    _activeComponentType = ActiveComponentType.none;
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

  // 当前活跃的组件类型（用于 split view 布局）
  ActiveComponentType _activeComponentType = ActiveComponentType.none;
  ActiveComponentType get activeComponentType => _activeComponentType;

  void setActiveComponentType(ActiveComponentType type) {
    print('[E2E-DEBUG] AppProvider.setActiveComponentType($type)');
    _activeComponentType = type;
    notifyListeners();
    _saveComponentState();
  }

  void clearActiveComponentType() {
    print('[E2E-DEBUG] AppProvider.clearActiveComponentType()');
    _activeComponentType = ActiveComponentType.none;
    notifyListeners();
    _saveComponentState();
  }

  Future<void> _saveComponentState() async {
    if (_currentConversationId == null) return;
    try {
      await _databaseService.saveConversationComponentState(
        conversationId: _currentConversationId!,
        activeComponent: _activeComponentType.name,
        workbookContent: _streamingWorkbookContent,
        blackboardContent: _streamingBlackboardContent,
        notebookContent: _streamingNotebookContent,
      );
    } catch (e) {
      print('[E2E-DEBUG] _saveComponentState failed: $e');
    }
  }

  Future<void> _restoreComponentState(String conversationId) async {
    print(
        '[DEBUG] _restoreComponentState START: conversationId=$conversationId');
    try {
      print(
          '[DEBUG] _restoreComponentState: calling getConversationComponentState');
      final state =
          await _databaseService.getConversationComponentState(conversationId);
      print('[DEBUG] _restoreComponentState: state=$state');
      if (state == null) {
        print('[DEBUG] _restoreComponentState: state is null, resetting all');
        _activeComponentType = ActiveComponentType.none;
        _streamingWorkbookContent = '';
        _streamingBlackboardContent = '';
        _streamingNotebookContent = '';
        notifyListeners();
        print('[DEBUG] _restoreComponentState END (null state)');
        return;
      }

      final activeComponentStr = state['active_component'] as String?;
      print(
          '[DEBUG] _restoreComponentState: activeComponentStr=$activeComponentStr');
      if (activeComponentStr != null && activeComponentStr != 'none') {
        _activeComponentType = ActiveComponentType.values.firstWhere(
          (e) => e.name == activeComponentStr,
          orElse: () => ActiveComponentType.none,
        );
      } else {
        _activeComponentType = ActiveComponentType.none;
      }
      print(
          '[DEBUG] _restoreComponentState: _activeComponentType=$_activeComponentType');

      _streamingWorkbookContent = state['workbook_content'] as String? ?? '';
      _streamingBlackboardContent =
          state['blackboard_content'] as String? ?? '';
      _streamingNotebookContent = state['notebook_content'] as String? ?? '';
      print(
          '[DEBUG] _restoreComponentState: workbook="${_streamingWorkbookContent.length}" chars');
      notifyListeners();
      print('[DEBUG] _restoreComponentState END');
    } catch (e) {
      print('[DEBUG] _restoreComponentState EXCEPTION: $e');
      print('[E2E-DEBUG] _restoreComponentState failed: $e');
      // 即使数据库失败，也重置状态
      _activeComponentType = ActiveComponentType.none;
      _streamingWorkbookContent = '';
      _streamingBlackboardContent = '';
      _streamingNotebookContent = '';
      notifyListeners();
    }
  }
}

enum ActiveComponentType {
  none,
  blackboard,
  workbook,
  notebook,
}

enum ComponentType {
  landing, // 首页（默认）
  chat, // 主聊天页面（包含内嵌的blackboard/workbook/notebook）
  savedBlackboards, // 已保存的黑板列表
  savedWorkbooks, // 已保存的作业本列表
  savedNotebooks, // 已保存的笔记本列表
  settings, // 设置页面
}
