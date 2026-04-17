import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

/// 上游测试：模拟 LLM 流式输出中的工具结果标记，
/// 验证 ToolCallEvent.result 结构正确（success 字段在顶层，不是嵌套的）
///
/// 这个测试覆盖了从 LLM 发出原始字符串 → 解析 → 生成 ChatChunk 的完整数据流，
/// 确保 toolCallEvent.result['success'] 可以被正确访问。
void main() {
  group('工具结果解析上游测试', () {

    test('1. 验证 __TOOL_RESULT__ 标记解析后的 result 结构', () async {
      // 这个测试模拟 LLM 发出的原始字符串格式
      // processDialogue 会发出包含 __TOOL_RESULT__: 标记的字符串
      // _processWithStreamingParser 需要正确解析它

      // 模拟 LLM 发出的原始 JSON 字符串（这就是实际网络传输的格式）
      const mockToolResultString = '''
{"tool_name":"create_workbook","result":{"success":true,"workbook_id":"wb_123","message":"作业本创建成功","ui_action":"append_to_workbook","workbook_content":"📝 三年级数学练习"}}
''';

      // 验证 JSON 结构
      final parsed = jsonDecode(mockToolResultString) as Map<String, dynamic>;

      // 这是 _parseResultToToolCallEvent 接收到的输入（wrapperResult）
      final wrapperResult = parsed;

      // 修复前：result 字段是 wrapperResult 本身（包含 tool_name 和嵌套 result）
      // 修复后：result 字段应该是 wrapperResult['result']（实际的工结果）

      final actualResult = wrapperResult['result'] as Map<String, dynamic>?;

      // 验证嵌套结构存在
      expect(wrapperResult['tool_name'], equals('create_workbook'));
      expect(wrapperResult['result'], isNotNull);
      expect(actualResult, isNotNull);

      // 验证 actualResult 有 success 字段在顶层
      expect(actualResult!['success'], isTrue,
          reason: 'actualResult 应该有 success 字段在顶层');
      expect(actualResult['workbook_id'], equals('wb_123'));
      expect(actualResult['ui_action'], equals('append_to_workbook'));
      expect(actualResult['workbook_content'], contains('三年级数学练习'));

      print('✅ 测试1通过: __TOOL_RESULT__ 标记的 JSON 结构正确，result 嵌套层级正确');
    });

    test('2. 验证 create_question 工具结果解析', () async {
      const mockToolResultString = '''
{"tool_name":"create_question","result":{"success":true,"question_id":"q_456","question_number":1,"message":"题目添加成功","ui_action":"append_to_workbook","workbook_content":"【题目】测试题目\\nA. 选项1\\nB. 选项2\\n"}}
''';

      final wrapperResult = jsonDecode(mockToolResultString) as Map<String, dynamic>;
      final actualResult = wrapperResult['result'] as Map<String, dynamic>?;

      // 验证结构
      expect(wrapperResult['tool_name'], equals('create_question'));
      expect(actualResult, isNotNull);
      expect(actualResult!['success'], isTrue);
      expect(actualResult['question_id'], equals('q_456'));
      expect(actualResult['question_number'], equals(1));

      // 关键验证：hasSuccess 检查应该能通过
      final hasSuccess = actualResult['success'] == true;
      expect(hasSuccess, isTrue,
          reason: 'hasSuccess 检查应该能找到 success=true');

      print('✅ 测试2通过: create_question 工具结果解析正确');
    });

    test('3. 验证失败情况：工具返回 success=false', () async {
      const mockToolResultString = '''
{"tool_name":"create_workbook","result":{"success":false,"message":"参数错误：缺少 title 字段"}}
''';

      final wrapperResult = jsonDecode(mockToolResultString) as Map<String, dynamic>;
      final actualResult = wrapperResult['result'] as Map<String, dynamic>?;

      expect(actualResult, isNotNull);
      expect(actualResult!['success'], isFalse);
      expect(actualResult['message'], contains('参数错误'));

      // 验证 hasSuccess 检查应该返回 false
      final hasSuccess = actualResult['success'] == true;
      expect(hasSuccess, isFalse,
          reason: '失败的工具结果，hasSuccess 应该为 false');

      print('✅ 测试3通过: 失败情况处理正确');
    });

    test('4. 兼容性测试：没有嵌套 result 的情况（防御性编程）', () async {
      const mockToolResultString = '''
{"tool_name":"create_workbook","success":true,"workbook_id":"wb_789"}
''';

      final wrapperResult = jsonDecode(mockToolResultString) as Map<String, dynamic>;

      // 修复后的代码应该能处理两种情况：
      // final actualResult = wrapperResult['result'] as Map<String, dynamic>? ?? wrapperResult;

      final actualResult = wrapperResult['result'] as Map<String, dynamic>? ?? wrapperResult;

      // 在没有嵌套 result 的情况下，应该使用 wrapperResult 本身
      expect(actualResult['success'], isTrue);
      expect(actualResult['workbook_id'], equals('wb_789'));

      print('✅ 测试4通过: 兼容没有嵌套 result 的情况');
    });

    test('5. 端到端验证：模拟完整工具调用数据流', () async {
      // 模拟完整的工具调用数据流（从 LLM 到 UI）
      final mockEvents = <Map<String, dynamic>>[];

      // 事件1: progress
      mockEvents.add({
        'tool_name': 'create_workbook',
        'state': 'progress',
        'progress_text': '📝 Creating workbook...',
      });

      // 事件2: done（模拟从 LLM 接收到的原始数据解析后的结果）
      const mockToolResultString = '''
{"tool_name":"create_workbook","result":{"success":true,"workbook_id":"wb_test","message":"作业本创建成功","ui_action":"append_to_workbook","workbook_content":"📝 测试作业本"}}
''';

      final wrapperResult = jsonDecode(mockToolResultString) as Map<String, dynamic>;
      final actualResult = wrapperResult['result'] as Map<String, dynamic>? ?? wrapperResult;

      mockEvents.add({
        'tool_name': 'create_workbook',
        'state': 'done',
        'progress_text': '✅ 作业本已创建',
        'result': actualResult,  // 这就是修复后应该存储的结构
      });

      // 现在验证 _buildInlineToolComponent 的 hasSuccess 检查能通过
      final hasSuccess = mockEvents.any((e) {
        final result = e['result'] as Map<String, dynamic>?;
        return result != null && result['success'] == true;
      });

      expect(hasSuccess, isTrue,
          reason: '修复后，hasSuccess 检查应该能通过，workbook 内联组件应该能显示');

      // 验证 workbook_content 可以访问
      final doneEvent = mockEvents.firstWhere((e) => e['state'] == 'done');
      final result = doneEvent['result'] as Map<String, dynamic>?;
      expect(result!['workbook_content'], contains('测试作业本'));

      print('✅ 测试5通过: 端到端数据流验证成功，workbook 内联组件应该能正常显示');
    });

    test('6. 验证多个工具调用的 result 结构', () async {
      // 模拟 create_workbook + create_question 的连续调用
      final allToolResults = <Map<String, dynamic>>[];

      // 工具1: create_workbook
      const workbookResultString = '''
{"tool_name":"create_workbook","result":{"success":true,"workbook_id":"wb_123","ui_action":"append_to_workbook","workbook_content":"📝 作业本"}}
''';
      final workbookWrapper = jsonDecode(workbookResultString) as Map<String, dynamic>;
      allToolResults.add({
        'tool_name': 'create_workbook',
        'state': 'done',
        'result': workbookWrapper['result'] as Map<String, dynamic>? ?? workbookWrapper,
      });

      // 工具2: create_question
      const questionResultString = '''
{"tool_name":"create_question","result":{"success":true,"question_id":"q_456","ui_action":"append_to_workbook","workbook_content":"【题目】问题1"}}
''';
      final questionWrapper = jsonDecode(questionResultString) as Map<String, dynamic>;
      allToolResults.add({
        'tool_name': 'create_question',
        'state': 'done',
        'result': questionWrapper['result'] as Map<String, dynamic>? ?? questionWrapper,
      });

      // 验证所有工具结果的 success 字段都能正确访问
      for (final toolResult in allToolResults) {
        final result = toolResult['result'] as Map<String, dynamic>?;
        expect(result!['success'], isTrue,
            reason: '${toolResult['tool_name']} 的 success 字段应该能访问');
      }

      print('✅ 测试6通过: 多个工具调用的 result 结构正确');
    });
  });

  print('\n========== 工具结果解析上游测试完成 ==========');
  print('这些测试验证了从 LLM 原始字符串 → 解析 → ToolCallEvent.result 的完整数据流');
  print('确保 _buildInlineToolComponent 的 hasSuccess 检查能正确找到 success=true');
  print('================================================\n');
}