import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tool Call Event Grouping Logic Tests', () {
    // 模拟 toolCallEvents 数据结构
    final events = [
      {'tool_name': 'create_workbook', 'state': 'progress', 'progress_text': 'Creating workbook...'},
      {'tool_name': 'create_workbook', 'state': 'done', 'progress_text': 'Workbook created', 'result': {'success': true}},
      {'tool_name': '', 'state': 'progress', 'progress_text': '正在处理...'}, // 无工具名事件
      {'tool_name': 'create_question', 'state': 'progress', 'progress_text': 'Adding question...'},
      {'tool_name': 'create_question', 'state': 'done', 'progress_text': 'Question added', 'result': {'success': true}},
      {'tool_name': '', 'state': 'progress', 'progress_text': '正在处理...'}, // 无工具名事件
    ];

    test('Filter out events with empty tool name', () {
      final filtered = events.where((e) => (e['tool_name'] as String? ?? '').isNotEmpty).toList();
      expect(filtered.length, 4); // 应该过滤掉2个无工具名事件
      expect(filtered.any((e) => (e['tool_name'] as String).isEmpty), false);
    });

    test('Group events by tool name', () {
      final filtered = events.where((e) => (e['tool_name'] as String? ?? '').isNotEmpty).toList();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final event in filtered) {
        final toolName = event['tool_name'] as String;
        grouped.putIfAbsent(toolName, () => []).add(event);
      }
      
      expect(grouped.length, 2); // create_workbook 和 create_question
      expect(grouped['create_workbook']!.length, 2); // progress + done
      expect(grouped['create_question']!.length, 2); // progress + done
    });

    test('Check isFirstEventForTool logic', () {
      bool isFirstEventForTool(List<Map<String, dynamic>> events, String toolName, int currentIndex) {
        for (int i = 0; i < currentIndex; i++) {
          if ((events[i]['tool_name'] as String? ?? '') == toolName) {
            return false;
          }
        }
        return true;
      }

      final filtered = events.where((e) => (e['tool_name'] as String? ?? '').isNotEmpty).toList();
      
      // 第一个 create_workbook 事件应该是 isFirst
      expect(isFirstEventForTool(filtered, 'create_workbook', 0), true);
      // 第二个 create_workbook 事件不应该是 isFirst
      expect(isFirstEventForTool(filtered, 'create_workbook', 1), false);
      // 第一个 create_question 事件应该是 isFirst
      expect(isFirstEventForTool(filtered, 'create_question', 2), true);
      // 第二个 create_question 事件不应该是 isFirst
      expect(isFirstEventForTool(filtered, 'create_question', 3), false);
    });

    test('Handle consecutive tool events with no text between', () {
      // 模拟连续两个工具事件之间没有文本内容的情况
      final contentWithMarkers = '\n\n[TOOL_CALL_EVENT:0]\n\n\n\n[TOOL_CALL_EVENT:1]\n\n';
      final pattern = RegExp(r'\n\n\[TOOL_CALL_EVENT:(\d+)\]\n\n');
      final matches = pattern.allMatches(contentWithMarkers).toList();
      
      expect(matches.length, 2);
      // 第一个标记后没有文本，第二个标记前也没有文本
      // 解析时应该能正确处理
    });

    test('Performance test: large number of events', () {
      // 生成大量事件测试性能
      final largeEvents = <Map<String, dynamic>>[];
      for (int i = 0; i < 100; i++) {
        largeEvents.add({'tool_name': 'tool_$i', 'state': 'progress'});
        largeEvents.add({'tool_name': 'tool_$i', 'state': 'done'});
      }

      final filtered = largeEvents.where((e) => (e['tool_name'] as String? ?? '').isNotEmpty).toList();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final event in filtered) {
        final toolName = event['tool_name'] as String;
        grouped.putIfAbsent(toolName, () => []).add(event);
      }
      
      expect(grouped.length, 100);
      expect(grouped['tool_0']!.length, 2);
      expect(grouped['tool_99']!.length, 2);
    });

    test('Get events for specific tool', () {
      List<Map<String, dynamic>> getEventsForTool(List<Map<String, dynamic>> events, String toolName) {
        return events.where((e) => (e['tool_name'] as String? ?? '') == toolName).toList();
      }

      final filtered = events.where((e) => (e['tool_name'] as String? ?? '').isNotEmpty).toList();
      final workbookEvents = getEventsForTool(filtered, 'create_workbook');
      final questionEvents = getEventsForTool(filtered, 'create_question');
      
      expect(workbookEvents.length, 2);
      expect(questionEvents.length, 2);
      expect(workbookEvents.every((e) => e['tool_name'] == 'create_workbook'), true);
      expect(questionEvents.every((e) => e['tool_name'] == 'create_question'), true);
    });
  });
}
