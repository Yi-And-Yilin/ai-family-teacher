import 'package:flutter/material.dart';

import 'blackboard.dart';
import 'workbook.dart';
import 'notebook.dart';
import 'blackboard_chat_view.dart';
import '../providers/app_provider.dart';

class ComponentController extends StatelessWidget {
  final ComponentType currentComponent;
  
  const ComponentController({
    super.key,
    required this.currentComponent,
  });

  @override
  Widget build(BuildContext context) {
    switch (currentComponent) {
      case ComponentType.landing:
        return const _EmptyComponent(message: '欢迎使用小书童');
      case ComponentType.blackboard:
        return const BlackboardWidget();
      case ComponentType.workbook:
        return const WorkbookWidget();
      case ComponentType.notebook:
        return const NotebookWidget();
      case ComponentType.blackboardChat:
        return const BlackboardChatView();
      case ComponentType.dialog:
      default:
        return const _EmptyComponent();
    }
  }
}

class _EmptyComponent extends StatelessWidget {
  final String message;
  const _EmptyComponent({this.message = '请开始对话，或选择其他组件'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
    );
  }
}