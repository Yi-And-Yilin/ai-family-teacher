import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../providers/app_provider.dart';
import '../models/conversation.dart';
import 'blackboard.dart';
import 'question_ui.dart';

/// 黑板+聊天组合视图
/// 当AI需要使用黑板讲解时，显示此视图
/// 上方是黑板，下方是简化的聊天/题目录入区域
class BlackboardChatView extends StatefulWidget {
  const BlackboardChatView({super.key});

  @override
  State<BlackboardChatView> createState() => _BlackboardChatViewState();
}

class _BlackboardChatViewState extends State<BlackboardChatView> {
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isExpanded = false; // 是否展开聊天区域

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return Column(
      children: [
        // 黑板区域（上方）
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isExpanded 
              ? MediaQuery.of(context).size.height * 0.3 
              : MediaQuery.of(context).size.height * 0.6,
          child: const BlackboardWidget(),
        ),
        
        // 分隔线/拖动条
        _buildDivider(appProvider),
        
        // 下方区域
        Expanded(
          child: _buildBottomArea(appProvider),
        ),
      ],
    );
  }

  Widget _buildDivider(AppProvider appProvider) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      onVerticalDragUpdate: (details) {
        // 可选：实现拖动调整高度
      },
      child: Container(
        height: 40,
        color: Colors.grey[100],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isExpanded ? '收起黑板' : '展开聊天',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea(AppProvider appProvider) {
    // 如果有当前题目，显示题目UI
    if (appProvider.currentQuestionData != null) {
      return _buildQuestionArea(appProvider);
    }
    
    // 否则显示聊天/讲解区域
    return _buildChatExplanationArea(appProvider);
  }

  Widget _buildQuestionArea(AppProvider appProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: QuestionUIWidget(
          question: appProvider.currentQuestionData!,
          showAnswer: appProvider.showAnswer,
          correctAnswer: appProvider.currentAnswerData?.correct,
          userAnswer: appProvider.userAnswer,
          onAnswerSubmitted: (answer) {
            appProvider.setUserAnswer(answer);
            // 提交答案后，触发AI讲解
            // 这里可以调用AI服务进行讲解
          },
        ),
      ),
    );
  }

  Widget _buildChatExplanationArea(AppProvider appProvider) {
    final messages = appProvider.messages;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 讲解内容区域
          Expanded(
            child: messages.isEmpty
                ? _buildWaitingMessage()
                : _buildExplanationList(messages, appProvider),
          ),
          
          // 简化的输入栏
          _buildCompactInput(appProvider),
        ],
      ),
    );
  }

  Widget _buildWaitingMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 32,
            color: Colors.purple[200],
          ),
          const SizedBox(height: 8),
          Text(
            '正在准备讲解...',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationList(List<Message> messages, AppProvider appProvider) {
    print('[CHAT_VIEW] 🔨 构建消息列表 - 总消息数: ${messages.length}');
    // 只显示最近的几条消息
    final recentMessages = messages.length > 5
        ? messages.sublist(messages.length - 5)
        : messages;

    print('[CHAT_VIEW] 📋 显示最近 ${recentMessages.length} 条消息');
    for (int i = 0; i < recentMessages.length; i++) {
      final msg = recentMessages[i];
      print('  [$i] role=${msg.role}, toolCallEvents=${msg.toolCallEvents?.length ?? 0}');
    }

    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: recentMessages.length,
      itemBuilder: (context, index) {
        final message = recentMessages[index];
        if (message.role == MessageRole.user) {
          return _buildUserBubble(message, appProvider);
        } else if (message.role == MessageRole.assistant) {
          return _buildAIBubble(message);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildUserBubble(Message message, AppProvider appProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBubble(Message message) {
    print('[CHAT_VIEW] 🛠️ 构建AI气泡 - toolCallEvents: ${message.toolCallEvents?.length ?? 0}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
              ),
            ),
            child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 工具调用指标（可折叠）
                  if (message.toolCallEvents != null && message.toolCallEvents!.isNotEmpty)
                    ...message.toolCallEvents!
                        .map((event) {
                          print('[CHAT_VIEW] 🎨 渲染工具指标: ${event['tool_name']} (${event['state']})');
                          return _buildToolCallIndicator(event);
                        })
                        .toList(),
                  // AI 回答内容
                  MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 13, height: 1.4),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        backgroundColor: Colors.grey[200],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInput(AppProvider appProvider) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // 隐藏黑板的按钮（已废弃，保持在聊天中）
          // IconButton(
          //   icon: Icon(Icons.close_fullscreen, color: Colors.grey[400], size: 20),
          //   onPressed: () => appProvider.setBlackboardInlineMode(false),
          //   tooltip: '关闭黑板',
          // ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  hintText: '有问题可以问我...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  hintStyle: TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) => _sendCaption(appProvider),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: appProvider.isProcessing ? null : () => _sendCaption(appProvider),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: appProvider.isProcessing 
                      ? [Colors.grey, Colors.grey]
                      : [const Color(0xFF7C4DFF), const Color(0xFFE040FB)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                appProvider.isProcessing ? Icons.hourglass_top : Icons.send,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendCaption(AppProvider appProvider) {
    final text = _captionController.text.trim();
    if (text.isEmpty) return;
    
    _captionController.clear();
    // TODO: 发送消息到AI服务
    // 这里需要调用AI服务进行对话
  }

  /// 构建可折叠的工具调用指标
  Widget _buildToolCallIndicator(Map<String, dynamic> event) {
    final toolName = event['tool_name'] as String? ?? '';
    final state = event['state'] as String? ?? '';
    final progressText = event['progress_text'] as String? ?? '';
    final arguments = event['arguments'] as Map<String, dynamic>?;
    final result = event['result'] as Map<String, dynamic>?;
    final isDone = state == 'done';
    
    print('[CHAT_VIEW] 🎨 构建工具指标Widget:');
    print('  - toolName: $toolName');
    print('  - state: $state (isDone: $isDone)');
    print('  - progressText: $progressText');
    print('  - hasArguments: ${arguments != null}');
    print('  - hasResult: ${result != null}');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.08) : Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: const ExpansionTileThemeData(
            collapsedIconColor: Colors.grey,
            iconColor: Colors.grey,
          ),
        ),
        child: ExpansionTile(
          leading: Text(
            isDone ? '✅' : '🔄',
            style: const TextStyle(fontSize: 16),
          ),
          title: Text(
            progressText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDone ? Colors.green[700] : Colors.blue[700],
            ),
          ),
          trailing: Icon(
            Icons.expand_more,
            size: 18,
            color: Colors.grey[400],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (arguments != null && arguments.isNotEmpty) ...[
                    Text(
                      '📋 参数:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatJson(arguments),
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (result != null && result.isNotEmpty) ...[
                    Text(
                      '📤 结果:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatJson(result),
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
}
