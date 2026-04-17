import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_family_teacher/providers/app_provider.dart';
import 'package:ai_family_teacher/widgets/component_chat_layout.dart';

void main() {
  group('ComponentChatLayout State Tests', () {
    late AppProvider appProvider;

    setUp(() {
      appProvider = AppProvider();
    });

    tearDown(() {
      appProvider.dispose();
    });

    group('ActiveComponentType State Tests', () {
      test('初始状态应为none', () {
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });

      test('setActiveComponentType可以设置blackboard', () {
        appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.blackboard));
      });

      test('setActiveComponentType可以设置workbook', () {
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));
      });

      test('setActiveComponentType可以设置notebook', () {
        appProvider.setActiveComponentType(ActiveComponentType.notebook);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.notebook));
      });

      test('clearActiveComponentType应重置为none', () {
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.clearActiveComponentType();
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });

      test('setActiveComponentType触发notifyListeners', () {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        expect(notifyCount, equals(1));

        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        expect(notifyCount, equals(2));

        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        expect(notifyCount, equals(3));
      });

      test('clearActiveComponentType触发notifyListeners', () {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        appProvider.setActiveComponentType(ActiveComponentType.notebook);
        expect(notifyCount, equals(1));

        appProvider.clearActiveComponentType();
        expect(notifyCount, equals(2));
      });
    });

    group('Streaming Content State Tests', () {
      test('初始streamingWorkbookContent应为空', () {
        expect(appProvider.streamingWorkbookContent, isEmpty);
      });

      test('appendToWorkbookContent正确追加内容', () {
        appProvider.appendToWorkbookContent('第一题\n');
        expect(appProvider.streamingWorkbookContent, contains('第一题'));

        appProvider.appendToWorkbookContent('第二题\n');
        expect(appProvider.streamingWorkbookContent, contains('第二题'));
      });

      test('初始streamingBlackboardContent应为空', () {
        expect(appProvider.streamingBlackboardContent, isEmpty);
      });

      test('appendToBlackboardContent正确追加内容', () {
        appProvider.appendToBlackboardContent('分数入门\n');
        expect(appProvider.streamingBlackboardContent, contains('分数入门'));
      });

      test('初始streamingNotebookContent应为空', () {
        expect(appProvider.streamingNotebookContent, isEmpty);
      });

      test('appendToNotebookContent正确追加内容', () {
        appProvider.appendToNotebookContent('学习笔记\n');
        expect(appProvider.streamingNotebookContent, contains('学习笔记'));
      });
    });

    group('clearAllStreamingContent Tests', () {
      test('clearAllStreamingContent正确重置所有streaming内容', () {
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.appendToWorkbookContent('作业1');
        appProvider.appendToBlackboardContent('黑板1');
        appProvider.appendToNotebookContent('笔记1');

        expect(appProvider.streamingWorkbookContent, isNotEmpty);
        expect(appProvider.streamingBlackboardContent, isNotEmpty);
        expect(appProvider.streamingNotebookContent, isNotEmpty);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));

        appProvider.clearAllStreamingContent();

        expect(appProvider.streamingWorkbookContent, isEmpty);
        expect(appProvider.streamingBlackboardContent, isEmpty);
        expect(appProvider.streamingNotebookContent, isEmpty);
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });

      test('clearAllStreamingContent触发一次notifyListeners', () {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        appProvider.appendToWorkbookContent('内容1');

        appProvider.clearAllStreamingContent();

        expect(notifyCount, equals(2));
      });
    });

    group('Component Type Detection Logic Tests', () {
      test('activeComponentType与streaming内容可以独立设置', () {
        appProvider.appendToWorkbookContent('作业内容');
        appProvider.setActiveComponentType(ActiveComponentType.blackboard);

        expect(appProvider.streamingWorkbookContent, isNotEmpty);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.blackboard));
      });

      test('组件切换后activeComponentType正确更新', () {
        appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.blackboard));

        appProvider.setActiveComponentType(ActiveComponentType.notebook);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.notebook));

        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));
      });

      test('快速切换组件类型不会导致状态不一致', () {
        appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.setActiveComponentType(ActiveComponentType.notebook);
        appProvider.setActiveComponentType(ActiveComponentType.none);

        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });
    });

    group('Multiple Content Streaming Tests', () {
      test('可以同时流式更新多个组件的内容', () {
        appProvider.appendToWorkbookContent('作业');
        appProvider.appendToBlackboardContent('黑板');
        appProvider.appendToNotebookContent('笔记');

        expect(appProvider.streamingWorkbookContent, contains('作业'));
        expect(appProvider.streamingBlackboardContent, contains('黑板'));
        expect(appProvider.streamingNotebookContent, contains('笔记'));
      });

      test('流式追加在同一次notifyListeners中完成', () {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        appProvider.appendToWorkbookContent('题目1');
        appProvider.appendToWorkbookContent('\n题目2');

        expect(notifyCount, equals(2));
      });
    });

    group('State Transitions', () {
      test('从none到workbook到none的完整流程', () {
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));

        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));

        appProvider.clearActiveComponentType();
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });

      test('完整workflow模拟：AI创建作业本', () {
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
        expect(appProvider.streamingWorkbookContent, isEmpty);

        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.appendToWorkbookContent('📝 三年级数学练习\n');
        appProvider.appendToWorkbookContent('【题目1】 1+1=?\n');

        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));
        expect(appProvider.streamingWorkbookContent, contains('三年级数学练习'));
        expect(appProvider.streamingWorkbookContent, contains('题目1'));
      });

      test('完整workflow模拟：AI使用黑板讲解', () {
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));

        appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        appProvider.appendToBlackboardContent('分数入门\n');
        appProvider.appendToBlackboardContent('今天学习分数的概念\n');

        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.blackboard));
        expect(appProvider.streamingBlackboardContent, contains('分数入门'));
        expect(appProvider.streamingBlackboardContent, contains('分数的概念'));
      });

      test('完整workflow模拟：用户记录笔记', () {
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));

        appProvider.setActiveComponentType(ActiveComponentType.notebook);
        appProvider.appendToNotebookContent('学习笔记\n');
        appProvider.appendToNotebookContent('- 今天学习了分数\n');
        appProvider.appendToNotebookContent('- 分数由分子和分母组成\n');

        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.notebook));
        expect(appProvider.streamingNotebookContent, contains('学习笔记'));
        expect(appProvider.streamingNotebookContent, contains('分数'));
      });
    });

    group('Edge Cases', () {
      test('设置相同的componentType多次不会出问题', () {
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.setActiveComponentType(ActiveComponentType.workbook);

        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));
      });

      test('清空后再设置新组件类型正常', () {
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.clearAllStreamingContent();

        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));

        appProvider.setActiveComponentType(ActiveComponentType.blackboard);
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.blackboard));
      });

      test('空内容字符串仍然被追加', () {
        appProvider.appendToWorkbookContent('');
        appProvider.appendToWorkbookContent('实际内容');
        expect(appProvider.streamingWorkbookContent, equals('\n实际内容\n'));
      });
    });
  });
}
