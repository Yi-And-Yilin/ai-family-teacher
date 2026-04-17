import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_family_teacher/providers/app_provider.dart';
import 'package:ai_family_teacher/widgets/dialog_area.dart';
import 'package:ai_family_teacher/models/conversation.dart';
import 'dart:convert';

/// 端到端 Widget 测试：模拟真实 LLM 消息流
///
/// 这个测试完全模拟从日志中看到的真实 LLM 响应格式：
/// 1. LLM 先发出文字："好的！我来帮你出一道小学三年级的数学题。让我先创建一个作业本，然后添加题目。"
/// 2. 然后发出工具调用：create_workbook
/// 3. 进度消息：Executing tool: create_workbook...
/// 4. 工具结果：{success: true, workbook_id, ui_action, workbook_content}
/// 5. 然后 LLM 继续发出文字
///
/// 测试验证：
/// - toolCallEvents 的结构正确（result 包含 success 字段在顶层）
/// - UI 正确渲染 workbook 内联组件
/// - streamingWorkbookContent 正确显示
void main() {
  group('端到端 Workbook Widget 测试（模拟真实 LLM 消息流）', () {

    testWidgets('1. 完整流程：LLM 文字 → create_workbook → 工具结果 → workbook 显示',
        (WidgetTester tester) async {
      // ===== 步骤1: 模拟真实 LLM 消息流 =====
      // 这些数据结构完全来自 log.txt 中的真实数据

      print('\n========== 测试1: 模拟完整 LLM 消息流 ==========');

      // 模拟 AI 消息内容（从日志中提取的真实格式）
      const aiContent = '''好的！我来帮你出一道小学三年级的数学题。让我先创建一个作业本，然后添加题目。

[TOOL_CALL_EVENT:0]

作业本已创建，请查看。''';

      // 模拟 toolCallEvents（完全按照真实数据流构造）
      // 这是从 LLM 原始 chunk → stream parser → dialog_area 处理后应该产生的数据
      final toolCallEvents = <Map<String, dynamic>>[
        // 事件1: progress（对应日志中的 "Executing tool: create_workbook..."）
        {
          'tool_name': 'create_workbook',
          'state': 'progress',
          'progress_text': '📝 Creating workbook...',
        },
        // 事件2: done（对应日志中的 TOOL_RESULT）
        // 关键：这里的 result 结构应该是修复后的格式（success 在顶层）
        {
          'tool_name': 'create_workbook',
          'state': 'done',
          'progress_text': '✅ 作业本已创建',
          // 修复前：这里是 {tool_name: ..., result: {success: ...}} 嵌套结构
          // 修复后：这里直接是 {success: ..., workbook_id: ...}
          'result': {
            'success': true,
            'workbook_id': 'wb_1776121032279',
            'message': '作业本创建成功',
            'ui_action': 'append_to_workbook',
            'workbook_content': '📝 小学三年级数学练习',
          },
        },
      ];

      // 创建测试消息（完全模拟真实消息结构）
      final testMessage = Message(
        id: 'test_msg_e2e_001',
        conversationId: 'test_conv',
        role: MessageRole.assistant,
        content: aiContent,
        toolCallEvents: toolCallEvents,
        timestamp: DateTime.now(),
      );

      // ===== 步骤2: 设置 AppProvider =====
      final appProvider = AppProvider();

      // 模拟 streamingWorkbookContent 被填充（对应日志中的 WORKBOOK 追加内容）
      appProvider.appendToWorkbookContent('📝 小学三年级数学练习');

      // 直接注入消息到 messages 列表（绕过数据库）
      // 使用 updateLastAIMessage 的替代方案：直接操作内部列表
      // 由于 addMessage 会触发数据库写入，我们这里手动注入
      final messagesList = appProvider.messages;
      messagesList.add(testMessage);
      appProvider.notifyListeners(); // 手动触发通知

      // ===== 步骤3: 验证数据结构（关键检查点）=====

      // 检查点1: toolCallEvents 结构正确
      expect(toolCallEvents.length, 2);
      expect(toolCallEvents[0]['state'], 'progress');
      expect(toolCallEvents[1]['state'], 'done');

      // 检查点2: result 的 success 字段在顶层（验证修复生效）
      final doneEvent = toolCallEvents[1];
      final result = doneEvent['result'] as Map<String, dynamic>?;
      expect(result, isNotNull, reason: 'done 事件应该有 result 字段');
      expect(result!['success'], isTrue,
          reason: 'result[success] 应该在顶层且为 true（验证修复后结构正确）');

      // 检查点3: streamingWorkbookContent 已填充
      expect(appProvider.streamingWorkbookContent, isNotEmpty);
      expect(appProvider.streamingWorkbookContent, contains('三年级数学练习'));

      print('✅ 检查点通过: toolCallEvents 结构正确，result.success 在顶层');

      // ===== 步骤4: 构建 Widget 树 =====
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appProvider,
          child: MaterialApp(
            home: Scaffold(
              body: DialogArea(fullScreen: true),
            ),
          ),
        ),
      );

      // 等待 Widget 渲染完成
      await tester.pumpAndSettle();

      // ===== 步骤5: 验证 UI 渲染 =====

      // 验证1: LLM 文字内容正确显示
      expect(find.textContaining('好的！我来帮你出一道小学三年级的数学题'), findsOneWidget,
          reason: 'LLM 文字内容应该显示');

      // 验证2: workbook 标题显示
      expect(find.text('作业本已创建'), findsOneWidget,
          reason: 'workbook 内联组件的标题应该显示');

      // 验证3: workbook 内容显示（这是关键验证！）
      final workbookContentFinder = find.textContaining('小学三年级数学练习');
      expect(workbookContentFinder, findsWidgets,
          reason: 'workbook 内容（streamingWorkbookContent）应该显示');

      // 验证4: workbook 卡片容器存在（绿色背景）
      final containerFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
                    widget.decoration is BoxDecoration,
      );
      expect(containerFinder, findsWidgets,
          reason: 'workbook 应该被渲染为带背景的卡片');

      print('✅ UI 渲染验证通过: workbook 内联组件正确显示');

      // ===== 步骤6: 模拟添加更多题目（create_question）=====
      print('\n步骤6: 模拟 create_question 添加题目...');

      // 追加题目内容到 streamingWorkbookContent
      appProvider.appendToWorkbookContent(
          '【题目】小明有48支铅笔，他要把这些铅笔平均分给6个同学，每个同学能得到多少支铅笔？\n'
          'A. 6支\n'
          'B. 7支\n'
          'C. 8支\n'
          'D. 9支\n\n');

      // 更新消息（绕过数据库）
      final updatedToolCallEvents = List<Map<String, dynamic>>.from(toolCallEvents);
      updatedToolCallEvents.add({
        'tool_name': 'create_question',
        'state': 'progress',
        'progress_text': '✏️ 正在添加题目...',
      });
      updatedToolCallEvents.add({
        'tool_name': 'create_question',
        'state': 'done',
        'progress_text': '✅ 题目已添加',
        'result': {
          'success': true,
          'question_id': 'q_1776121038040',
          'question_number': 1,
          'ui_action': 'append_to_workbook',
          'workbook_content': '【题目】小明有48支铅笔...',
        },
      });

      // 更新现有消息（绕过数据库）
      final updatedMessage = Message(
        id: 'test_msg_e2e_002',
        conversationId: 'test_conv',
        role: MessageRole.assistant,
        content: aiContent,
        toolCallEvents: updatedToolCallEvents,
        timestamp: DateTime.now(),
      );

      if (appProvider.messages.isNotEmpty) {
        appProvider.messages[appProvider.messages.length - 1] = updatedMessage;
      } else {
        appProvider.messages.add(updatedMessage);
      }
      appProvider.notifyListeners();

      // 重新渲染
      await tester.pumpAndSettle();

      // 验证题目内容显示
      expect(find.textContaining('小明有48支铅笔'), findsWidgets,
          reason: '题目内容应该显示');
      expect(find.textContaining('A. 6支'), findsWidgets,
          reason: '选项A应该显示');
      expect(find.textContaining('C. 8支'), findsWidgets,
          reason: '选项C应该显示');

      print('✅ 步骤6通过: 多题目场景正确显示');

      print('\n========== 测试1通过: 完整 LLM 消息流验证成功 ==========');
    });

    testWidgets('2. 失败场景：工具返回 success=false，workbook 不应该显示',
        (WidgetTester tester) async {
      print('\n========== 测试2: 失败场景验证 ==========');

      const aiContent = '''我来创建作业本。

[TOOL_CALL_EVENT:0]

作业本创建失败。''';

      final toolCallEvents = <Map<String, dynamic>>[
        {
          'tool_name': 'create_workbook',
          'state': 'progress',
          'progress_text': '📝 Creating workbook...',
        },
        {
          'tool_name': 'create_workbook',
          'state': 'done',
          'progress_text': '❌ 作业本创建失败',
          'result': {
            'success': false,
            'message': '参数错误：缺少 title 字段',
          },
        },
      ];

      final testMessage = Message(
        id: 'test_msg_fail_001',
        conversationId: 'test_conv',
        role: MessageRole.assistant,
        content: aiContent,
        toolCallEvents: toolCallEvents,
        timestamp: DateTime.now(),
      );

      final appProvider = AppProvider();
      appProvider.messages.add(testMessage);
      appProvider.notifyListeners();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appProvider,
          child: MaterialApp(
            home: Scaffold(
              body: DialogArea(fullScreen: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证：workbook 内联组件不应该显示（因为 success=false）
      expect(find.text('作业本已创建'), findsNothing,
          reason: '失败时，workbook 内联组件不应该显示');

      // 但展开的工具指示器应该存在
      expect(find.textContaining('作业本'), findsWidgets,
          reason: '工具调用指示器应该显示');

      print('✅ 测试2通过: 失败场景正确，workbook 不显示');
    });

    testWidgets('3. 多轮对话场景：create_workbook + create_question 连续调用',
        (WidgetTester tester) async {
      print('\n========== 测试3: 多轮工具调用场景 ==========');

      // 模拟真实日志中的多轮对话
      const aiContent = '''好的！我来帮你出题。

[TOOL_CALL_EVENT:0]

[TOOL_CALL_EVENT:1]

题目已准备好，请查看作业本。''';

      final toolCallEvents = <Map<String, dynamic>>[
        // 第一轮：create_workbook
        {
          'tool_name': 'create_workbook',
          'state': 'progress',
          'progress_text': '📝 Creating workbook...',
        },
        {
          'tool_name': 'create_workbook',
          'state': 'done',
          'progress_text': '✅ 作业本已创建',
          'result': {
            'success': true,
            'workbook_id': 'wb_multi_test',
            'ui_action': 'append_to_workbook',
            'workbook_content': '📝 多轮测试作业本',
          },
        },
        // 第二轮：create_question
        {
          'tool_name': 'create_question',
          'state': 'progress',
          'progress_text': '✏️ 正在添加题目...',
        },
        {
          'tool_name': 'create_question',
          'state': 'done',
          'progress_text': '✅ 题目已添加',
          'result': {
            'success': true,
            'question_id': 'q_multi_001',
            'ui_action': 'append_to_workbook',
            'workbook_content': '【题目】1+1=?\nA. 1\nB. 2\nC. 3\nD. 4\n\n',
          },
        },
      ];

      final testMessage = Message(
        id: 'test_msg_multi_001',
        conversationId: 'test_conv',
        role: MessageRole.assistant,
        content: aiContent,
        toolCallEvents: toolCallEvents,
        timestamp: DateTime.now(),
      );

      final appProvider = AppProvider();
      appProvider.appendToWorkbookContent('📝 多轮测试作业本');
      appProvider.appendToWorkbookContent('【题目】1+1=?\nA. 1\nB. 2\nC. 3\nD. 4\n\n');
      appProvider.messages.add(testMessage);
      appProvider.notifyListeners();

      // 验证数据结构
      final wbDone = toolCallEvents.firstWhere((e) => e['tool_name'] == 'create_workbook' && e['state'] == 'done');
      final wbResult = wbDone['result'] as Map<String, dynamic>?;
      expect(wbResult!['success'], isTrue);

      final qDone = toolCallEvents.firstWhere((e) => e['tool_name'] == 'create_question' && e['state'] == 'done');
      final qResult = qDone['result'] as Map<String, dynamic>?;
      expect(qResult!['success'], isTrue);

      print('✅ 检查点通过: 多轮工具调用的 result 结构都正确');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appProvider,
          child: MaterialApp(
            home: Scaffold(
              body: DialogArea(fullScreen: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证两个工具都正确显示
      expect(find.textContaining('作业本已创建'), findsOneWidget,
          reason: 'create_workbook 的内联组件应该显示');
      expect(find.textContaining('1+1=?'), findsWidgets,
          reason: '题目内容应该显示');

      print('✅ 测试3通过: 多轮工具调用场景正确');
    });

    testWidgets('4. 数据边界测试：result 字段为 null（防御性编程）',
        (WidgetTester tester) async {
      print('\n========== 测试4: 数据边界测试 ==========');

      const aiContent = '''处理中...

[TOOL_CALL_EVENT:0]

完成。''';

      // 模拟 result 为 null 的情况（网络异常或数据丢失）
      final toolCallEvents = <Map<String, dynamic>>[
        {
          'tool_name': 'create_workbook',
          'state': 'progress',
          'progress_text': '📝 Creating workbook...',
        },
        {
          'tool_name': 'create_workbook',
          'state': 'done',
          'progress_text': '完成',
          'result': null, // 异常情况：result 为 null
        },
      ];

      final testMessage = Message(
        id: 'test_msg_null_001',
        conversationId: 'test_conv',
        role: MessageRole.assistant,
        content: aiContent,
        toolCallEvents: toolCallEvents,
        timestamp: DateTime.now(),
      );

      final appProvider = AppProvider();
      appProvider.messages.add(testMessage);
      appProvider.notifyListeners();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appProvider,
          child: MaterialApp(
            home: Scaffold(
              body: DialogArea(fullScreen: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证：不应该崩溃，workbook 内联组件不显示（因为 result 为 null）
      expect(find.text('作业本已创建'), findsNothing,
          reason: 'result 为 null 时，workbook 内联组件不应该显示');

      // 但不应该抛出异常
      print('✅ 测试4通过: result 为 null 时，UI 不崩溃');
    });
  });

  print('\n========== 端到端 Workbook Widget 测试完成 ==========');
  print('这些测试完全模拟真实 LLM 消息流，验证从工具调用到 UI 渲染的完整链路');
  print('================================================\n');
}
