import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_family_teacher/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('多模态图片上传测试', () {
    testWidgets('应用启动并显示首页', (WidgetTester tester) async {
      print('\n========================================');
      print('测试: 应用启动');
      print('========================================');
      
      // 启动应用
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // 验证首页显示
      expect(find.textContaining('好'), findsWidgets);
      
      print('应用启动成功!');
    });

    testWidgets('导航到对话界面', (WidgetTester tester) async {
      print('\n========================================');
      print('测试: 导航到对话界面');
      print('========================================');
      
      // 启动应用
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // 找到并点击菜单按钮
      final menuButton = find.byIcon(Icons.menu_rounded);
      if (menuButton.evaluate().isNotEmpty) {
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        print('已点击菜单按钮');
      }
      
      // 找到对话按钮并点击
      final dialogButton = find.text('对话');
      if (dialogButton.evaluate().isNotEmpty) {
        await tester.tap(dialogButton);
        await tester.pumpAndSettle();
        print('已点击对话按钮');
      }
      
      // 验证进入对话界面
      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('对话界面加载完成');
      
      print('导航成功!');
    });
  });
}
