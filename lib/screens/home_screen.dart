import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/component_controller.dart';
import '../widgets/dialog_area.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 主内容
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: appProvider.currentComponent == ComponentType.landing ||
                        appProvider.currentComponent == ComponentType.dialog
                    ? [
                        const Color(0xFFE8F5E9),
                        const Color(0xFFFCE4EC),
                        const Color(0xFFF3E5F5),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF5F5F5),
                      ],
              ),
            ),
            child: SafeArea(
              child: appProvider.currentComponent == ComponentType.landing
                  ? _buildLandingPage(appProvider)
                  : appProvider.currentComponent == ComponentType.dialog
                      ? const DialogArea(fullScreen: true)
                      : _buildActiveView(appProvider),
            ),
          ),
          
          // 左上角菜单按钮
          Positioned(
            top: 16,
            left: 16,
            child: _buildMenuButton(appProvider),
          ),
          
          // 隐藏式导航菜单
          if (_menuOpen) _buildNavOverlay(appProvider),
        ],
      ),
    );
  }

  Widget _buildMenuButton(AppProvider appProvider) {
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = !_menuOpen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _menuOpen ? const Color(0xFF7C4DFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _menuOpen ? Icons.close : Icons.menu_rounded,
          color: _menuOpen ? Colors.white : const Color(0xFF7C4DFF),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildNavOverlay(AppProvider appProvider) {
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = false),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 72, left: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: '首页',
                    isActive: appProvider.currentComponent == ComponentType.landing,
                    onTap: () {
                      appProvider.switchTo(ComponentType.landing);
                      setState(() => _menuOpen = false);
                    },
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_rounded,
                    label: '对话',
                    isActive: appProvider.currentComponent == ComponentType.dialog,
                    onTap: () {
                      appProvider.switchTo(ComponentType.dialog);
                      setState(() => _menuOpen = false);
                    },
                  ),
                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: '黑板',
                    isActive: appProvider.currentComponent == ComponentType.blackboard,
                    onTap: () {
                      appProvider.switchTo(ComponentType.blackboard);
                      setState(() => _menuOpen = false);
                    },
                  ),
                  _NavItem(
                    icon: Icons.edit_note_rounded,
                    label: '作业本',
                    isActive: appProvider.currentComponent == ComponentType.workbook,
                    onTap: () {
                      appProvider.switchTo(ComponentType.workbook);
                      setState(() => _menuOpen = false);
                    },
                  ),
                  _NavItem(
                    icon: Icons.book_rounded,
                    label: '笔记本',
                    isActive: appProvider.currentComponent == ComponentType.notebook,
                    onTap: () {
                      appProvider.switchTo(ComponentType.notebook);
                      setState(() => _menuOpen = false);
                    },
                  ),
                  const Divider(height: 16),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: '个人设置',
                    isActive: false,
                    onTap: () {
                      setState(() => _menuOpen = false);
                      _showProfileMenu(appProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandingPage(AppProvider appProvider) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeRow(appProvider),
            const SizedBox(height: 24),
            _buildQuickActions(appProvider),
            const SizedBox(height: 24),
            _buildTodayStats(appProvider),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeRow(AppProvider appProvider) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting，${appProvider.studentName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '准备好开始今天的学习了吗？',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showProfileMenu(appProvider),
          child: _buildAvatar(appProvider, 56),
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppProvider appProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快速开始',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _QuickActionCard(
              icon: Icons.chat_bubble_rounded,
              title: '对话',
              subtitle: '提问答疑',
              gradient: [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
              onTap: () => appProvider.switchTo(ComponentType.dialog),
            ),
            _QuickActionCard(
              icon: Icons.edit_note_rounded,
              title: '作业本',
              subtitle: '练习题目',
              gradient: [const Color(0xFF66BB6A), const Color(0xFF388E3C)],
              onTap: () => appProvider.switchTo(ComponentType.workbook),
            ),
            _QuickActionCard(
              icon: Icons.book_rounded,
              title: '笔记本',
              subtitle: '记录学习',
              gradient: [const Color(0xFFFFA726), const Color(0xFFF57C00)],
              onTap: () => appProvider.switchTo(ComponentType.notebook),
            ),
            _QuickActionCard(
              icon: Icons.dashboard_rounded,
              title: '黑板',
              subtitle: '查看讲解',
              gradient: [const Color(0xFFAB47BC), const Color(0xFF7B1FA2)],
              onTap: () => appProvider.switchTo(ComponentType.blackboard),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayStats(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日学习',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatItem(
                icon: Icons.help_outline,
                label: '提问',
                value: '${appProvider.todayQuestions}次',
                color: Colors.blue,
              ),
              const SizedBox(width: 20),
              _StatItem(
                icon: Icons.timer_outlined,
                label: '学习',
                value: '0分钟',
                color: Colors.green,
              ),
              const SizedBox(width: 20),
              _StatItem(
                icon: Icons.star_outline,
                label: '积分',
                value: '0',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(AppProvider appProvider) {
    return Column(
      children: [
        _buildSwitcherBar(appProvider),
        Expanded(
          child: ComponentController(
            currentComponent: appProvider.currentComponent,
          ),
        ),
        const DialogArea(),
      ],
    );
  }

  Widget _buildSwitcherBar(AppProvider appProvider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(70, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SwitcherBtn(
            icon: Icons.dashboard_rounded,
            label: '黑板',
            isActive: appProvider.currentComponent == ComponentType.blackboard,
            onTap: () => appProvider.switchTo(ComponentType.blackboard),
          ),
          _SwitcherBtn(
            icon: Icons.edit_note_rounded,
            label: '作业本',
            isActive: appProvider.currentComponent == ComponentType.workbook,
            onTap: () => appProvider.switchTo(ComponentType.workbook),
          ),
          _SwitcherBtn(
            icon: Icons.book_rounded,
            label: '笔记本',
            isActive: appProvider.currentComponent == ComponentType.notebook,
            onTap: () => appProvider.switchTo(ComponentType.notebook),
          ),
          _SwitcherBtn(
            icon: Icons.chat_bubble_rounded,
            label: '对话',
            isActive: appProvider.currentComponent == ComponentType.dialog,
            onTap: () => appProvider.switchTo(ComponentType.dialog),
          ),
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
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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

  void _showProfileMenu(AppProvider appProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileMenuSheet(appProvider: appProvider),
    );
  }
}

// --- 辅助组件 ---

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7C4DFF) : const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF7C4DFF),
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SwitcherBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SwitcherBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF7C4DFF).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF7C4DFF) : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF7C4DFF) : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuSheet extends StatelessWidget {
  final AppProvider appProvider;

  const _ProfileMenuSheet({required this.appProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://api.dicebear.com/7.x/lorelei/png?seed=${Uri.encodeComponent(appProvider.studentName)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.pink[100],
                      child: Icon(Icons.face, size: 32, color: Colors.pink[300]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appProvider.studentName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '今日提问 ${appProvider.todayQuestions} 次',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MenuItem(
            icon: Icons.edit,
            title: '修改昵称',
            onTap: () {
              Navigator.pop(context);
              _showNameDialog(context);
            },
          ),
          _MenuItem(
            icon: Icons.bar_chart,
            title: '学习统计',
            onTap: () {
              Navigator.pop(context);
              _showComingSoon(context, '学习统计');
            },
          ),
          _MenuItem(
            icon: Icons.settings,
            title: '设置',
            onTap: () {
              Navigator.pop(context);
              _showComingSoon(context, '设置');
            },
          ),
          _MenuItem(
            icon: Icons.help,
            title: '帮助',
            onTap: () {
              Navigator.pop(context);
              _showComingSoon(context, '帮助');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showNameDialog(BuildContext context) {
    final controller = TextEditingController(text: appProvider.studentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入新昵称',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                appProvider.setStudentName(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(feature),
        content: const Text('功能开发中，敬请期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF7C4DFF), size: 20),
      ),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}