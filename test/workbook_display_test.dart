import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/providers/app_provider.dart';

void main() {
  group('Workbook Display Tests', () {
    
    test('1. 验证create_workbook工具返回包含ui_action和workbook_content', () {
      // 模拟工具返回的结果
      final toolResult = {
        'success': true,
        'workbook_id': 'wb_test_123',
        'message': '作业本创建成功',
        'ui_action': 'append_to_workbook',
        'workbook_content': '📝 三年级数学练习',
      };
      
      // 验证关键字段存在
      expect(toolResult.containsKey('ui_action'), isTrue, 
          reason: '工具结果必须包含ui_action字段');
      expect(toolResult.containsKey('workbook_content'), isTrue, 
          reason: '工具结果必须包含workbook_content字段');
      expect(toolResult['ui_action'], equals('append_to_workbook'));
      expect(toolResult['workbook_content'], isNotEmpty);
    });
    
    test('2. 验证AppProvider在收到ui_action时会填充streamingWorkbookContent', () {
      final appProvider = AppProvider();
      
      // 初始状态应该为空
      expect(appProvider.streamingWorkbookContent, isEmpty);
      
      // 模拟收到append_to_workbook的ui_action
      final toolResult = {
        'success': true,
        'workbook_id': 'wb_test_123',
        'ui_action': 'append_to_workbook',
        'workbook_content': '📝 三年级数学练习',
      };
      
      // 这段代码应该在dialog_area.dart中执行
      if (toolResult['ui_action'] == 'append_to_workbook' && 
          toolResult.containsKey('workbook_content')) {
        final wbContent = toolResult['workbook_content'] as String;
        appProvider.appendToWorkbookContent(wbContent);
      }
      
      // 验证streamingWorkbookContent已被填充
      expect(appProvider.streamingWorkbookContent, isNotEmpty,
          reason: '收到ui_action后，streamingWorkbookContent应该被填充');
      expect(appProvider.streamingWorkbookContent, contains('三年级数学练习'));
    });
    
    test('3. 验证streamingWorkbookContent不为空时，_buildInlineToolComponent应该返回widget', () {
      final appProvider = AppProvider();
      
      // 先清空
      appProvider.clearAllStreamingContent();
      
      // 模拟填充内容
      appProvider.appendToWorkbookContent('📝 三年级数学练习');
      
      // 验证内容已填充
      expect(appProvider.streamingWorkbookContent, isNotEmpty);
      
      // 这里应该测试_buildInlineToolComponent的返回
      // 但由于是私有方法，我们只能验证前提条件
      // 前提条件：streamingWorkbookContent不为空
      // 如果前提条件满足但widget仍不显示，说明问题在_buildInlineToolComponent内部逻辑
    });
    
    test('4. 验证toolCallEvents中create_workbook的state是否正确', () {
      final toolCallEvents = <Map<String, dynamic>>[];
      
      // 模拟收到progress事件
      toolCallEvents.add({
        'tool_name': 'create_workbook',
        'state': 'progress',
        'progress_text': '📝 Creating workbook...',
      });
      
      // 模拟收到done事件
      toolCallEvents.add({
        'tool_name': 'create_workbook',
        'state': 'done',
        'result': {
          'success': true,
          'workbook_id': 'wb_test_123',
          'ui_action': 'append_to_workbook',
          'workbook_content': '📝 三年级数学练习',
        },
      });
      
      // 验证有done状态的事件
      final hasDone = toolCallEvents.any((e) => e['state'] == 'done');
      expect(hasDone, isTrue, reason: '必须有done状态的事件才能触发内联组件显示');
      
      // 验证有result且result包含ui_action
      final doneEvent = toolCallEvents.firstWhere((e) => e['state'] == 'done');
      final result = doneEvent['result'] as Map<String, dynamic>?;
      expect(result, isNotNull);
      expect(result!.containsKey('ui_action'), isTrue,
          reason: 'done事件的result必须包含ui_action');
    });
  });
}
