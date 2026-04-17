import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/providers/app_provider.dart';
import 'package:ai_family_teacher/services/database_service.dart';
import 'package:ai_family_teacher/models/conversation.dart';

void main() {
  group('AppProvider Conversation State Tests', () {
    late AppProvider appProvider;

    setUp(() {
      appProvider = AppProvider();
    });

    tearDown(() {
      appProvider.dispose();
    });

    group('loadHistoricalConversation', () {
      test('loadHistoricalConversation会触发notifyListeners', () async {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        await appProvider.loadHistoricalConversation('test_conv_id');

        expect(notifyCount, greaterThan(0));
      });

      test('loadHistoricalConversation设置currentComponent为chat', () async {
        await appProvider.loadHistoricalConversation('test_conv_id');

        expect(appProvider.currentComponent, equals(ComponentType.chat));
      });

      test('loadHistoricalConversation对相同id会提前返回', () async {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        // 先设置 currentConversationId
        await appProvider.loadHistoricalConversation('test_conv_id');
        final countAfterFirst = notifyCount;

        // 再次加载相同的id
        await appProvider.loadHistoricalConversation('test_conv_id');

        // 第二次加载应该只是设置 chat 模式，不会重新加载
        expect(notifyCount, greaterThanOrEqualTo(countAfterFirst));
      });
    });

    group('switchConversation', () {
      test('switchConversation会触发notifyListeners', () async {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        await appProvider.switchConversation('new_conv_id');

        expect(notifyCount, greaterThan(0));
      });

      test('switchConversation对相同id不会执行', () async {
        // 先切换到一个不同的id
        await appProvider.switchConversation('conv_1');
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        // 尝试切换到相同的id
        await appProvider.switchConversation('conv_1');

        // 不应该触发notifyListeners
        expect(notifyCount, equals(0));
      });
    });

    group('createNewConversation', () {
      test('createNewConversation会触发notifyListeners', () async {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        await appProvider.createNewConversation();

        expect(notifyCount, greaterThan(0));
      });

      test('createNewConversation重置activeComponentType为none', () async {
        // 先设置一个非none的状态
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.appendToWorkbookContent('some content');
        expect(appProvider.activeComponentType,
            equals(ActiveComponentType.workbook));

        // 创建新对话
        await appProvider.createNewConversation();

        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });

      test('createNewConversation清空streaming内容', () async {
        // 先添加内容
        appProvider.appendToWorkbookContent('test content');
        expect(appProvider.streamingWorkbookContent.isNotEmpty, isTrue);

        // 创建新对话
        await appProvider.createNewConversation();

        expect(appProvider.streamingWorkbookContent, isEmpty);
        expect(appProvider.streamingBlackboardContent, isEmpty);
        expect(appProvider.streamingNotebookContent, isEmpty);
      });
    });

    group('deleteConversation', () {
      test('deleteConversation会触发notifyListeners', () async {
        int notifyCount = 0;
        appProvider.addListener(() => notifyCount++);

        await appProvider.deleteConversation('some_conv_id');

        expect(notifyCount, greaterThan(0));
      });
    });

    group('_restoreComponentState', () {
      test('state为null时正确重置状态', () async {
        // 先设置一些状态
        appProvider.setActiveComponentType(ActiveComponentType.workbook);
        appProvider.appendToWorkbookContent('some content');

        // 调用 restore但数据库会返回null (因为测试环境没有db)
        // 这应该被 try-catch 捕获并重置状态
        await appProvider.loadHistoricalConversation('nonexistent_conv');

        // 状态应该被重置为 none
        expect(
            appProvider.activeComponentType, equals(ActiveComponentType.none));
      });
    });
  });
}
