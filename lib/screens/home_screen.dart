import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../i18n/translations.dart';
import '../widgets/component_controller.dart';
import '../theme/ios_theme.dart';
import 'settings_screen.dart';
import 'api_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: appProvider.currentComponent == ComponentType.landing
                ? [
                    const Color(0xFFE8F5E9),
                    const Color(0xFFFCE4EC),
                    const Color(0xFFF3E5F5),
                  ]
                : [
                    iOSTheme.white,
                    iOSTheme.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: appProvider.currentComponent == ComponentType.landing
              ? _buildLandingPage(appProvider)
              : _buildActiveView(appProvider),
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
      greeting = Translations().t('landing_morning');
    } else if (hour < 18) {
      greeting = Translations().t('landing_afternoon');
    } else {
      greeting = Translations().t('landing_evening');
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
                Translations().t('landing_ready'),
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
          Translations().t('landing_quick_start'),
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
              title: Translations().t('landing_chat'),
              subtitle: Translations().t('landing_chat_subtitle'),
              gradient: [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
              onTap: () => appProvider.switchTo(ComponentType.chat),
            ),
            _QuickActionCard(
              icon: Icons.edit_note_rounded,
              title: '已保存作业本',
              subtitle: '查看历史作业本记录',
              gradient: [const Color(0xFF66BB6A), const Color(0xFF388E3C)],
              onTap: () => appProvider.switchTo(ComponentType.savedWorkbooks),
            ),
            _QuickActionCard(
              icon: Icons.book_rounded,
              title: '已保存笔记本',
              subtitle: '查看历史笔记记录',
              gradient: [const Color(0xFFFFA726), const Color(0xFFF57C00)],
              onTap: () => appProvider.switchTo(ComponentType.savedNotebooks),
            ),
            _QuickActionCard(
              icon: Icons.dashboard_rounded,
              title: '已保存黑板',
              subtitle: '查看历史黑板记录',
              gradient: [const Color(0xFFAB47BC), const Color(0xFF7B1FA2)],
              onTap: () => appProvider.switchTo(ComponentType.savedBlackboards),
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
            Translations().t('home_today_learning'),
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
                label: Translations().t('home_ask_questions'),
                value: '${appProvider.todayQuestions}次',
                color: Colors.blue,
              ),
              const SizedBox(width: 20),
              _StatItem(
                icon: Icons.timer_outlined,
                label: Translations().t('home_study'),
                value: '0分钟',
                color: Colors.green,
              ),
              const SizedBox(width: 20),
              _StatItem(
                icon: Icons.star_outline,
                label: Translations().t('home_points'),
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
    // 直接显示 ComponentController，不再需要 Switcher Bar
    return ComponentController(
      currentComponent: appProvider.currentComponent,
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
                      child:
                          Icon(Icons.face, size: 32, color: Colors.pink[300]),
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
            title: Translations().t('home_change_nickname'),
            onTap: () {
              Navigator.pop(context);
              _showNameDialog(context);
            },
          ),
          _MenuItem(
            icon: Icons.bar_chart,
            title: Translations().t('profile_statistics'),
            onTap: () {
              Navigator.pop(context);
              _showComingSoon(context, Translations().t('profile_statistics'));
            },
          ),
          _MenuItem(
            icon: Icons.settings,
            title: Translations().t('nav_settings'),
            onTap: () {
              print('[DEBUG] home_screen设置按钮点击 - 1. 开始执行onTap');
              Navigator.pop(context);
              print('[DEBUG] home_screen设置按钮点击 - 2. Navigator.pop完成');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  print('[DEBUG] home_screen设置按钮点击 - 3. 进入SettingsScreen构建');
                  return const SettingsScreen();
                }),
              );
              print('[DEBUG] home_screen设置按钮点击 - 4. Navigator.push完成');
            },
          ),
          _MenuItem(
            icon: Icons.science,
            title: Translations().t('home_api_test'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ApiTestScreen()),
              );
            },
          ),
          _MenuItem(
            icon: Icons.help,
            title: Translations().t('profile_help'),
            onTap: () {
              Navigator.pop(context);
              _showComingSoon(context, Translations().t('profile_help'));
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
        title: Text(Translations().t('home_change_nickname')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: Translations().t('home_nickname_hint'),
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
            child: Text(Translations().t('dialog_cancel')),
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
            child: Text(Translations().t('common_save')),
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
        content: Text(Translations().t('home_features_coming')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Translations().t('home_got_it')),
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
