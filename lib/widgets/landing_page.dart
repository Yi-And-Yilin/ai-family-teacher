import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8F5E9), // 淡绿
            const Color(0xFFFCE4EC), // 淡粉
            const Color(0xFFF3E5F5), // 淡紫
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // 欢迎行：左边问候，右边头像
              _buildWelcomeRow(appProvider),
              
              const SizedBox(height: 24),
              
              // 快捷入口
              _buildQuickActions(appProvider),
              
              const SizedBox(height: 24),
              
              // 今日学习
              _buildTodayStats(appProvider),
              
              const SizedBox(height: 20),
            ],
          ),
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
        // 左边：欢迎文字
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // 右边：头像
        _buildAvatar(appProvider),
      ],
    );
  }

  Widget _buildAvatar(AppProvider appProvider) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
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
          // 使用 lorelei 风格生成甜美女孩头像
          'https://api.dicebear.com/7.x/lorelei/png?seed=${Uri.encodeComponent(appProvider.studentName)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.network(
              'https://api.dicebear.com/7.x/adventurer/png?seed=${Uri.encodeComponent(appProvider.studentName)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.pink[100],
                child: Icon(
                  Icons.face,
                  size: 28,
                  color: Colors.pink[300],
                ),
              ),
            );
          },
        ),
      ),
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
                Icon(
                  icon,
                  size: 28,
                  color: Colors.white,
                ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
