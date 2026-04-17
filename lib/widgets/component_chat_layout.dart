import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../providers/app_provider.dart';
import '../screens/settings_screen.dart';
import '../theme/ios_theme.dart';
import 'blackboard.dart';
import 'workbook.dart';
import 'notebook.dart';

class ComponentChatLayout extends StatefulWidget {
  final Widget chatWidget;

  const ComponentChatLayout({super.key, required this.chatWidget});

  @override
  State<ComponentChatLayout> createState() => _ComponentChatLayoutState();
}

class _ComponentChatLayoutState extends State<ComponentChatLayout> {
  double _splitRatio = 0.45;
  static const double _minComponentRatio = 0.1;
  static const double _maxComponentRatio = 0.9;
  static const double _subtitleThreshold = 0.85;
  final ScrollController _subtitleScrollController = ScrollController();

  bool get _isSubtitleMode => _splitRatio >= _subtitleThreshold;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final activeComponent = appProvider.activeComponentType;
        print(
            '[E2E-DEBUG] ComponentChatLayout.build() - activeComponent: $activeComponent, splitRatio: ${(_splitRatio * 100).toInt()}%');

        if (activeComponent == ActiveComponentType.none) {
          print('[E2E-DEBUG] No active component - showing full chat');
          return widget.chatWidget;
        }

        return Column(
          children: [
            _buildHeader(appProvider),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const dividerHeight = 40.0;
                  final availableHeight = constraints.maxHeight - dividerHeight;
                  final componentHeight = availableHeight * _splitRatio;
                  final chatHeight = availableHeight * (1 - _splitRatio);
                  final isSubtitle = _isSubtitleMode;
                  print(
                      '[E2E-DEBUG] Split view mode - componentHeight: ${componentHeight.toInt()}, chatHeight: ${chatHeight.toInt()}, isSubtitle: $isSubtitle');

                  if (isSubtitle) {
                    return Stack(
                      children: [
                        SizedBox(
                          height: constraints.maxHeight,
                          child:
                              _buildComponentView(appProvider, activeComponent),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child:
                              _buildFloatingSubtitleBar(context, appProvider),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(
                        height: componentHeight,
                        child:
                            _buildComponentView(appProvider, activeComponent),
                      ),
                      _buildDraggableDivider(context),
                      SizedBox(
                        height: chatHeight,
                        child: widget.chatWidget,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
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
              GestureDetector(
                onTap: () => _showHamburgerMenu(context, appProvider),
                child: Icon(
                  Icons.menu_rounded,
                  color: iOSTheme.blue,
                  size: 26,
                ),
              ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showConversationHistory(context, appProvider),
                    child: Icon(
                      Icons.history_rounded,
                      color: iOSTheme.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _createNewConversation(appProvider),
                    child: Icon(
                      Icons.add_rounded,
                      color: iOSTheme.blue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildAvatar(appProvider, 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHamburgerMenu(BuildContext context, AppProvider appProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _HamburgerMenuSheet(appProvider: appProvider),
    );
  }

  void _showConversationHistory(BuildContext context, AppProvider appProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ConversationHistorySheet(appProvider: appProvider),
    );
  }

  Future<void> _createNewConversation(AppProvider appProvider) async {
    await appProvider.createNewConversation();
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

  Widget _buildComponentView(
      AppProvider appProvider, ActiveComponentType type) {
    Widget child;
    switch (type) {
      case ActiveComponentType.blackboard:
        child = const BlackboardWidget();
        break;
      case ActiveComponentType.workbook:
        child = const WorkbookWidget();
        break;
      case ActiveComponentType.notebook:
        child = const NotebookWidget();
        break;
      case ActiveComponentType.none:
        return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: child,
    );
  }

  Widget _buildDraggableDivider(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          final delta = details.delta.dy / MediaQuery.of(context).size.height;
          _splitRatio = (_splitRatio + delta).clamp(
            _minComponentRatio,
            _maxComponentRatio,
          );
        });
      },
      onDoubleTap: () {
        setState(() {
          if (_isSubtitleMode) {
            _splitRatio = 0.45;
          } else {
            _splitRatio = _subtitleThreshold;
          }
        });
      },
      child: Container(
        height: 40,
        color: Colors.grey[100],
        child: Center(
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
              Icon(Icons.drag_handle, color: Colors.grey[400], size: 20),
              const SizedBox(width: 8),
              Text(
                '${(_splitRatio * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.keyboard_arrow_up, color: Colors.grey[400], size: 16),
              Icon(Icons.keyboard_arrow_down,
                  color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSubtitleBar(
      BuildContext context, AppProvider appProvider) {
    final messages = appProvider.messages;
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final lastLlmMsg = messages.lastWhere(
      (msg) => msg.role != MessageRole.user,
      orElse: () => messages.last,
    );

    final content = lastLlmMsg.content;
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final reversedLines = lines.reversed.toList();

    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            setState(() {});
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _subtitleScrollController,
          physics: const BouncingScrollPhysics(),
          child: _SubtitleLineView(
            lines: reversedLines,
            scrollController: _subtitleScrollController,
          ),
        ),
      ),
    );
  }
}

class _SubtitleLineView extends StatelessWidget {
  final List<String> lines;
  final ScrollController scrollController;

  const _SubtitleLineView({
    required this.lines,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    const itemHeight = 56.0;
    final maxIndex = lines.length - 1;

    int getLineIndex() {
      try {
        if (!scrollController.hasClients ||
            !scrollController.position.hasContentDimensions ||
            scrollController.position.maxScrollExtent == 0) {
          return 0;
        }
        final scrollOffset = scrollController.offset;
        final index = (scrollOffset / itemHeight).round();
        return index.clamp(0, maxIndex);
      } catch (e) {
        return 0;
      }
    }

    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, child) {
        final currentIndex = getLineIndex();
        final currentLine = lines[currentIndex];

        return Container(
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.smart_toy,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentLine,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                  label: const Text('新对话'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7C4DFF),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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

        return ListTile(
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
            onPressed: () async {
              print('[DEBUG-DELETE] Button pressed for: ${conversation.id}');
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
                      onPressed: () {
                        print('[DEBUG-DELETE] User cancelled');
                        Navigator.pop(context, false);
                      },
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        print('[DEBUG-DELETE] User confirmed delete');
                        Navigator.pop(context, true);
                      },
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
              print('[DEBUG-DELETE] confirm = $confirm');
              if (confirm == true) {
                print(
                    '[DEBUG-DELETE] Calling deleteConversation: ${conversation.id}');
                await appProvider.deleteConversation(conversation.id);
              }
            },
          ),
          onTap: () async {
            Navigator.pop(context);
            await appProvider.switchConversation(conversation.id);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

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
}

class _HamburgerMenuSheet extends StatelessWidget {
  final AppProvider appProvider;

  const _HamburgerMenuSheet({required this.appProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: iOSTheme.systemGray5,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '导航菜单',
              style: TextStyle(
                fontSize: iOSTheme.title1,
                fontWeight: FontWeight.w600,
                color: iOSTheme.secondaryLabel,
              ),
            ),
          ),
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
          _HamburgerMenuItem(
            icon: Icons.settings_rounded,
            title: '设置',
            isActive: false,
            onTap: () {
              print('[DEBUG] 设置按钮点击 - 1. 开始执行onTap');
              Navigator.pop(context);
              print('[DEBUG] 设置按钮点击 - 2. Navigator.pop完成');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  print('[DEBUG] 设置按钮点击 - 3. 进入SettingsScreen构建');
                  return const SettingsScreen();
                }),
              );
              print('[DEBUG] 设置按钮点击 - 4. Navigator.push完成');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? iOSTheme.blue.withOpacity(0.1)
                      : iOSTheme.systemGray6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isActive ? iOSTheme.blue : iOSTheme.secondaryLabel,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
