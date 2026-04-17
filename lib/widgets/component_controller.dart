import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'saved_lists.dart';
import 'dialog_area.dart';
import 'component_chat_layout.dart';
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
      case ComponentType.chat:
        return Consumer<AppProvider>(
          builder: (context, appProvider, child) {
            final hasActiveComponent =
                appProvider.activeComponentType != ActiveComponentType.none;
            return ComponentChatLayout(
              chatWidget: DialogArea(
                fullScreen: true,
                showHeader: !hasActiveComponent,
              ),
            );
          },
        );
      case ComponentType.savedBlackboards:
        return const SavedBlackboardList();
      case ComponentType.savedWorkbooks:
        return const SavedWorkbookList();
      case ComponentType.savedNotebooks:
        return const SavedNotebookList();
      case ComponentType.settings:
        return const _EmptyComponent(message: '设置页面');
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
