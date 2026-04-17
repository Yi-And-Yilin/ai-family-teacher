import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../i18n/translations.dart';

/// 已保存黑板列表页面
class SavedBlackboardList extends StatelessWidget {
  const SavedBlackboardList({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return _SavedListScaffold(
      itemType: 'blackboard',
      icon: Icons.dashboard_rounded,
      title: Translations().t('saved_blackboards'),
      emptyMessage: Translations().t('no_saved_blackboards'),
      appProvider: appProvider,
    );
  }
}

/// 已保存作业本列表页面
class SavedWorkbookList extends StatelessWidget {
  const SavedWorkbookList({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return _SavedListScaffold(
      itemType: 'workbook',
      icon: Icons.edit_note_rounded,
      title: Translations().t('saved_workbooks'),
      emptyMessage: Translations().t('no_saved_workbooks'),
      appProvider: appProvider,
    );
  }
}

/// 已保存笔记本列表页面
class SavedNotebookList extends StatelessWidget {
  const SavedNotebookList({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return _SavedListScaffold(
      itemType: 'notebook',
      icon: Icons.book_rounded,
      title: Translations().t('saved_notebooks'),
      emptyMessage: Translations().t('no_saved_notebooks'),
      appProvider: appProvider,
    );
  }
}

/// 通用的已保存列表脚手架
class _SavedListScaffold extends StatefulWidget {
  final String itemType;
  final IconData icon;
  final String title;
  final String emptyMessage;
  final AppProvider appProvider;

  const _SavedListScaffold({
    required this.itemType,
    required this.icon,
    required this.title,
    required this.emptyMessage,
    required this.appProvider,
  });

  @override
  State<_SavedListScaffold> createState() => _SavedListScaffoldState();
}

class _SavedListScaffoldState extends State<_SavedListScaffold> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      // 从数据库加载会话列表，过滤包含当前类型工具调用的会话
      final conversations = await widget.appProvider.databaseService
          .getConversations('default_user');

      final items = <Map<String, dynamic>>[];
      for (final conversation in conversations) {
        final messages = await widget.appProvider.databaseService
            .getMessages(conversation.id);

        // 检查消息中是否包含与当前类型相关的工具调用
        bool hasRelevantToolCalls = false;
        for (final message in messages) {
          if (message.toolCallEvents != null) {
            for (final event in message.toolCallEvents!) {
              final toolName =
                  (event['tool_name'] as String? ?? '').toLowerCase();
              if (widget.itemType == 'blackboard' &&
                  toolName.contains('blackboard')) {
                hasRelevantToolCalls = true;
                break;
              } else if (widget.itemType == 'workbook' &&
                  toolName.contains('workbook')) {
                hasRelevantToolCalls = true;
                break;
              } else if (widget.itemType == 'notebook' &&
                  message.content.contains('N>')) {
                hasRelevantToolCalls = true;
                break;
              }
            }
          }
          if (hasRelevantToolCalls) break;
        }

        if (hasRelevantToolCalls) {
          items.add({
            'conversation': conversation,
            'messages': messages,
          });
        }
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      print('[SavedList] Error loading items: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : _items.isEmpty
                        ? _buildEmptyState()
                        : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: const Color(0xFF7C4DFF), size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
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
            widget.icon,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyMessage,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
              _loadItems();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final conversation = item['conversation'];
        final messages = item['messages'] as List<dynamic>;

        return _buildListItem(conversation, messages);
      },
    );
  }

  Widget _buildListItem(dynamic conversation, List<dynamic> messages) {
    final createdAt = conversation.createdAt as DateTime;
    final title = conversation.title as String;

    // 提取预览文本
    String previewText = '';
    for (final message in messages) {
      if (message.role.name == 'assistant' && message.content.isNotEmpty) {
        previewText = message.content.length > 100
            ? message.content.substring(0, 100) + '...'
            : message.content;
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // 加载历史对话并跳转到chat
          widget.appProvider.loadHistoricalConversation(conversation.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 20, color: const Color(0xFF7C4DFF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              if (previewText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  previewText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${messages.length} 条消息',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
