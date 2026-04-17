# Bug Fixes History

> **Last updated:** 2026-04-13 (UI Refactoring)
> **Status:** Deprecated - content moved to `docs/LOGGING_AND_DEBUGGING.md`
> **Source:** Split from LLM_STREAMING_COMMUNICATION_FLOW.md

**Note:** This document is kept for historical reference. The bug fix table and detailed notes have been integrated into `docs/LOGGING_AND_DEBUGGING.md` under "Known Issues & Resolutions".

---

## Major Refactorings

### UI Architecture Refactoring (April 2026)

**Issue:** Users had to navigate between multiple tabs (Blackboard, Workbook, Notebook) to see different content types. AI responses would auto-switch tabs, causing context loss.

**Solution:** 
1. **Chat-centric UI**: All content now appears inline in chat view
2. **Saved Lists**: Former standalone tabs converted to historical content browsers
3. **No auto-switching**: AI responses stay in chat, users maintain context
4. **Historical jump**: Click saved item → load original chat context

**Files Changed:**
- `lib/providers/app_provider.dart` - Updated ComponentType enum, added loadHistoricalConversation()
- `lib/models/saved_item.dart` - New model for saved content items
- `lib/widgets/saved_lists.dart` - New saved list views (blackboard/workbook/notebook)
- `lib/widgets/component_controller.dart` - Updated routing
- `lib/screens/home_screen.dart` - Updated navigation
- `lib/widgets/dialog_area.dart` - Removed auto-switching callbacks
- `docs/UI_COMPONENTS.md` - Updated documentation
- `docs/GENERAL.md` - Updated architecture overview
- `docs/DATA_MODELS.md` - Added SavedItem model

---

## Active Bugs Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | `C>` prefix literal appearing in chat output | SSE chunks split `C>` across boundaries, line-based detection ran on partial text | **Zero-latency state machine**: 2-char lookahead confirms prefix before switching; per-char emit ensures no prefix chars leak |
| 2 | Question displayed twice in workbook | `create_question` tool result appended workbook content in two separate handlers | Removed duplicate `appendToWorkbookContent` call |
| 3 | LLM self-talk mixed into chat without newlines | Multi-round tool-calling concatenated round contents without `\n` separators; `reasoning_content` leaked into `content` | `__THINKING__:` marker isolates reasoning; newlines emitted as `ChatChunk(content: '\n')` |
| 4 | `thinking` field always NULL in database | `updateLastAIMessage()` never received `thinking` parameter | `dialog_area.dart` now collects `thinking` from chunks and passes it |
| 5 | Post-hoc "thinking vs answer" classification | `logResponse()` guessed intent based on prefix presence (unreliable) | Removed entirely; classification is now API-level (`reasoning_content` field) |
| 6 | Log showed real newlines (invisible `\n`) | `RESPONSE_BODY` wrote raw text with actual line breaks | Now displays `\n` as visible escape sequences |
| 7 | Tool call events not displaying in UI | Events collected but only attached to message at stream end; no real-time UI update | Insert `[TOOL_CALL_EVENT:n]` markers in content; update UI on each event |
| 8 | "正在处理..." appearing incorrectly | Round separator (`Fetching response`) has no tool name, parsed as generic event | Filter out events with empty `toolName` |
| 9 | Tool events displayed as separate rows | Each progress/done event created separate UI row | Group events by `toolName`, display as single collapsible row |
| 10 | Too many icons in tool indicators | Tool icon + state icon + expand icon + background | Simplified to: category icon + expand indicator only |

---

## Detailed Fix Notes

### Fix #7: Tool Call Events Not Displaying

**Symptom:** Tool call indicators not appearing in chat UI during or after streaming.

**Root cause:** `toolCallEvents` were collected in `dialog_area.dart` but only attached to the message when `chunk.done` was true. This meant:
1. No real-time display during streaming
2. Events appeared all at once at the end, above the message content

**Solution:**
1. Insert `[TOOL_CALL_EVENT:n]` markers in `fullContent` when events arrive
2. Call `updateLastAIMessage()` on each event for real-time UI update
3. Parse markers in `_buildMessageContent()` and replace with widgets

### Fix #8: "正在处理..." Round Separator

**Symptom:** Generic "正在处理..." indicator appearing between real tool events.

**Root cause:** The `__PROGRESS__:Fetching response` message is a round separator between LLM calls, not a real tool event. It has no tool name, so regex extraction fails and falls back to default text.

**Solution:** Filter out events with empty `toolName`:
```dart
if (toolName.isNotEmpty) {
  // Process only real tool events
}
```

### Fix #9: Tool Events Grouped Incorrectly

**Symptom:** Each tool step (progress, done) displayed as separate row.

**Root cause:** Each `ToolCallEvent` was rendered individually.

**Solution:** Group events by `toolName`:
```dart
final grouped = <String, List<Map<String, dynamic>>>{};
for (final event in events) {
  grouped.putIfAbsent(toolName, () => []).add(event);
}
```

### Fix #10: Too Many Icons

**Symptom:** Tool indicators had 3+ icons (tool icon, state icon, expand icon) plus colored backgrounds.

**Solution:** Simplified to 2 icons only:
- Category icon (📚/✏️/⚙️)
- Expand indicator (▼/▲)

---

## Related Documents

- [LOGGING_AND_DEBUGGING.md](./LOGGING_AND_DEBUGGING.md) - Debugging guide
- [TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md) - Tool call system details
- [STREAMING_PROTOCOL.md](./STREAMING_PROTOCOL.md) - Streaming protocol
