# Tool Call System

> **Last updated:** 2026-04-13
> **Source:** New document for tool calling functionality

---

## Overview

The LLM can call tools to perform actions like creating workbooks, adding questions, and grading answers. Tool calls are executed server-side, with results displayed as collapsible indicators in the chat UI.

---

## Tool Definitions

**File:** `lib/services/workbook_tools.dart`

All tools are defined in `WorkbookTools.allTools`:

```dart
static List<Map<String, dynamic>> get allTools => [
  createWorkbook,    // 创建新的作业本
  createQuestion,    // 创建新题目
  gradeAnswer,       // 批改答案
  gradeWorkbook,     // 批改作业本
  explainSolution,   // 生成讲解
  // ... and more
];
```

### Tool Schema Structure

```dart
static const Map<String, dynamic> createWorkbook = {
  'type': 'function',
  'function': {
    'name': 'create_workbook',
    'description': '创建新的作业本',  // Used as UI headline
    'parameters': {
      'type': 'object',
      'properties': {
        'title': { 'type': 'string', 'description': '作业本标题' },
        'subject': { 'type': 'string', 'enum': ['数学', '语文', '英语', '科学'] },
        'grade_level': { 'type': 'integer', 'description': '年级' },
      },
      'required': ['title'],
    },
  },
};
```

---

## Tool Execution Flow

### 1. LLM Decides to Call Tool

LLM includes `tool_calls` in its streaming response:

```json
{
  "id": "call_00_TjtpiBpnTTlXbysP9ecgY4NM",
  "type": "function",
  "function": {
    "name": "create_workbook",
    "arguments": "{\"title\": \"三年级数学练习\", \"subject\": \"数学\", \"grade_level\": 3}"
  }
}
```

### 2. Progress Event Generated

```dart
yield '__PROGRESS__:Executing tool: create_workbook...';
```

Parsed by `_parseProgressToToolCallEvent()` → `ToolCallEvent(state: progress)`

### 3. Tool Executed

**File:** `lib/services/workbook_tool_executor.dart`

```dart
final executor = WorkbookToolExecutor();
final result = await executor.execute(toolName, args);
```

### 4. Result Event Generated

```dart
yield '__TOOL_RESULT__:${jsonEncode({
  'tool_name': toolName,
  'result': result,
})}';
```

Parsed by `_parseResultToToolCallEvent()` → `ToolCallEvent(state: done)`

### 5. UI Displays Indicator

Events are grouped by tool name and displayed as collapsible widgets.

---

## UI Display Mechanism

### Event Collection

**File:** `lib/widgets/dialog_area.dart`

```dart
final toolCallEvents = <Map<String, dynamic>>[];

await for (final chunk in stream) {
  if (chunk.hasToolCallEvent) {
    final event = chunk.toolCallEvent!;
    // Only process events with tool name (filter out "正在处理..." round separators)
    if (event.toolName.isNotEmpty) {
      toolCallEvents.add({...});
      // Insert marker in content to preserve ordering
      fullContent += '\n\n[TOOL_CALL_EVENT:$toolIndex]\n\n';
      // Update UI in real-time
      await appProvider.updateLastAIMessage(fullContent, toolCallEvents: ...);
    }
  }
}
```

### Event Grouping

Multiple steps of the same tool (progress + done) are grouped into ONE collapsible row:

```dart
// Group events by tool name
final grouped = <String, List<Map<String, dynamic>>>{};
for (final event in events) {
  grouped.putIfAbsent(toolName, () => []).add(event);
}
```

### Rendering

**File:** `lib/widgets/dialog_area.dart` — `_buildGroupedToolCallIndicator()`

```dart
Widget _buildGroupedToolCallIndicator(String toolName, List<Map<String, dynamic>> events) {
  return ExpansionTile(
    leading: Text(_getToolCategoryIcon(toolName)),  // 📚 or ✏️ or ⚙️
    title: Text(_getToolDescription(toolName)),     // "创建新的作业本"
    trailing: Icon(Icons.expand_more),              // Collapse/expand indicator
    children: [/* arguments and results */],
  );
}
```

### Category Icons

| Category | Icon | Tools |
|----------|------|-------|
| Workbook | 📚 | create_workbook, get_workbook, grade_workbook |
| Question | ✏️ | create_question, get_question, update_question |
| Other | ⚙️ | explain_solution, etc. |

---

## Filtering "正在处理..." Events

Round separator messages (`__PROGRESS__:Fetching response`) have NO tool name:

```
[AI_SERVICE] 🔍 解析进度消息: Fetching response
[AI_SERVICE] ⚠️ 未能从进度消息中提取工具名
```

These are filtered out:

```dart
if (toolName.isNotEmpty) {
  // Process real tool events only
}
```

---

## Unit Tests

**File:** `test/tool_call_event_grouping_test.dart`

Tests cover:
- Filtering empty tool name events
- Grouping by tool name
- isFirstEventForTool logic
- Consecutive tool events with no text between
- Performance with 100+ events
- getEventsForTool logic

Run tests:
```bash
flutter test test/tool_call_event_grouping_test.dart
```

---

## Adding a New Tool

1. **Define in `workbook_tools.dart`:**
   ```dart
   static const Map<String, dynamic> myNewTool = {
     'type': 'function',
     'function': {
       'name': 'my_new_tool',
       'description': '我的新工具描述',  // This becomes the UI headline
       'parameters': {...},
     },
   };
   ```

2. **Add to `allTools` list**

3. **Implement in `workbook_tool_executor.dart`:**
   ```dart
   case 'my_new_tool':
     return await _myNewTool(arguments);
   ```

4. **Add description in `dialog_area.dart`:**
   ```dart
   case 'my_new_tool':
     return '我的新工具描述';
   ```

5. **Add category icon if needed:**
   ```dart
   String _getToolCategoryIcon(String toolName) {
     if (toolName.contains('my_category')) return '';
     // ...
   }
   ```

---

## Related Documents

- [STREAMING_PROTOCOL.md](./STREAMING_PROTOCOL.md) - How tool events are streamed
- [UI_COMPONENTS.md](./UI_COMPONENTS.md) - dialog_area rendering
- [DATA_MODELS.md](./DATA_MODELS.md) - ToolCallEvent structure
