import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:convert';
import 'dart:typed_data';

import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../models/conversation.dart';
import '../services/voice_service.dart';

class DialogArea extends StatefulWidget {
  final bool fullScreen;
  const DialogArea({super.key, this.fullScreen = false});

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
        appProvider.updateBlackboard([{
          'type': 'text',
          'content': content,
          'position': {'x': 50, 'y': 50},
          'style': {'fontSize': 24, 'color': '#FFFFFF'}
        }]);
        appProvider.switchTo(ComponentType.blackboard);
      },
      onWorkbookMark: (marks) {
        appProvider.updateWorkbookMarks(marks);
        appProvider.switchTo(ComponentType.workbook);
      },
      onBlackboardClear: () {
        appProvider.updateBlackboard([]);
      },
      onRequireConfirmation: (title, message) async {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('同意执行'),
              ),
            ],
          ),
        );
        return result ?? false;
      },
    );
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FE), Color(0xFFFFFFFF)],
        ),
      ),
      child: Column(
        children: [
          _buildHeader(appProvider),
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

  Widget _buildBottomSheetView(AppProvider appProvider, List<Message> messages) {
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
    return Container(
      padding: EdgeInsets.fromLTRB(70, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '与 小书童 对话',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '随时为你答疑解惑',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // 历史对话按钮
          IconButton(
            icon: Icon(Icons.history, color: Colors.grey[600], size: 22),
            onPressed: () => _showConversationHistory(appProvider),
            tooltip: '历史对话',
          ),
          // 新建对话按钮
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: Colors.grey[600], size: 22),
            onPressed: () => _createNewConversation(appProvider),
            tooltip: '新建对话',
          ),
          const SizedBox(width: 4),
          _buildAvatar(appProvider, 44),
        ],
      ),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('小书童', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 4),
          Text('你的 AI 学习伙伴', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 32),
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
          Text('开始对话吧！', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(AppProvider appProvider) {
    final prompts = [
      {'icon': Icons.help_outline, 'text': '帮我解释这个概念'},
      {'icon': Icons.edit_note, 'text': '出一道练习题'},
      {'icon': Icons.lightbulb_outline, 'text': '给我一些学习建议'},
    ];

    return Column(
      children: prompts.map((p) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
          child: InkWell(
            onTap: () {
              _textController.text = p['text'] as String;
              _sendMessage(appProvider);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(p['icon'] as IconData, color: const Color(0xFF7C4DFF), size: 20),
                  const SizedBox(width: 12),
                  Text(p['text'] as String, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(messages[index], appProvider),
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
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                ),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF7C4DFF) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
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
                          child: Image.memory(base64Decode(img), width: 80, height: 80, fit: BoxFit.cover),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Markdown渲染
                  if (isUser)
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      onTapLink: (text, href, title) {
                        // 处理链接点击
                        if (href != null) {
                          // 可以在这里打开链接
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
                        h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
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
                          border: Border(left: BorderSide(color: Colors.purple[300]!, width: 4)),
                        ),
                        listBullet: TextStyle(color: Colors.purple[400]),
                        tableHead: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        tableBody: TextStyle(color: Colors.grey[700]),
                        em: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[800]),
                        strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                      extensionSet: md.ExtensionSet.gitHubWeb,
                    ),
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

  Widget _buildAvatar(AppProvider appProvider, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
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
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          if (_selectedImageBytes.isNotEmpty) _buildImagePreview(),
          Row(
            children: [
              _buildCircleBtn(Icons.add_photo_alternate_outlined, _pickFiles),
              const SizedBox(width: 8),
              _buildCircleBtn(_isListening ? Icons.mic : Icons.mic_none_outlined, () => _toggleVoiceInput(appProvider), isActive: _isListening),
              const SizedBox(width: 8),
              // 自动播放语音开关
              _buildCircleBtn(
                appProvider.autoSpeak ? Icons.volume_up : Icons.volume_off,
                () {
                  if (appProvider.autoSpeak) {
                    // 关闭时停止当前播放
                    _voiceService.stopSpeaking();
                  }
                  appProvider.setAutoSpeak(!appProvider.autoSpeak);
                },
                isActive: appProvider.autoSpeak,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(hintText: '输入问题...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)),
                    onSubmitted: (_) => _sendMessage(appProvider),
                    enabled: !appProvider.isProcessing,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: appProvider.isProcessing ? null : () => _sendMessage(appProvider),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: appProvider.isProcessing ? [Colors.grey, Colors.grey] : [const Color(0xFF7C4DFF), const Color(0xFFE040FB)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Icon(appProvider.isProcessing ? Icons.hourglass_top : Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputAreaCompact(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildCircleBtn(Icons.add_photo_alternate_outlined, _pickFiles, size: 36),
          const SizedBox(width: 8),
          _buildCircleBtn(_isListening ? Icons.mic : Icons.mic_none_outlined, () => _toggleVoiceInput(appProvider), isActive: _isListening, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(hintText: '输入问题...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                onSubmitted: (_) => _sendMessage(appProvider),
                enabled: !appProvider.isProcessing,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: appProvider.isProcessing ? null : () => _sendMessage(appProvider),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: appProvider.isProcessing ? [Colors.grey, Colors.grey] : [const Color(0xFF7C4DFF), const Color(0xFFE040FB)]),
                shape: BoxShape.circle,
              ),
              child: Icon(appProvider.isProcessing ? Icons.hourglass_top : Icons.send_rounded, color: Colors.white, size: 18),
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
                  child: Image.memory(_selectedImageBytes[index], height: 60, width: 60, fit: BoxFit.cover),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: InkWell(
                    onTap: () => setState(() => _selectedImageBytes.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
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

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap, {bool isActive = false, double size = 44}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? Colors.red[50] : const Color(0xFFF5F5F7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.red : Colors.grey[600], size: size * 0.5),
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
        onStatusChanged: (listening) => setState(() => _isListening = listening),
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

    final List<String> imagesBase64 = _selectedImageBytes.map((b) => base64Encode(b)).toList();
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
      final stream = _aiService!.answerQuestionStream(
        history: appProvider.messages.take(appProvider.messages.length - 1).toList(),
        images: imagesBase64.isNotEmpty ? imagesBase64 : null,
      );

      await for (final chunk in stream) {
        if (_isCancelled) break;
        
        print('[DIALOG_AREA] ========== 收到ChatChunk ==========');
        print('[DIALOG_AREA] chunk.content: ${chunk.content}');
        print('[DIALOG_AREA] chunk.workbookContent: ${chunk.workbookContent}');
        print('[DIALOG_AREA] chunk.blackboardContent: ${chunk.blackboardContent}');
        print('[DIALOG_AREA] hasWorkbookContent: ${chunk.hasWorkbookContent}');
        print('[DIALOG_AREA] hasBlackboardContent: ${chunk.hasBlackboardContent}');
        print('[DIALOG_AREA] =====================================');
        
        // 处理聊天内容（已经去掉 C> 前缀）
        if (chunk.content != null && chunk.content!.isNotEmpty) {
          fullContent += chunk.content!;
          await appProvider.updateLastAIMessage(fullContent);
        }
        
        // 处理黑板内容（已经去掉 B> 前缀）
        if (chunk.hasBlackboardContent) {
          print('[DIALOG_AREA] ✓ 处理黑板内容: ${chunk.blackboardContent}');
          appProvider.appendToBlackboardContent(chunk.blackboardContent!);
          appProvider.setBlackboardWithChatMode(true);
        }
        
        // 处理做题册内容（已经去掉 W> 前缀）
        if (chunk.hasWorkbookContent) {
          print('[DIALOG_AREA] ✓ 处理做题册内容: ${chunk.workbookContent}');
          appProvider.appendToWorkbookContent(chunk.workbookContent!);
        }
        
        // 处理笔记本内容（已经去掉 N> 前缀）
        if (chunk.hasNotebookContent) {
          print('[DIALOG_AREA] ✓ 处理笔记本内容: ${chunk.notebookContent}');
          appProvider.appendToNotebookContent(chunk.notebookContent!);
        }
        
        // 处理题目响应（保留兼容旧格式）
        if (chunk.hasQuestionResponse) {
          print('[DIALOG_AREA] ✓ 处理题目响应');
          final qr = chunk.questionResponse!;
          appProvider.setCurrentQuestionData(
            qr.question,
            answer: qr.answer,
          );
          appProvider.setBlackboardWithChatMode(true);
        }
        
        // 处理完成
        if (chunk.done) {
          print('[DIALOG_AREA] 流式处理完成');
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
      }
    } finally {
      appProvider.setProcessing(false);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

/// 历史对话列表组件
class _ConversationHistorySheet extends StatelessWidget {
  final AppProvider appProvider;

  const _ConversationHistorySheet({required this.appProvider});

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
                    await appProvider.createNewConversation();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建对话'),
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
            child: appProvider.conversations.isEmpty
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
      itemCount: appProvider.conversations.length,
      itemBuilder: (context, index) {
        final conversation = appProvider.conversations[index];
        final isActive = conversation.id == appProvider.currentConversationId;
        
        return _ConversationItem(
          conversation: conversation,
          isActive: isActive,
          onTap: () async {
            Navigator.pop(context);
            await appProvider.switchConversation(conversation.id);
          },
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('删除对话'),
                content: const Text('确定要删除这个对话吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
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
            if (confirm == true) {
              await appProvider.deleteConversation(conversation.id);
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
        color: isActive ? const Color(0xFF7C4DFF).withOpacity(0.1) : Colors.transparent,
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
