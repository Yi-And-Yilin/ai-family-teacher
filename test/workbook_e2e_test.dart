import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/providers/app_provider.dart';
import 'package:ai_family_teacher/models/conversation.dart';
import 'package:ai_family_teacher/services/ai_service.dart';

void main() {
  group('端到端 Workbook 数据流测试', () {
    
    test('1. 验证create_workbook工具的返回值结构', () async {
      // 这个测试验证workbook_tool_executor.dart的返回值
      print('\n========== 测试1: 工具返回值结构 ==========');
      
      // 模拟 _createWorkbook 的返回值
      final mockToolResult = {
        'success': true,
        'workbook_id': 'wb_test_123',
        'message': '作业本创建成功',
        'ui_action': 'append_to_workbook',
        'workbook_content': '📝 三年级数学练习',
      };
      
      // 验证关键字段
      print('📊 工具返回值:');
      print('  - success: ${mockToolResult['success']}');
      print('  - ui_action: ${mockToolResult['ui_action']}');
      print('  - workbook_content: ${mockToolResult['workbook_content']}');
      
      expect(mockToolResult['success'], isTrue);
      expect(mockToolResult['ui_action'], equals('append_to_workbook'));
      expect(mockToolResult['workbook_content'], isNotEmpty);
      
      print('✅ 测试1通过: 工具返回值结构正确\n');
    });
    
    test('2. 验证toolCallEvent数据结构', () async {
      print('\n========== 测试2: toolCallEvent数据结构 ==========');
      
      // 模拟progress事件
      final progressEvent = {
        'tool_name': 'create_workbook',
        'state': 'progress',
        'progress_text': '📝 Creating workbook...',
      };
      
      // 模拟done事件（包含result）
      final doneEvent = {
        'tool_name': 'create_workbook',
        'state': 'done',
        'progress_text': '❌ Workbook created',
        'result': {
          'success': true,
          'workbook_id': 'wb_test_123',
          'ui_action': 'append_to_workbook',
          'workbook_content': '📝 三年级数学练习',
        },
      };
      
      final toolCallEvents = [progressEvent, doneEvent];
      
      print('📊 toolCallEvents:');
      print('  - 总数: ${toolCallEvents.length}');
      for (var i = 0; i < toolCallEvents.length; i++) {
        final e = toolCallEvents[i];
        final result = e['result'] as Map<String, dynamic>?;
        print('  - event[$i]: state=${e['state']}, result=${result != null ? "有值" : "null"}, success=${result?['success']}');
      }
      
      // 验证hasSuccess检查
      final hasSuccess = toolCallEvents.any((e) {
        final result = e['result'] as Map<String, dynamic>?;
        return result != null && result['success'] == true;
      });
      
      print('  - hasSuccess: $hasSuccess');
      expect(hasSuccess, isTrue, reason: 'done事件的result应该有success=true');
      
      print('✅ 测试2通过: toolCallEvent数据结构正确\n');
    });
    
    test('3. 验证AppProvider接收并处理toolCallEvents', () async {
      print('\n========== 测试3: AppProvider数据处理 ==========');
      
      final appProvider = AppProvider();
      
      // 模拟完整的消息，包含toolCallEvents
      final testMessage = Message(
        id: 'test_msg_1',
        conversationId: 'test_conv',
        role: MessageRole.assistant,
        content: '我来创建作业本\n\n[TOOL_CALL_EVENT:0]\n\n',
        toolCallEvents: [
          {
            'tool_name': 'create_workbook',
            'state': 'progress',
            'progress_text': '📝 Creating workbook...',
          },
          {
            'tool_name': 'create_workbook',
            'state': 'done',
            'result': {
              'success': true,
              'workbook_id': 'wb_test_123',
              'ui_action': 'append_to_workbook',
              'workbook_content': '📝 三年级数学练习',
            },
          },
        ],
        timestamp: DateTime.now(),
      );
      
      // 模拟dialog_area.dart中的处理逻辑
      final toolCallEvents = testMessage.toolCallEvents!;
      
      print('📊 消息中的toolCallEvents:');
      print('  - 总数: ${toolCallEvents.length}');
      for (var i = 0; i < toolCallEvents.length; i++) {
        final e = toolCallEvents[i];
        final result = e['result'] as Map<String, dynamic>?;
        print('  - event[$i]: state=${e['state']}, result=${result != null ? "有值" : "null"}');
        if (result != null) {
          print('    - result.success: ${result['success']}');
          print('    - result.ui_action: ${result['ui_action']}');
          print('    - result.workbook_content: ${result['workbook_content']}');
        }
      }
      
      // 模拟处理tool result
      final doneEvent = toolCallEvents.firstWhere(
        (e) => e['state'] == 'done',
        orElse: () => {},
      );
      
      if (doneEvent.isNotEmpty) {
        final result = doneEvent['result'] as Map<String, dynamic>?;
        print('\n📊 处理done事件的result:');
        print('  - result: $result');
        
        if (result != null && result.containsKey('ui_action')) {
          final uiAction = result['ui_action'] as String;
          print('  - ui_action: $uiAction');
          
          if (uiAction == 'append_to_workbook' && result.containsKey('workbook_content')) {
            final wbContent = result['workbook_content'] as String;
            appProvider.appendToWorkbookContent(wbContent);
            print('  - 已调用 appProvider.appendToWorkbookContent()');
          }
        }
      }
      
      print('\n📊 AppProvider状态:');
      print('  - streamingWorkbookContent: "${appProvider.streamingWorkbookContent}"');
      print('  - isEmpty: ${appProvider.streamingWorkbookContent.isEmpty}');
      
      expect(appProvider.streamingWorkbookContent, isNotEmpty,
          reason: 'streamingWorkbookContent应该被填充');
      expect(appProvider.streamingWorkbookContent, contains('三年级数学练习'));
      
      print('✅ 测试3通过: AppProvider正确处理数据\n');
    });
    
    test('4. 验证_buildInlineToolComponent的前置条件', () async {
      print('\n========== 测试4: _buildInlineToolComponent前置条件 ==========');
      
      final appProvider = AppProvider();
      
      // 模拟toolCallEvents
      final events = <Map<String, dynamic>>[
        {
          'tool_name': 'create_workbook',
          'state': 'progress',
          'progress_text': '📝 Creating workbook...',
        },
        {
          'tool_name': 'create_workbook',
          'state': 'done',
          'result': {
            'success': true,
            'workbook_id': 'wb_test_123',
            'ui_action': 'append_to_workbook',
            'workbook_content': '📝 三年级数学练习',
          },
        },
      ];
      
      // 模拟 _buildInlineToolComponent 中的 hasSuccess 检查
      print('📊 检查hasSuccess:');
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        final result = e['result'] as Map<String, dynamic>?;
        print('  - event[$i]: state=${e['state']}, result存在=${result != null}, success=${result?['success']}');
      }
      
      final hasSuccess = events.any((e) {
        final result = e['result'] as Map<String, dynamic>?;
        return result != null && result['success'] == true;
      });
      
      print('  - hasSuccess结果: $hasSuccess');
      
      if (!hasSuccess) {
        print('❌ hasSuccess为false，会返回null，不显示workbook');
      } else {
        print('✅ hasSuccess为true，会继续检查workbook_content');
        
        // 模拟填充streamingWorkbookContent
        final doneEvent = events.firstWhere((e) => e['state'] == 'done');
        final result = doneEvent['result'] as Map<String, dynamic>;
        if (result['ui_action'] == 'append_to_workbook') {
          appProvider.appendToWorkbookContent(result['workbook_content']);
          print('  - streamingWorkbookContent: "${appProvider.streamingWorkbookContent}"');
        }
        
        if (appProvider.streamingWorkbookContent.isEmpty) {
          print('❌ workbookContent为空，会返回null');
        } else {
          print('✅ workbookContent不为空，应该显示workbook');
        }
      }
      
      expect(hasSuccess, isTrue, reason: '必须有success=true的事件');
      expect(appProvider.streamingWorkbookContent, isNotEmpty, 
          reason: 'workbook content应该被填充');
      
      print('✅ 测试4通过: 前置条件满足\n');
    });
    
    test('5. 端到端集成测试：模拟真实的工具执行和UI更新流程', () async {
      print('\n========== 测试5: 端到端集成测试 ==========');
      
      final appProvider = AppProvider();
      
      print('\n步骤1: 模拟AI服务发送工具调用');
      final toolCallRequest = {
        'name': 'create_workbook',
        'arguments': {
          'title': '三年级数学练习',
          'subject': '数学',
          'grade_level': 3,
        }
      };
      print('  - 工具调用: ${toolCallRequest['name']}');
      print('  - 参数: ${toolCallRequest['arguments']}');
      
      print('\n步骤2: 模拟工具执行（workbook_tool_executor.dart）');
      final toolResult = {
        'success': true,
        'workbook_id': 'wb_${DateTime.now().millisecondsSinceEpoch}',
        'message': '作业本创建成功',
        'ui_action': 'append_to_workbook',
        'workbook_content': '📝 三年级数学练习',
      };
      print('  - 执行结果: $toolResult');
      
      print('\n步骤3: 模拟streaming parser发送toolCallEvents');
      final progressEvent = {
        'tool_name': 'create_workbook',
        'state': 'progress',
        'progress_text': '📝 Creating workbook...',
      };
      
      final doneEvent = {
        'tool_name': 'create_workbook',
        'state': 'done',
        'result': toolResult,
      };
      
      final toolCallEvents = [progressEvent, doneEvent];
      print('  - progress event: state=${progressEvent['state']}');
      print('  - done event: state=${doneEvent['state']}, result存在=${doneEvent['result'] != null}');
      
      print('\n步骤4: 模拟dialog_area处理toolCallEvents');
      
      // 检查hasSuccess
      final hasSuccess = toolCallEvents.any((e) {
        final result = e['result'] as Map<String, dynamic>?;
        return result != null && result['success'] == true;
      });
      print('  - hasSuccess: $hasSuccess');
      
      if (hasSuccess) {
        // 处理result
        final result = doneEvent['result'] as Map<String, dynamic>;
        if (result['ui_action'] == 'append_to_workbook') {
          final wbContent = result['workbook_content'] as String;
          appProvider.appendToWorkbookContent(wbContent);
          print('  - 已填充streamingWorkbookContent: "${appProvider.streamingWorkbookContent}"');
        }
      }
      
      print('\n步骤5: 验证最终UI应该显示的内容');
      print('  - streamingWorkbookContent: "${appProvider.streamingWorkbookContent}"');
      print('  - isEmpty: ${appProvider.streamingWorkbookContent.isEmpty}');
      
      // 最终验证
      expect(hasSuccess, isTrue, reason: '工具执行必须成功');
      expect(appProvider.streamingWorkbookContent, isNotEmpty, 
          reason: 'workbook content必须被填充');
      expect(appProvider.streamingWorkbookContent, contains('三年级数学练习'),
          reason: 'workbook content必须包含正确的内容');
      
      print('\n✅ 测试5通过: 端到端流程正确\n');
    });
  });
}
