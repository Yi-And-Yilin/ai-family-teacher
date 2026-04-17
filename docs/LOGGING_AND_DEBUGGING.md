# Logging and Debugging

> **Last updated:** 2026-04-13
> **Source:** Split from LLM_STREAMING_COMMUNICATION_FLOW.md

---

## Overview

This document describes the logging system and debugging techniques for the AI Family Teacher application.

---

## Log Format

**File:** `lib/services/ai_service.dart` — `AILogger`

### Standard Format

```
[2026-04-13T10:47:13.171401][ENTRY] 收到用户请求
[2026-04-13T10:47:13.171401][ENTRY] DATA: {"has_images":false,"image_count":0,"history_count":1,"provider":"Ollama"}
[2026-04-13T10:47:28.843914][REQUEST_TOOLS] 可用工具: [create_workbook, create_question, ...]
[2026-04-13T10:47:29.390038][ROUND] === 第 1 轮 API 调用 ===
[2026-04-13T10:47:30.623918][LLM_CHUNK] [Round 1] delta content: "我来"
[2026-04-13T10:47:35.033997][RESPONSE] 收到模型 deepseek-chat 的响应 (39 字符)
[2026-04-13T10:47:35.033997][RESPONSE_SUMMARY] Chat>1行 B>0行 N>0行
[2026-04-13T10:47:35.033997][TOOL_CALL] 第 1 轮检测到 1 个工具调用
[2026-04-13T10:47:35.034996][PROGRESS] Executing tool: create_workbook...
[2026-04-13T10:47:35.035997][TOOL_EXEC] 执行工具: create_workbook
[2026-04-13T10:47:35.069099][TOOL_RESULT] 工具执行结果
```

### Log Categories

| Category | Purpose |
|----------|---------|
| `ENTRY` | User request received |
| `REQUEST` | API request details |
| `LLM_CHUNK` | Streaming chunks from LLM |
| `RESPONSE` | Complete response summary |
| `ROUND` | Multi-round tool calling |
| `TOOL_CALL` | LLM requests tool call |
| `TOOL_EXEC` | Tool execution |
| `PROGRESS` | Tool progress messages |
| `TOOL_RESULT` | Tool execution results |
| `THINKING` | AI reasoning content |

---

## Debug Logging in Components

### dialog_area.dart

```dart
print('[DIALOG_AREA] 🎯 [TOOL_EVENT_RECEIVED] 收到工具事件:');
print('  - toolName: $toolName');
print('  - state: ${event.state.name}');
print('[DIALOG_AREA] 🔔 已插入工具事件标记，索引: $toolIndex');
```

### ai_service.dart

```dart
print('[AI_SERVICE] 🔍 解析进度消息: $progressMsg');
print('[AI_SERVICE] ✓ 提取到工具名: $toolName');
print('[AI_SERVICE] ⚠️ 未能从进度消息中提取工具名');
```

### app_provider.dart

```dart
print('[APP_PROVIDER] 📝 更新最后一条AI消息:');
print('  - content长度: ${content.length}');
print('  - toolCallEvents数量: ${toolCallEvents?.length ?? 0}');
print('[APP_PROVIDER] 🔔 已通知监听器重建UI');
```

---

## Common Debugging Scenarios

### 1. Tool Call Events Not Displaying

**Check:**
```
[DIALOG_AREA] 🎯 [TOOL_EVENT_RECEIVED] 收到工具事件:
  - toolName: create_workbook
  - state: progress
```

If no log appears → Tool events not reaching UI layer.

If log appears but UI doesn't update → Check `updateLastAIMessage` call.

### 2. "正在处理..." Appearing Incorrectly

**Root cause:** Round separator message (`Fetching response`) has no tool name.

**Check log:**
```
[AI_SERVICE] 🔍 解析进度消息: Fetching response
[AI_SERVICE] ⚠️ 未能从进度消息中提取工具名
[AI_SERVICE] 📝 进度显示文字: ⚙️ 正在处理...
```

**Fix:** Filter out events with empty `toolName`.

### 3. Streaming Content Not Appearing

**Check:**
```
[LLM_CHUNK] [Round 1] delta content: "我来"
[APP_PROVIDER] 📝 更新最后一条AI消息:
  - content长度: 1
```

If `LLM_CHUNK` appears but `APP_PROVIDER` doesn't → Stream parsing issue.

### 4. Tool Call Events Grouped Incorrectly

**Run unit tests:**
```bash
flutter test test/tool_call_event_grouping_test.dart
```

**Check grouping logic:**
- `_isFirstEventForTool()` - Should return true only for first event of each tool
- `_getEventsForTool()` - Should return all events for a specific tool

---

## Running with Logging

### Method 1: Command Line

```cmd
cd C:\ai-family-teacher && flutter run -d windows > log.txt 2>&1
```

### Method 2: Batch Script

```cmd
run_with_logging.bat
```

---

## Unit Tests

**Test file:** `test/tool_call_event_grouping_test.dart`

```bash
flutter test test/tool_call_event_grouping_test.dart
```

**Coverage:**
- Filtering empty tool name events
- Grouping by tool name
- isFirstEventForTool logic
- Consecutive tool events with no text
- Performance with 100+ events

---

## Known Issues & Resolutions

This section documents past issues and their fixes for reference.

| # | Issue | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | `C>` prefix literal appearing in chat | SSE chunks split `C>` across boundaries | Zero-latency state machine with 2-char lookahead |
| 2 | Question displayed twice in workbook | Duplicate `appendToWorkbookContent` call | Removed duplicate call |
| 3 | LLM self-talk mixed into chat | Multi-round concatenation without `\n` | `__THINKING__:` marker isolates reasoning |
| 4 | `thinking` field always NULL | `updateLastAIMessage()` never received parameter | Now collects `thinking` from chunks |
| 5 | Post-hoc "thinking vs answer" classification | Guessed based on prefix presence | Removed; now API-level classification |
| 6 | Log showed invisible `\n` | Raw text with actual line breaks | Now displays `\n` as visible escape sequences |
| 7 | Tool call events not displaying in UI | Events only attached at stream end | Insert `[TOOL_CALL_EVENT:n]` markers in content |
| 8 | "正在处理..." appearing incorrectly | Round separator has no tool name | Filter out events with empty `toolName` |
| 9 | Tool events displayed as separate rows | Each event created separate UI row | Group events by `toolName` |
| 10 | Too many icons in tool indicators | 3+ icons plus backgrounds | Simplified to category icon + expand indicator |

For detailed fix notes, see [BUG_FIXES_HISTORY.md](./BUG_FIXES_HISTORY.md) (historical reference).

---

## Related Documents

- [GENERAL.md](./GENERAL.md) - Quick reference
- [TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md) - Tool call flow
- [BUG_FIXES_HISTORY.md](./BUG_FIXES_HISTORY.md) - Historical bug fixes (deprecated, content moved here)
