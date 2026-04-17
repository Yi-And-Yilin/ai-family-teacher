# Data Models

> **Last updated:** 2026-04-13 (Added SavedItem model)
> **Source:** Split from LLM_STREAMING_COMMUNICATION_FLOW.md

---

## Overview

This document describes the core data structures used throughout the application.

---

## SavedItem (NEW)

**File:** `lib/models/saved_item.dart`

Represents a saved content item (blackboard, workbook, or notebook) for browsing historical content.

```dart
class SavedItem {
  final String id;
  final String title;
  final String type;                // 'blackboard' | 'workbook' | 'notebook'
  final String conversationId;      // Link to original conversation
  final DateTime createdAt;
  final String? thumbnail;          // Preview text
  final String? description;
}
```

### Properties

| Property | Type | Purpose |
|----------|------|---------|
| `id` | String | Unique identifier |
| `title` | String | Display title (usually from conversation title) |
| `type` | String | Content type: 'blackboard', 'workbook', or 'notebook' |
| `conversationId` | String | Link to the original conversation for historical view |
| `createdAt` | DateTime | When this item was created |
| `thumbnail` | String? | Preview text (first 100 chars of content) |
| `description` | String? | Optional description |

### Methods

| Method | Returns | Purpose |
|--------|---------|---------|
| `get icon` | String | Emoji icon for type (📋/📝/📖) |
| `get typeName` | String | Display name for type (黑板/作业本/笔记本) |
| `toMap()` | Map | Serialize to database format |
| `fromMap()` | SavedItem | Deserialize from database format |

### Usage

```dart
// Create a saved item
final item = SavedItem(
  id: 'item_123',
  title: 'Math Practice Session',
  type: 'workbook',
  conversationId: 'conv_456',
  createdAt: DateTime.now(),
  thumbnail: '我来帮你创建数学练习题...',
);

// Click item → load historical conversation
appProvider.loadHistoricalConversation(item.conversationId);
```

---

## ChatChunk

**File:** `lib/services/ai_service.dart`

Represents a chunk of streamed content from the LLM parser.

```dart
class ChatChunk {
  final String? content;              // No-prefix → chat area
  final String? thinking;             // __THINKING__: → AI reasoning (persisted)
  final String? blackboardContent;    // B> → blackboard
  final String? notebookContent;      // N> → notebook
  final String? progressMessage;      // __PROGRESS__:
  final Map<String, dynamic>? toolResult; // __TOOL_RESULT__:
  final ToolCallEvent? toolCallEvent; // UI display event
  final bool done;                    // __DONE__
}
```

### Properties

| Property | Source | Target |
|----------|--------|--------|
| `content` | Regular text, no prefix | Chat area |
| `thinking` | `__THINKING__:` marker | Persisted to DB, not shown in chat |
| `blackboardContent` | `B>` prefix | Blackboard component |
| `notebookContent` | `N>` prefix | Notebook component |
| `toolResult` | `__TOOL_RESULT__:` marker | Tool execution result |
| `toolCallEvent` | Parsed from progress/result | UI indicator widget |

---

## ToolCallEvent

**File:** `lib/services/ai_service.dart`

Represents a tool call event for UI display.

```dart
class ToolCallEvent {
  final String toolName;                    // e.g., "create_workbook"
  final ToolCallState state;                // progress | done
  final String progressText;                // Display text
  final Map<String, dynamic>? arguments;    // Tool arguments
  final Map<String, dynamic>? result;       // Tool result
}

enum ToolCallState { progress, done }
```

### Event Flow

1. **Progress event**: Generated when tool starts executing
2. **Done event**: Generated when tool completes

Both events are grouped by `toolName` in the UI.

---

## Message

**File:** `lib/models/conversation.dart`

Represents a chat message.

```dart
class Message {
  final String id;
  final String conversationId;
  final MessageRole role;             // system | user | assistant | tool
  final String content;               // May contain [TOOL_CALL_EVENT:n] markers
  final String? thinking;             // AI reasoning process
  final List<Map<String, dynamic>>? toolCalls;  // LLM tool calls
  final String? toolCallId;           // For tool role messages
  final List<Map<String, dynamic>>? toolCallEvents; // UI indicators
  final List<String>? images;         // Base64 images
  final DateTime timestamp;
}
```

### Content Format

The `content` field may contain special markers:

```
我来帮你创建题目！

[TOOL_CALL_EVENT:0]

现在添加题目...

[TOOL_CALL_EVENT:1]

题目准备好了！
```

The UI parser replaces these markers with tool call indicator widgets.

---

## Conversation

**File:** `lib/models/conversation.dart`

Represents a conversation session.

```dart
class Conversation {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

---

## Database Schema

**File:** `lib/services/database_service.dart`

### Messages Table

```sql
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT,
  thinking TEXT,
  tool_calls TEXT,          -- JSON encoded
  tool_call_id TEXT,
  tool_call_events TEXT,    -- JSON encoded
  images TEXT,              -- JSON encoded
  timestamp INTEGER,
  FOREIGN KEY (conversation_id) REFERENCES conversations (id)
);
```

---

## Related Documents

- [STREAMING_PROTOCOL.md](./STREAMING_PROTOCOL.md) - How ChatChunk is generated
- [TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md) - ToolCallEvent lifecycle
- [UI_COMPONENTS.md](./UI_COMPONENTS.md) - How Message is rendered
