# Streaming Communication Protocol

> **Last updated:** 2026-04-13
> **Source:** Split from LLM_STREAMING_COMMUNICATION_FLOW.md

---

## Overview

This document describes the streaming communication protocol between the Flutter app and LLM providers. It covers the line-prefix protocol, SSE parsing, and real-time content routing.

---

## Line-Prefix Protocol

Defined in `lib/prompts/study_buddy_prompt.dart`:

| Prefix | Target Component | Purpose |
|--------|-----------------|---------|
| *(none)* | **Chat** (default) | Explanations, guidance, encouragement |
| `B>` | Blackboard | Formulas, step-by-step solutions |
| `N>` | Notebook | Study notes, summaries |

**Key changes:**
- `C>` removed — no-prefix lines default to chat
- `W>` decommissioned — workbook content generated through tool calls

---

## Zero-Latency State Machine Parser

**File:** `lib/services/ai_service.dart` — `_processWithStreamingParser()`

### How It Works

**No buffering, no waiting for `\n`.** Each character is evaluated and emitted immediately. A **2-character lookahead prefix buffer** handles prefix confirmation.

```dart
Stream<ChatChunk> _processWithStreamingParser(List<Message> history) async* {
  final prefixBuffer = <String>[];       // holds up to 2 chars for B>/N> confirmation
  RenderTarget currentTarget = RenderTarget.chat;

  await for (final text in processDialogue(history)) {
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];

      // '\n' → reset state, emit newline to chat
      if (ch == '\n') {
        currentTarget = RenderTarget.chat;
        prefixBuffer.clear();
        yield ChatChunk(content: '\n', ...);
        continue;
      }

      if (prefixBuffer.isNotEmpty) {
        // Buffer has 1 char (B/N), waiting for 2nd char to confirm
        prefixBuffer.add(ch);
        if (ch == '>') {
          // Confirmed prefix! Switch target
          switch (prefixBuffer[0]) {
            case 'B': currentTarget = RenderTarget.blackboard; break;
            case 'N': currentTarget = RenderTarget.notebook; break;
          }
          prefixBuffer.clear();
        } else {
          // NOT a prefix (e.g. "Ba" → not B>)
          // Emit buffered chars as chat, re-process current char
          for (final c in prefixBuffer) yield ChatChunk(content: c, ...);
          prefixBuffer.clear();
          i--;  // re-evaluate ch
        }
        continue;
      }

      // Buffer empty — is this char a potential prefix start?
      if (ch == 'B' || ch == 'N') {
        prefixBuffer.add(ch);  // wait for next char to confirm
      } else {
        // Regular char → emit to current target immediately
        yield ChatChunk(content: ch, ...);
      }
    }
  }
}
```

### SSE Chunk Splitting Examples

| SSE Chunk 1 | SSE Chunk 2 | Behavior |
|-------------|-------------|----------|
| `"B"` | `"> formula"` | `B` buffered → `>` confirms → switch to blackboard → `formula` emitted |
| `"Ba"` | `"c"` | `B` buffered → `a` ≠ `>` → `B`+`a` emitted to chat → `c` emitted |
| `"Hello "` | `"B> x=1"` | `Hello ` to chat → `B` buffered → `>` confirms → ` x=1` to blackboard |

---

## Provider Selection

**File:** `lib/services/ai_service.dart` — `processDialogue()`

| Provider | Method | Endpoint | Model |
|----------|--------|----------|-------|
| **GLM (智谱AI)** | `_processWithGLM()` | `open.bigmodel.cn` | `glm-4.7-flash` |
| **DeepSeek** | `_processWithDeepSeek()` | `api.deepseek.com` | `deepseek-chat` |
| **Ollama** | `_processWithOllama()` | `192.168.4.22:11434` | `qwen3.5:9b` |

### GLM / DeepSeek (OpenAI SSE format)

```dart
if (delta['reasoning_content'] != null) {
  yield '__THINKING__:$rc';  // NOT sent to chat area
}
if (delta['content'] != null) {
  yield delta['content'];    // Only formal response
}
```

### Ollama (JSON-lines format)

Ollama does not return `reasoning_content`. All content arrives in `message.content`.

---

## Special Markers

| Marker | Purpose | Handler |
|--------|---------|---------|
| `__THINKING__:` | AI reasoning process | Accumulated into `fullThinking`, persisted to DB |
| `__PROGRESS__:` | Tool execution progress | Parsed to `ToolCallEvent` (progress state) |
| `__TOOL_RESULT__:` | Tool execution result | Parsed to `ToolCallEvent` (done state) |
| `__DONE__` | Stream completion | Ends the stream loop |

---

## Tool Call Event Markers in Content

When tool calls occur, `[TOOL_CALL_EVENT:n]` markers are inserted into the content stream to preserve ordering:

```
我来帮你创建题目！
让我先创建一个作业本。

[TOOL_CALL_EVENT:0]

现在添加题目...

[TOOL_CALL_EVENT:1]

题目准备好了！
```

The UI parser replaces these markers with collapsible indicator widgets.

---

## Error Handling

| Layer | Mechanism |
|-------|-----------|
| **HTTP** | Status code checking |
| **JSON Parse** | Try/catch per line |
| **Tool Execution** | Try/catch per tool |
| **API Key Validation** | `APIConfigService.isConfigValid` |
| **Stream Cancellation** | `_isCancelled` flag |
| **Network Timeout** | VL analysis: 5 min timeout |

---

## Related Documents

- [TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md) - Tool calling details
- [DATA_MODELS.md](./DATA_MODELS.md) - ChatChunk structure
- [LOGGING_AND_DEBUGGING.md](./LOGGING_AND_DEBUGGING.md) - Debugging streaming
