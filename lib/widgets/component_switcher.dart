import 'package:flutter/material.dart';

import '../providers/app_provider.dart';

class ComponentSwitcher extends StatelessWidget {
  final ComponentType currentComponent;
  final Function(ComponentType) onSwitch;
  
  const ComponentSwitcher({
    super.key,
    required this.currentComponent,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSwitchButton(
            type: ComponentType.landing,
            icon: Icons.home,
            label: '首页',
          ),
          _buildSwitchButton(
            type: ComponentType.blackboard,
            icon: Icons.school,
            label: '黑板',
          ),
          _buildSwitchButton(
            type: ComponentType.workbook,
            icon: Icons.edit_note,
            label: '作业本',
          ),
          _buildSwitchButton(
            type: ComponentType.notebook,
            icon: Icons.note,
            label: '笔记本',
          ),
          _buildSwitchButton(
            type: ComponentType.dialog,
            icon: Icons.chat,
            label: '对话',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSwitchButton({
    required ComponentType type,
    required IconData icon,
    required String label,
  }) {
    final isActive = currentComponent == type;
    
    return GestureDetector(
      onTap: () => onSwitch(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.blue : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}