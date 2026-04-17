import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:convert';
import 'dart:typed_data';

import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../i18n/translations.dart';
import '../models/conversation.dart';
import '../services/voice_service.dart';
import '../theme/ios_theme.dart';

class DialogArea extends StatefulWidget {
  final bool fullScreen;
  final bool showHeader;
  const DialogArea(
      {super.key, this.fullScreen = false, this.showHeader = true});

  @override
  State<DialogArea> createState() => _DialogAreaState();
}

class _DialogAreaState extends State<DialogArea> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AIService? _aiService;
  final VoiceService _voiceService = VoiceService();
  final _uuid = const Uuid();
  bool _isListening = false;
  bool _isCancelled = false;
  List<Uint8List> _selectedImageBytes = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aiService != null) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    _aiService = AIService(
      config: appProvider.apiConfig,
      onBlackboardUpdate: (content) {
        // 不再自动切换页面，只在聊天中显示
        appProvider.updateBlackboard([
          {
            'type': 'text',
            'content': content,
            'position': {'x': 50, 'y': 50},
            'style': {'fontSize': 24, 'color': '#FFFFFF'}
          }
        ]);
        // 保持当前组件不变，不切换到blackboard
      },
      onWorkbookMark: (marks) {
        // 不再自动切换页面，只在聊天中显示
        appProvider.updateWorkbookMarks(marks);
        // 保持当前组件不变，不切换到workbook
      },
      onBlackboardClear: () {
        appProvider.updateBlackboard([]);
      },
      onRequireConfirmation: (title, message) async {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(Translations().t('dialog_cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(Translations().t('dialog_agree')),
              ),
            ],
          ),
        );
        return result ?? false;
      },
    );
    // 注册 AIService 到 AppProvider，用于语言同步
    appProvider.setAIService(_aiService!);
    // 同步初始语言
    _aiService!.setLanguage(appProvider.language);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _selectedImageBytes.addAll(result.files.map((f) => f.bytes!).toList());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final messages = appProvider.messages;

    if (widget.fullScreen) {
      return _buildFullScreenView(appProvider, messages);
    }
    return _buildBottomSheetView(appProvider, messages);
  }

  Widget _buildFullScreenView(AppProvider appProvider, List<Message> messages) {
    return Container(
      color: iOSTheme.white,
      child: Column(
        children: [
          if (widget.showHeader) _buildHeader(appProvider),
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(appProvider)
                : _buildMessageList(messages, appProvider),
          ),
          _buildInputArea(appProvider),
        ],
      ),
    );
  }

  Widget _buildBottomSheetView(
      AppProvider appProvider, List<Message> messages) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyStateCompact(appProvider)
                : _buildMessageList(messages, appProvider),
          ),
          _buildInputAreaCompact(appProvider),
        ],
      ),
    );
  }

  Widget _buildHeader(AppProvider appProvider) {
    return iOSTheme.frostedGlass(
      blur: 10.0,
      opacity: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: iOSTheme.systemGray5.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧：汉堡菜单按钮（作为普通 Row 元素，无外框）
              GestureDetector(
                onTap: () => _showHamburgerMenu(appProvider),
                child: Icon(
                  Icons.menu_rounded,
                  color: iOSTheme.blue,
                  size: 26,
                ),
              ),

              // 中间：标题
              Expanded(
                child: Text(
                  '与小书童对话',
                  style: TextStyle(
                    fontSize: iOSTheme.title1,
                    fontWeight: FontWeight.w600,
                    color: iOSTheme.label,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 右侧：历史对话、新对话、头像
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 历史对话按钮（作为普通 Row 元素，无外框）
                  GestureDetector(
                    onTap: () => _showConversationHistory(appProvider),
                    child: Icon(
                      Icons.history_rounded,
                      color: iOSTheme.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 新对话按钮（作为普通 Row 元素，无外框）
                  GestureDetector(
                    onTap: () => _createNewConversation(appProvider),
                    child: Icon(
                      Icons.add_rounded,
                      color: iOSTheme.blue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 头像
                  _buildAvatar(appProvider, 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示汉堡菜单（侧滑抽屉）
  void _showHamburgerMenu(AppProvider appProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _HamburgerMenuSheet(appProvider: appProvider),
    );
  }

  void _showConversationHistory(AppProvider appProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ConversationHistorySheet(appProvider: appProvider),
    );
  }

  Future<void> _createNewConversation(AppProvider appProvider) async {
    // 清空输入框
    _textController.clear();
    // 清空选中的图片
    setState(() => _selectedImageBytes = []);
    // 创建新对话
    await appProvider.createNewConversation();
  }

  Widget _buildEmptyState(AppProvider appProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 程序 Logo - 使用 auto_awesome 图标配合温暖色调
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF9A56), Color(0xFFFF6B8B)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B8B).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '👋 嗨，${appProvider.studentName}！',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: iOSTheme.label,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '今天想学点什么新东西呀？',
            style: TextStyle(
              fontSize: iOSTheme.subhead,
              color: iOSTheme.secondaryLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),
          _buildQuickPrompts(appProvider),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCompact(AppProvider appProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(Translations().t('dialog_start_chat'),
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(AppProvider appProvider) {
    // 每个快捷按钮使用不同的温暖背景色，保持整体风格协调
    final prompts = [
      {
        'icon': Icons.help_outline_rounded,
        'text': '帮我解释一个概念',
        'emoji': '💡',
        'bgColor': const Color(0xFFFFF3E0), // 温暖橙色背景
      },
      {
        'icon': Icons.edit_note_rounded,
        'text': '出一些练习题',
        'emoji': '✏️',
        'bgColor': const Color(0xFFE8F5E9), // 清新绿色背景
      },
      {
        'icon': Icons.lightbulb_outline_rounded,
        'text': '给我学习小建议',
        'emoji': '🌟',
        'bgColor': const Color(0xFFF3E5F5), // 柔和紫色背景
      },
    ];

    return Column(
      children: prompts.map((p) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _textController.text = p['text'] as String;
                _sendMessage(appProvider);
              },
              borderRadius: BorderRadius.circular(iOSTheme.radiusLarge),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: p['bgColor'] as Color,
                  borderRadius: BorderRadius.circular(iOSTheme.radiusLarge),
                ),
                child: Row(
                  children: [
                    Text(p['emoji'] as String,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(
                      p['text'] as String,
                      style: TextStyle(
                        fontSize: iOSTheme.subhead,
                        color: iOSTheme.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageList(List<Message> messages, AppProvider appProvider) {
    return ListView.builder(
      controller: _scrollController,
      physics: iOSTheme.bouncingScroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _buildMessageBubble(messages[index], appProvider),
    );
  }

  Widget _buildMessageBubble(Message message, AppProvider appProvider) {
    final isUser = message.role == MessageRole.user;
    final isTool = message.role == MessageRole.tool;

    if (isTool) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iOSTheme.systemGray6,
              borderRadius: BorderRadius.circular(iOSTheme.radiusMedium),
            ),
            child: Text(
              message.content,
              style: TextStyle(fontSize: 12, color: iOSTheme.tertiaryLabel),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iOSTheme.blue, Color(0xFF5856D6)],
                ),
                boxShadow: iOSTheme.subtleShadow,
              ),
              child:
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? iOSTheme.blue : const Color(0xFFE8E0F0),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(iOSTheme.radiusLarge),
                  topRight: const Radius.circular(iOSTheme.radiusLarge),
                  bottomLeft:
                      Radius.circular(isUser ? iOSTheme.radiusLarge : 4),
                  bottomRight:
                      Radius.circular(isUser ? 4 : iOSTheme.radiusLarge),
                ),
                boxShadow: iOSTheme.bubbleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.images != null) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: message.images!.map((img) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(base64Decode(img),
                              width: 80, height: 80, fit: BoxFit.cover),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 解析消息内容，将 [TOOL_CALL_EVENT:n] 标记替换为实际的组件
                  ..._buildMessageContent(message, isUser, appProvider),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(appProvider, 32),
          ],
        ],
      ),
    );
  }

  /// 构建消息内容，解析 [TOOL_CALL_EVENT:n] 标记并替换为组件
  List<Widget> _buildMessageContent(
      Message message, bool isUser, AppProvider appProvider) {
    final content = message.content;
    if (content.isEmpty) return [];

    // 如果是用户消息，直接显示文本
    if (isUser) {
      return [
        Text(
          content,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white,
            height: 1.4,
          ),
        ),
      ];
    }

    // 解析 AI 消息，将 [TOOL_CALL_EVENT:n] 替换为组件
    final widgets = <Widget>[];
    final pattern = RegExp(r'\n\n\[TOOL_CALL_EVENT:(\d+)\]\n\n');
    final matches = pattern.allMatches(content).toList();

    if (matches.isEmpty) {
      // 没有工具事件标记，直接渲染 Markdown
      widgets.add(_buildMarkdownBody(content));
      return widgets;
    }

    int lastIndex = 0;
    for (final match in matches) {
      // 添加标记前的文本内容
      if (match.start > lastIndex) {
        final textBefore = content.substring(lastIndex, match.start);
        if (textBefore.trim().isNotEmpty) {
          widgets.add(_buildMarkdownBody(textBefore));
        }
      }

      // 添加工具事件组件（分组后）
      final toolIndex = int.parse(match.group(1)!);
      if (message.toolCallEvents != null &&
          toolIndex < message.toolCallEvents!.length) {
        final event = message.toolCallEvents![toolIndex];
        // 只处理有工具名的事件（过滤掉"正在处理..."这类无工具名事件）
        final toolName = event['tool_name'] as String? ?? '';
        if (toolName.isNotEmpty) {
          // 检查是否是这个工具的第一个事件
          final isFirstEvent = _isFirstEventForTool(
              message.toolCallEvents!, toolName, toolIndex);
          if (isFirstEvent) {
            // 获取该工具的所有事件并分组
            final groupedEvents =
                _getEventsForTool(message.toolCallEvents!, toolName);
            widgets
                .add(_buildGroupedToolCallIndicator(toolName, groupedEvents));

            // 如果工具调用已完成，添加内联组件
            final isDone = groupedEvents
                .any((e) => (e['state'] as String? ?? '') == 'done');
            if (isDone) {
              // 关键调试：检查groupedEvents中的result
              for (var i = 0; i < groupedEvents.length; i++) {
                final ge = groupedEvents[i];
                final geResult = ge['result'] as Map<String, dynamic>?;
                print(
                    '[DIALOG_AREA] 🔍 [groupedEvents][$i] state=${ge['state']}, hasResult=${geResult != null}, success=${geResult?['success']}');
              }

              final inlineWidget = _buildInlineToolComponent(
                  toolName, groupedEvents, appProvider);
              if (inlineWidget != null) {
                widgets.add(inlineWidget);
              }
            }
          }
        }
      }

      lastIndex = match.end;
    }

    // 添加最后一段文本
    if (lastIndex < content.length) {
      final remainingText = content.substring(lastIndex);
      if (remainingText.trim().isNotEmpty) {
        widgets.add(_buildMarkdownBody(remainingText));
      }
    }

    return widgets;
  }

  /// 检查是否是某个工具的第一个事件
  bool _isFirstEventForTool(
      List<Map<String, dynamic>> events, String toolName, int currentIndex) {
    for (int i = 0; i < currentIndex; i++) {
      if ((events[i]['tool_name'] as String? ?? '') == toolName) {
        return false;
      }
    }
    return true;
  }

  /// 获取某个工具的所有事件
  List<Map<String, dynamic>> _getEventsForTool(
      List<Map<String, dynamic>> events, String toolName) {
    return events
        .where((e) => (e['tool_name'] as String? ?? '') == toolName)
        .toList();
  }

  /// 构建分组后的工具调用指标（多个步骤合并为一个可折叠行）
  List<Widget> _buildGroupedToolCallIndicators(
      List<Map<String, dynamic>> events) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final toolName = event['tool_name'] as String? ?? '';
      if (toolName.isEmpty) continue; // 跳过无工具名的事件
      grouped.putIfAbsent(toolName, () => []).add(event);
    }

    return grouped.entries
        .map((e) => _buildGroupedToolCallIndicator(e.key, e.value))
        .toList();
  }

  /// 构建单个分组后的工具调用指标
  Widget _buildGroupedToolCallIndicator(
      String toolName, List<Map<String, dynamic>> events) {
    // 收集所有步骤的参数和结果
    final allArguments = <Map<String, dynamic>>[];
    final allResults = <Map<String, dynamic>>[];
    bool hasDone = false;
    bool isProcessing = false;

    for (final event in events) {
      final state = event['state'] as String? ?? '';
      if (state == 'done') hasDone = true;
      if (event['arguments'] != null)
        allArguments.add(event['arguments'] as Map<String, dynamic>);
      if (event['result'] != null)
        allResults.add(event['result'] as Map<String, dynamic>);
    }

    // 修复：只有当工具还没完成时才显示loading
    // 只要有任意一个事件state是'done'，就认为已完成，不显示loading
    isProcessing = !hasDone;

    return ExpansionTile(
      leading: Text(
        _getToolCategoryIcon(toolName),
        style: const TextStyle(fontSize: 16),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getToolDescription(toolName),
            style: const TextStyle(fontSize: 13),
          ),
          if (isProcessing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ],
      ),
      trailing: Icon(
        Icons.expand_more,
        size: 18,
        color: hasDone ? Colors.green : Colors.grey,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allArguments.isNotEmpty) ...[
                const Text(
                  '参数:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey),
                ),
                const SizedBox(height: 2),
                ...allArguments.map((args) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        _formatJson(args),
                        style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.grey),
                      ),
                    )),
                const SizedBox(height: 6),
              ],
              if (allResults.isNotEmpty) ...[
                const Text(
                  '结果:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey),
                ),
                const SizedBox(height: 2),
                ...allResults.map((result) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        _formatJson(result),
                        style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.grey),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 构建内联工具组件（工具调用完成后显示实际内容）
  /// 当有活跃组件时（在分屏视图中显示），返回 null 不显示内联版本
  Widget? _buildInlineToolComponent(String toolName,
      List<Map<String, dynamic>> events, AppProvider appProvider) {
    // 如果已经有活跃的组件类型（workbook/blackboard/notebook），
    // 说明分屏视图正在显示，不再显示内联版本
    if (appProvider.activeComponentType != ActiveComponentType.none) {
      return null;
    }

    // 检查工具调用是否成功
    final hasSuccess = events.any((e) {
      final result = e['result'] as Map<String, dynamic>?;
      return result != null && result['success'] == true;
    });

    if (!hasSuccess) return null;

    // 根据工具类型返回对应的内联组件
    switch (toolName) {
      case 'create_workbook':
        final workbookContent = appProvider.streamingWorkbookContent;
        if (workbookContent.isEmpty) return null;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    '作业本已创建',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                workbookContent,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        );

      case 'create_notebook':
      case 'append_to_notebook':
        final notebookContent = appProvider.streamingNotebookContent;
        if (notebookContent.isEmpty) return null;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    '笔记本已更新',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notebookContent,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        );

      default:
        return null;
    }
  }

  /// 构建 Markdown 内容
  Widget _buildMarkdownBody(String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          // 可以在这里打开链接
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
        h1: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        h2: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        h3: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        code: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          backgroundColor: Colors.grey[200],
          color: Colors.purple[700],
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border:
              Border(left: BorderSide(color: Colors.purple[300]!, width: 4)),
        ),
        listBullet: TextStyle(color: Colors.purple[400]),
        tableHead:
            TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
        tableBody: TextStyle(color: Colors.grey[700]),
        em: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[800]),
        strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
      ),
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
  }

  /// 获取工具类别对应的图标（workbook 和 question 用不同图标）
  String _getToolCategoryIcon(String toolName) {
    // workbook 相关工具用📚
    if (toolName.contains('workbook')) return '📚';
    // question 相关工具用✏️
    if (toolName.contains('question')) return '✏️';
    // 其他工具用⚙️
    return '⚙️';
  }

  /// 获取工具类别名称（用于分组）
  String _getToolCategory(String toolName) {
    if (toolName.contains('workbook')) return 'workbook';
    if (toolName.contains('question')) return 'question';
    return toolName;
  }

  /// 根据工具 schema 获取描述文字（作为折叠标题）
  String _getToolDescription(String toolName) {
    // 从工具 schema 中获取 description
    switch (toolName) {
      case 'create_workbook':
        return '创建新的作业本';
      case 'get_workbooks':
        return '获取作业本列表';
      case 'get_workbook':
        return '获取作业本详情';
      case 'create_question':
        return '创建新题目';
      case 'get_questions':
        return '获取题目列表';
      case 'get_question':
        return '获取题目详情';
      case 'update_question':
        return '更新题目';
      case 'delete_question':
        return '删除题目';
      case 'get_user_answer':
        return '获取用户答案';
      case 'get_all_user_answers':
        return '获取所有用户答案';
      case 'grade_answer':
        return '批改答案';
      case 'grade_answers':
        return '批量批改答案';
      case 'grade_workbook':
        return '批改作业本';
      case 'explain_solution':
        return '生成讲解';
      case 'upload_user_answer':
        return '上传用户答案';
      default:
        return toolName;
    }
  }

  /// 构建可折叠的工具调用指标（简化版：只有类别图标 + 折叠指示）
  Widget _buildToolCallIndicator(Map<String, dynamic> event) {
    final toolName = event['tool_name'] as String? ?? '';
    final arguments = event['arguments'] as Map<String, dynamic>?;
    final result = event['result'] as Map<String, dynamic>?;

    return ExpansionTile(
      leading: Text(
        _getToolCategoryIcon(toolName),
        style: const TextStyle(fontSize: 16),
      ),
      title: Text(
        _getToolDescription(toolName),
        style: const TextStyle(fontSize: 13),
      ),
      trailing: const Icon(Icons.expand_more, size: 18, color: Colors.grey),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (arguments != null && arguments.isNotEmpty) ...[
                const Text(
                  '参数:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    _formatJson(arguments),
                    style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (result != null && result.isNotEmpty) ...[
                const Text(
                  '结果:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    _formatJson(result),
                    style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 格式化 JSON 为可读字符串
  String _formatJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  Widget _buildAvatar(AppProvider appProvider, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.purple.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          'https://api.dicebear.com/7.x/lorelei/png?seed=${Uri.encodeComponent(appProvider.studentName)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.pink[100],
            child: Icon(Icons.face, size: size * 0.5, color: Colors.pink[300]),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(AppProvider appProvider) {
    return iOSTheme.frostedGlass(
      blur: 10.0,
      opacity: 0.9,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: iOSTheme.systemGray5.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            if (_selectedImageBytes.isNotEmpty) _buildImagePreview(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧工具按钮（同一行）
                _buildIOSSquareBtn(
                    Icons.add_photo_alternate_rounded, _pickFiles),
                const SizedBox(width: 6),
                _buildIOSSquareBtn(
                  _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                  () => _toggleVoiceInput(appProvider),
                  isActive: _isListening,
                ),
                const SizedBox(width: 6),
                _buildIOSSquareBtn(
                  appProvider.autoSpeak
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  () {
                    if (appProvider.autoSpeak) {
                      _voiceService.stopSpeaking();
                    }
                    appProvider.setAutoSpeak(!appProvider.autoSpeak);
                  },
                  isActive: appProvider.autoSpeak,
                ),
                const SizedBox(width: 10),

                // 输入框（圆角矩形）
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: iOSTheme.systemGray6,
                      borderRadius: BorderRadius.circular(iOSTheme.radiusLarge),
                      border: Border.all(
                        color: iOSTheme.systemGray5.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: '说说你的想法...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: iOSTheme.tertiaryLabel,
                          fontSize: iOSTheme.subhead,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: iOSTheme.subhead,
                        color: iOSTheme.label,
                      ),
                      onSubmitted: (_) => _sendMessage(appProvider),
                      enabled: !appProvider.isProcessing,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 发送按钮（iOS 风格）
                GestureDetector(
                  onTap: appProvider.isProcessing
                      ? null
                      : () => _sendMessage(appProvider),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: appProvider.isProcessing
                          ? iOSTheme.systemGray5
                          : iOSTheme.blue,
                      shape: BoxShape.circle,
                      boxShadow:
                          appProvider.isProcessing ? [] : iOSTheme.subtleShadow,
                    ),
                    child: Icon(
                      appProvider.isProcessing
                          ? Icons.hourglass_top_rounded
                          : Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// iOS 风格方形按钮（用于输入区左侧）
  Widget _buildIOSSquareBtn(IconData icon, VoidCallback onTap,
      {bool isActive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(iOSTheme.radiusSmall),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                isActive ? iOSTheme.blue.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(iOSTheme.radiusSmall),
          ),
          child: Icon(
            icon,
            color: isActive ? iOSTheme.blue : iOSTheme.secondaryLabel,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildInputAreaCompact(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildCircleBtn(Icons.add_photo_alternate_outlined, _pickFiles,
              size: 36),
          const SizedBox(width: 8),
          _buildCircleBtn(_isListening ? Icons.mic : Icons.mic_none_outlined,
              () => _toggleVoiceInput(appProvider),
              isActive: _isListening, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                    hintText: '输入问题...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10)),
                onSubmitted: (_) => _sendMessage(appProvider),
                enabled: !appProvider.isProcessing,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: appProvider.isProcessing
                ? null
                : () => _sendMessage(appProvider),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: appProvider.isProcessing
                        ? [Colors.grey, Colors.grey]
                        : [const Color(0xFF7C4DFF), const Color(0xFFE040FB)]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  appProvider.isProcessing
                      ? Icons.hourglass_top
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImageBytes.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_selectedImageBytes[index],
                      height: 60, width: 60, fit: BoxFit.cover),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedImageBytes.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap,
      {bool isActive = false, double size = 44}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? Colors.red[50] : const Color(0xFFF5F5F7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: isActive ? Colors.red : Colors.grey[600], size: size * 0.5),
      ),
    );
  }

  void _toggleVoiceInput(AppProvider appProvider) {
    if (_isListening) {
      _voiceService.stopListening();
    } else {
      _voiceService.startListening(
        onResult: (text) {
          // 只设置文本到输入框，不自动发送，让用户有机会编辑
          setState(() {
            _textController.text = text;
          });
        },
        onStatusChanged: (listening) =>
            setState(() => _isListening = listening),
      );
    }
  }

  void _sendMessage(AppProvider appProvider) async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImageBytes.isEmpty) return;
    if (appProvider.isProcessing) return;

    _textController.clear();
    _voiceService.stopSpeaking();
    setState(() => _isCancelled = false);

    final List<String> imagesBase64 =
        _selectedImageBytes.map((b) => base64Encode(b)).toList();
    setState(() => _selectedImageBytes = []);

    final userMsg = Message(
      id: _uuid.v4(),
      conversationId: appProvider.currentConversationId,
      role: MessageRole.user,
      content: text,
      images: imagesBase64.isNotEmpty ? imagesBase64 : null,
      timestamp: DateTime.now(),
    );
    await appProvider.addMessage(userMsg);

    // 清空之前的流式内容
    appProvider.clearAllStreamingContent();
    appProvider.clearErrorMessage();

    appProvider.setProcessing(true);

    final aiMsg = Message(
      id: _uuid.v4(),
      conversationId: appProvider.currentConversationId,
      role: MessageRole.assistant,
      content: '...',
      timestamp: DateTime.now(),
    );
    await appProvider.addMessage(aiMsg);

    try {
      String fullContent = '';
      String fullThinking = '';
      final toolCallEvents = <Map<String, dynamic>>[];

      // 节流机制：累积内容，定期更新UI
      DateTime? lastUpdateTime;
      const throttleDuration = Duration(milliseconds: 100); // 每100ms更新一次UI
      const throttleCharCount = 50; // 或每50个字符更新一次UI
      int charsSinceLastUpdate = 0;

      final stream = _aiService!.answerQuestionStream(
        history:
            appProvider.messages.take(appProvider.messages.length - 1).toList(),
        images: imagesBase64.isNotEmpty ? imagesBase64 : null,
      );

      await for (final chunk in stream) {
        if (_isCancelled) break;

        _scrollToBottom();

        // 时间戳日志：记录后端yield时间和前端接收时间，计算延迟
        final frontendTimestamp = DateTime.now();
        if (chunk.backendTimestamp != null) {
          final backendTime = chunk.backendTimestamp!;
          final delayMs =
              frontendTimestamp.difference(backendTime).inMilliseconds;
          final chunkType = chunk.hasToolCallEvent
              ? 'TOOL_CALL'
              : chunk.hasProgressMessage
                  ? 'PROGRESS'
                  : chunk.hasToolResult
                      ? 'TOOL_RESULT'
                      : chunk.hasBlackboardContent
                          ? 'BLACKBOARD'
                          : chunk.hasNotebookContent
                              ? 'NOTEBOOK'
                              : chunk.done
                                  ? 'DONE'
                                  : 'TEXT';
          print(
              '[LATENCY] [$chunkType] backend=${backendTime.toIso8601String()} frontend=${frontendTimestamp.toIso8601String()} delay=${delayMs}ms');
        }

        // 收集 thinking 内容
        if (chunk.thinking != null && chunk.thinking!.isNotEmpty) {
          fullThinking += chunk.thinking!;
        }

        // 处理工具调用事件 - 关键改进：实时插入到内容流中
        if (chunk.hasToolCallEvent) {
          final event = chunk.toolCallEvent!;
          final toolName = event.toolName;

          // 只处理有工具名的事件（过滤掉"正在处理..."这类无工具名事件）
          if (toolName.isNotEmpty) {
            print('[DIALOG_AREA] 🎯 [TOOL_EVENT_RECEIVED] 收到工具事件:');
            print('  - toolName: $toolName');
            print('  - state: ${event.state.name}');

            // 检查是否是这个工具的第一个事件
            final isFirstForThisTool = !toolCallEvents
                .any((e) => (e['tool_name'] as String? ?? '') == toolName);

            toolCallEvents.add({
              'tool_name': toolName,
              'state': event.state.name,
              'progress_text': event.progressText,
              if (event.arguments != null) 'arguments': event.arguments,
              if (event.result != null) 'result': event.result,
            });

            // 只在该工具的第一个事件时插入标记（用于分组显示）
            if (isFirstForThisTool) {
              final toolIndex = toolCallEvents.length - 1;
              fullContent += '\n\n[TOOL_CALL_EVENT:$toolIndex]\n\n';
              print('[DIALOG_AREA] 🔔 已插入工具事件标记，索引: $toolIndex');
            }

            // 实时更新消息（使用节流）
            final now = DateTime.now();
            final shouldUpdate = lastUpdateTime == null ||
                now.difference(lastUpdateTime) >= throttleDuration;

            if (shouldUpdate) {
              await appProvider.updateLastAIMessage(
                fullContent,
                thinking: fullThinking.isNotEmpty ? fullThinking : null,
                toolCallEvents: List.from(toolCallEvents),
              );
              _scrollToBottom();
              lastUpdateTime = now;
              charsSinceLastUpdate = 0;
            }
          }
        }

        // 处理进度消息和字符计数（合并为一个调用）
        if (chunk.hasProgressMessage || chunk.roundCharCount != null) {
          final msg = chunk.progressMessage ?? appProvider.progressMessage;
          appProvider.updateProgress(msg, charCount: chunk.roundCharCount);
          if (chunk.hasProgressMessage) {
            print('[DIALOG_AREA] ✓ 进度: ${chunk.progressMessage}');
          }
        }

        // 处理聊天内容（已经去掉 C> 前缀）
        if (chunk.content != null && chunk.content!.isNotEmpty) {
          fullContent += chunk.content!;
          charsSinceLastUpdate += chunk.content!.length;

          // 检查是否需要更新UI（节流）
          final now = DateTime.now();
          final shouldUpdateByTime = lastUpdateTime == null ||
              now.difference(lastUpdateTime) >= throttleDuration;
          final shouldUpdateByChars = charsSinceLastUpdate >= throttleCharCount;

          if (shouldUpdateByTime || shouldUpdateByChars) {
            await appProvider.updateLastAIMessage(
              fullContent,
              thinking: fullThinking.isNotEmpty ? fullThinking : null,
              toolCallEvents: toolCallEvents.isNotEmpty ? toolCallEvents : null,
            );
            _scrollToBottom();
            lastUpdateTime = now;
            charsSinceLastUpdate = 0;
          }
        }

        // 处理黑板内容（已经去掉 B> 前缀）
        if (chunk.hasBlackboardContent) {
          print('[DIALOG_AREA] ✓ 处理黑板内容: ${chunk.blackboardContent}');
          appProvider.appendToBlackboardContent(chunk.blackboardContent!);
          appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        }

        // 处理笔记本内容（已经去掉 N> 前缀）
        if (chunk.hasNotebookContent) {
          print('[DIALOG_AREA] ✓ 处理笔记本内容: ${chunk.notebookContent}');
          appProvider.appendToNotebookContent(chunk.notebookContent!);
          appProvider.setActiveComponentType(ActiveComponentType.notebook);
        }

        // 处理题目响应（保留兼容旧格式）
        if (chunk.hasQuestionResponse) {
          print('[DIALOG_AREA] ✓ 处理题目响应');
          final qr = chunk.questionResponse!;
          appProvider.setCurrentQuestionData(
            qr.question,
            answer: qr.answer,
          );
          // 保持在聊天中，不再切换到单独的黑板页面
        }

        // 处理工具结果
        if (chunk.hasToolResult) {
          print('[DIALOG_AREA] ✓ 处理工具结果');
          final result = chunk.toolResult!;
          final toolName = result['tool_name'] as String;
          final toolResult = result['result'] as Map<String, dynamic>;

          print('[DIALOG_AREA] 工具: $toolName, 结果: $toolResult');

          // 根据工具类型处理 UI 变化
          if (toolResult.containsKey('ui_action')) {
            final uiAction = toolResult['ui_action'] as String;

            switch (uiAction) {
              case 'show_correct_mark':
                print('[DIALOG_AREA] UI: 显示正确标记');
                break;
              case 'show_wrong_mark':
                print('[DIALOG_AREA] UI: 显示错误标记');
                break;
              case 'show_score':
                final score = toolResult['score'] as double;
                print('[DIALOG_AREA] UI: 显示分数 $score');
                break;
              case 'switch_to_blackboard':
                // 不再切换到单独的blackboard页面
                print('[DIALOG_AREA] UI: 切换到黑板（已废弃，保持在聊天中）');
                break;
            }
          }

          // 处理作业本创建
          if (toolName == 'create_workbook' && toolResult['success'] == true) {
            final workbookId = toolResult['workbook_id'] as String;
            print('[DIALOG_AREA] 创建作业本成功: $workbookId');
            // 不再切换到单独的workbook页面，保持在聊天中
          }

          // 处理题目创建
          if (toolName == 'create_question' && toolResult['success'] == true) {
            print('[DIALOG_AREA] 创建题目成功');
            // 不再切换到单独的workbook页面，保持在聊天中

            // 关键修复：只通过通用 ui_action 处理一次，不要在这里重复追加
            // （删除了此处的 appProvider.appendToWorkbookContent 调用，避免重复）
          }

          // 通用 ui_action 处理
          if (toolResult.containsKey('ui_action')) {
            final uiAction = toolResult['ui_action'] as String;
            print('[DIALOG_AREA] 🎯 [UI_ACTION] ui_action=$uiAction');
            if (uiAction == 'append_to_workbook' &&
                toolResult.containsKey('workbook_content')) {
              final wbContent = toolResult['workbook_content'] as String;
              print('[DIALOG_AREA] 📝 [WORKBOOK] 追加内容: "$wbContent"');
              appProvider.appendToWorkbookContent(wbContent);
              appProvider.setActiveComponentType(ActiveComponentType.workbook);
              print(
                  '[DIALOG_AREA] 📝 [WORKBOOK] 当前streamingWorkbookContent: "${appProvider.streamingWorkbookContent}"');
            }
          }
        }

        // 处理完成
        if (chunk.done) {
          print('[DIALOG_AREA] ========== 流式处理完成 ==========');
          print('[DIALOG_AREA] - content_length: ${fullContent.length}');
          print('[DIALOG_AREA] - thinking_length: ${fullThinking.length}');
          print('[DIALOG_AREA] - toolCallEvents收集数量: ${toolCallEvents.length}');
          if (toolCallEvents.isNotEmpty) {
            print('[DIALOG_AREA] 📋 工具事件列表:');
            for (int i = 0; i < toolCallEvents.length; i++) {
              final event = toolCallEvents[i];
              print('    [$i] ${event['tool_name']} (${event['state']})');
            }
          }

          // 确保最后的内容被更新到 UI，包含工具调用事件
          if (fullContent.isNotEmpty || fullThinking.isNotEmpty) {
            print(
                '[DIALOG_AREA] 📤 调用 updateLastAIMessage，附加 toolCallEvents...');
            await appProvider.updateLastAIMessage(
              fullContent,
              thinking: fullThinking.isNotEmpty ? fullThinking : null,
              toolCallEvents: toolCallEvents.isNotEmpty ? toolCallEvents : null,
            );
            print('[DIALOG_AREA] ✓ updateLastAIMessage 调用完成');
          }
          break;
        }
      }

      if (!_isCancelled) {
        if (appProvider.autoSpeak) {
          _voiceService.speak(fullContent);
        }
        await appProvider.finalizeLastMessage();
        appProvider.incrementQuestions();
      }
    } catch (e) {
      if (!_isCancelled) {
        await appProvider.updateLastAIMessage('抱歉，出现了一些问题：$e');
        appProvider.setError('网络或服务错误: $e');
      }
    } finally {
      appProvider.setProcessing(false);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }
}

/// 历史对话列表组件
class _ConversationHistorySheet extends StatefulWidget {
  final AppProvider appProvider;

  const _ConversationHistorySheet({required this.appProvider});

  @override
  State<_ConversationHistorySheet> createState() =>
      _ConversationHistorySheetState();
}

class _ConversationHistorySheetState extends State<_ConversationHistorySheet> {
  @override
  void initState() {
    super.initState();
    widget.appProvider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    widget.appProvider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 顶部拖动条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '历史对话',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await widget.appProvider.createNewConversation();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(Translations().t('dialog_new_conversation')),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7C4DFF),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 对话列表
          Expanded(
            child: widget.appProvider.conversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无历史对话',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.appProvider.conversations.length,
      itemBuilder: (context, index) {
        final conversation = widget.appProvider.conversations[index];
        final isActive =
            conversation.id == widget.appProvider.currentConversationId;

        return _ConversationItem(
          conversation: conversation,
          isActive: isActive,
          onTap: () async {
            Navigator.pop(context);
            await widget.appProvider.switchConversation(conversation.id);
          },
          onDelete: () async {
            print(
                '[DEBUG-DIALOG-AREA] onDelete called for: ${conversation.id}');
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(Translations().t('dialog_delete_title')),
                content: Text(Translations().t('dialog_delete_confirm')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(Translations().t('dialog_cancel')),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            print('[DEBUG-DIALOG-AREA] confirm = $confirm');
            if (confirm == true) {
              print(
                  '[DEBUG-DIALOG-AREA] calling deleteConversation: ${conversation.id}');
              await widget.appProvider.deleteConversation(conversation.id);
              print('[DEBUG-DIALOG-AREA] deleteConversation finished');
            }
          },
        );
      },
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationItem({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF7C4DFF).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF7C4DFF) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            color: isActive ? Colors.white : Colors.grey[500],
            size: 20,
          ),
        ),
        title: Text(
          conversation.title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF7C4DFF) : Colors.grey[800],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatTime(conversation.updatedAt),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 20),
          onPressed: onDelete,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 汉堡菜单弹出表格（包含导航选项）
class _HamburgerMenuSheet extends StatelessWidget {
  final AppProvider appProvider;

  const _HamburgerMenuSheet({required this.appProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(iOSTheme.radiusExtraLarge)),
      ),
      padding: const EdgeInsets.all(iOSTheme.spacingLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: iOSTheme.systemGray5,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: iOSTheme.spacingLarge),

          // 菜单标题
          Padding(
            padding: const EdgeInsets.only(
                left: iOSTheme.spacingMedium, bottom: iOSTheme.spacingMedium),
            child: Text(
              '导航菜单',
              style: TextStyle(
                fontSize: iOSTheme.title1,
                fontWeight: FontWeight.w600,
                color: iOSTheme.secondaryLabel,
              ),
            ),
          ),

          // 主聊天
          _HamburgerMenuItem(
            icon: Icons.chat_bubble_rounded,
            title: '聊天',
            isActive: appProvider.currentComponent == ComponentType.chat,
            onTap: () {
              appProvider.switchTo(ComponentType.chat);
              Navigator.pop(context);
            },
          ),

          const Divider(height: 1, color: iOSTheme.systemGray5),

          // 已保存黑板
          _HamburgerMenuItem(
            icon: Icons.dashboard_rounded,
            title: '已保存黑板',
            isActive:
                appProvider.currentComponent == ComponentType.savedBlackboards,
            onTap: () {
              appProvider.switchTo(ComponentType.savedBlackboards);
              Navigator.pop(context);
            },
          ),

          // 已保存作业本
          _HamburgerMenuItem(
            icon: Icons.edit_note_rounded,
            title: '已保存作业本',
            isActive:
                appProvider.currentComponent == ComponentType.savedWorkbooks,
            onTap: () {
              appProvider.switchTo(ComponentType.savedWorkbooks);
              Navigator.pop(context);
            },
          ),

          // 已保存笔记本
          _HamburgerMenuItem(
            icon: Icons.book_rounded,
            title: '已保存笔记本',
            isActive:
                appProvider.currentComponent == ComponentType.savedNotebooks,
            onTap: () {
              appProvider.switchTo(ComponentType.savedNotebooks);
              Navigator.pop(context);
            },
          ),

          const Divider(height: 1, color: iOSTheme.systemGray5),

          // 设置
          _HamburgerMenuItem(
            icon: Icons.settings_rounded,
            title: '设置',
            isActive: false,
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings
            },
          ),

          const SizedBox(height: iOSTheme.spacingMedium),
        ],
      ),
    );
  }
}

/// 汉堡菜单项
class _HamburgerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _HamburgerMenuItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(iOSTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: iOSTheme.spacingMedium,
            vertical: iOSTheme.spacingSmall,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? iOSTheme.blue.withOpacity(0.1)
                      : iOSTheme.systemGray6,
                  borderRadius: BorderRadius.circular(iOSTheme.radiusSmall),
                ),
                child: Icon(
                  icon,
                  color: isActive ? iOSTheme.blue : iOSTheme.secondaryLabel,
                  size: 20,
                ),
              ),
              const SizedBox(width: iOSTheme.spacingMedium),
              Text(
                title,
                style: TextStyle(
                  fontSize: iOSTheme.body,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? iOSTheme.blue : iOSTheme.label,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Icon(
                  Icons.check_rounded,
                  color: iOSTheme.blue,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
