import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_family_teacher/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('小学三年级数学题测试', () {
    testWidgets('请帮我出一道小学三年级的数学题', (WidgetTester tester) async {
      print('\n========================================');
      print('测试: 请帮我出一道小学三年级的数学题');
      print('========================================');

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      print('1. 应用启动完成');

      final menuButton = find.byIcon(Icons.menu_rounded);
      if (menuButton.evaluate().isNotEmpty) {
        await tester.tap(menuButton, warnIfMissed: false);
        await tester.pumpAndSettle();
        print('2. 已点击菜单按钮');
      }

      final dialogButton = find.text('对话');
      if (dialogButton.evaluate().isNotEmpty) {
        await tester.tap(dialogButton, warnIfMissed: false);
        await tester.pumpAndSettle();
        print('3. 已点击对话按钮');
      }

      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('4. 进入对话界面');

      print('5. 查找输入框并输入...');
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '请帮我出一道小学三年级的数学题');
      print('   已输入文本');

      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      print('6. 按回车发送...');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      print('   已按回车发送');

      print('7. 等待消息处理(60秒)...');

      bool aiResponded = false;
      bool errorOccurred = false;

      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));

        final ellipsisFinder = find.text('...');
        if (ellipsisFinder.evaluate().isEmpty && i > 0) {
          final errorFinder = find.textContaining('抱歉');
          if (errorFinder.evaluate().isNotEmpty) {
            errorOccurred = true;
            print('   [$i秒] 检测到错误消息');
            break;
          }
          aiResponded = true;
          print('   [$i秒] AI响应完成(省略号消失)');
          break;
        }

        if (i % 10 == 0) {
          print('   [$i秒] 等待中...');
        }
      }

      print('8. 最终状态检查...');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final userTextFinder = find.text('请帮我出一道小学三年级的数学题');
      print('   用户消息: ${userTextFinder.evaluate().isNotEmpty}');
      print('   AI响应: $aiResponded');
      print('   错误: $errorOccurred');

      print('\n========================================');
      print(
          '测试结果: user=${userTextFinder.evaluate().isNotEmpty}, ai=$aiResponded, error=$errorOccurred');
      print('========================================');

      expect(userTextFinder.evaluate().isNotEmpty, true, reason: '用户消息应该显示');
    });
  });
}
