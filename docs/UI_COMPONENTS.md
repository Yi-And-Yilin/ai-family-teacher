# UI Components

> **Last updated:** 2026-04-14
> **Source:** Updated to reflect new top-bottom split layout design

---

## Overview

This document describes the UI component architecture. The chat page uses a **top-bottom split layout**: when AI generates content via workbook/blackboard/notebook tools, the dedicated component appears at the top (40-50% height) and the chat continues below. The former standalone component pages have been converted into **Saved Lists** for accessing historical content.

---

## Component Structure

```
┌─────────────────────────────────────────────────────────┐
│                    Home Screen                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Top Navigation Bar                    │  │
│  │  [Chat] [Saved Blackboards] [Saved Workbooks]     │  │
│  │  [Saved Notebooks]                                │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │           Component Controller                     │  │
│  │  Routes to chat or saved list views              │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  MAIN VIEW: Chat with Split Layout                      │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Top Component Area (draggable, ~45% default)    │  │
│  │  - WorkbookWidget (paper style, red margin)      │  │
│  │  - BlackboardWidget (dark green, chalk texture)  │  │
│  │  - NotebookWidget (spiral binding, grid paper)   │  │
│  ├───────────────────────────────────────────────────┤  │
│  │  Draggable Divider (shows %, double-tap toggle)  │  │
│  ├───────────────────────────────────────────────────┤  │
│  │  Bottom Chat Area                                 │  │
│  │  - Message list with tool call indicators         │  │
│  │  - Input field                                    │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  SUBTITLE MODE (when component dragged to ≥85%):       │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Component Fullscreen (~90%)                      │  │
│  ├───────────────────────────────────────────────────┤  │
│  │  [▼] [msg1] [msg2] ... [📤]  ← 80pt subtitle bar │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  SAVED LIST VIEWS:                                      │
│  ┌───────────────────────────────────────────────────┐  │
│  │  SavedBlackboardList / SavedWorkbookList /        │  │
│  │  SavedNotebookList                                │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Key Design Features

### Split View Behavior

1. **Default Ratio**: 45% component area, 55% chat area
2. **Draggable Divider**: Users can drag to adjust ratio (10% - 90%)
3. **Double-tap Toggle**: Double-tap divider to switch between 45% and 90%
4. **Subtitle Mode**: When component area ≥ 85%, chat becomes a slim bottom bar showing recent messages with an input icon
5. **Real-time Updates**: Component content streams in as AI generates it

### Component Detection

The layout automatically detects which component to show based on `streamingBlackboardContent`, `streamingWorkbookContent`, and `streamingNotebookContent` in AppProvider.

---

## component_chat_layout.dart

**Path:** `lib/widgets/component_chat_layout.dart`

The split view layout controller. Wraps `DialogArea` and shows the appropriate component above when streaming content is active.

### Key Logic

The `activeComponentType` is set **externally** by `dialog_area.dart` when streaming callbacks fire (not derived from streaming content):

```dart
// In dialog_area.dart streaming callbacks:
if (chunk.hasBlackboardContent) {
  appProvider.appendToBlackboardContent(chunk.blackboardContent!);
  appProvider.setActiveComponentType(ActiveComponentType.blackboard);
}
```

The layout widget uses `appProvider.activeComponentType` directly to determine which component to display.

### Subtitle Mode

When `_splitRatio >= 0.85`:
- Component takes most of the screen (~90%)
- Chat appears as a 80pt bottom bar with:
  - Collapse button (returns to 45%)
  - Horizontal scrolling message chips
  - Send icon (returns to 45%)

---

## component_controller.dart

**Path:** `lib/widgets/component_controller.dart`

Routes to the appropriate view based on `currentComponent`. For `ComponentType.chat`, it now wraps `DialogArea` with `ComponentChatLayout`:

```dart
case ComponentType.chat:
  return ComponentChatLayout(
    chatWidget: const DialogArea(fullScreen: true),
  );
```

---

## dialog_area.dart

**Path:** `lib/widgets/dialog_area.dart`

The main chat component. Handles:
- Message list rendering
- User input (text, images, voice)
- Streaming AI responses
- Tool call indicator display
- Sets `activeComponentType` when streaming content arrives

### Key Streaming Callbacks

```dart
// 处理黑板内容
if (chunk.hasBlackboardContent) {
  appProvider.appendToBlackboardContent(chunk.blackboardContent!);
  appProvider.setActiveComponentType(ActiveComponentType.blackboard);
}

// 处理笔记本内容
if (chunk.hasNotebookContent) {
  appProvider.appendToNotebookContent(chunk.notebookContent!);
  appProvider.setActiveComponentType(ActiveComponentType.notebook);
}

// 处理作业本内容
if (uiAction == 'append_to_workbook' && toolResult.containsKey('workbook_content')) {
  appProvider.appendToWorkbookContent(wbContent);
  appProvider.setActiveComponentType(ActiveComponentType.workbook);
}
```

---

## Component Widgets

### blackboard.dart

**Path:** `lib/widgets/blackboard.dart`

- Full blackboard-style component with chalk texture
- Real-time streaming content display (supports LaTeX via `flutter_math_fork`)
- User drawing layer (touch input for chalk strokes)
- Color toolbar (white, yellow, pink)
- Used in split view when `streamingBlackboardContent` is active

### workbook.dart

**Path:** `lib/widgets/workbook.dart`

- Paper-style component with horizontal lines and red margin
- AI grading marks (✓/✗/circle/text) via `_WorkbookMarkPainter`
- Displays `streamingWorkbookContent`
- Used in split view when `streamingWorkbookContent` is active

### notebook.dart

**Path:** `lib/widgets/notebook.dart`

- Spiral binding effect on left side
- Grid paper background
- User note input (controlled by `appProvider.updateNoteContent()`)
- Used in split view when `streamingNotebookContent` is active

---

## Saved Lists

**Path:** `lib/widgets/saved_lists.dart`

Three list views for browsing historical content. These replaced the former standalone component pages.

### SavedBlackboardList
- Shows conversations with blackboard content (B> prefix)
- Click → Load historical conversation in Chat view

### SavedWorkbookList
- Shows conversations with workbook tool calls
- Click → Load historical conversation in Chat view

### SavedNotebookList
- Shows conversations with notebook content (N> prefix)
- Click → Load historical conversation in Chat view

---

## State Management

**File:** `lib/providers/app_provider.dart`

### Key State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `messages` | `List<Message>` | Chat history |
| `currentComponent` | `ComponentType` | Active view |
| `streamingBlackboardContent` | `String` | Streaming blackboard text |
| `streamingWorkbookContent` | `String` | Streaming workbook text |
| `streamingNotebookContent` | `String` | Streaming notebook text |
| `activeComponentType` | `ActiveComponentType` | Which component to show in split view |

### Component Types

```dart
enum ComponentType {
  landing,           // Welcome screen
  chat,              // Main chat (default)
  savedBlackboards,  // Saved blackboard history list
  savedWorkbooks,     // Saved workbook history list
  savedNotebooks,    // Saved notebook history list
  settings,          // Settings page
}

enum ActiveComponentType {
  none,
  blackboard,
  workbook,
  notebook,
}
```

### Key Methods

| Method | Purpose |
|--------|---------|
| `setActiveComponentType(type)` | Set which component to show in split view |
| `clearActiveComponentType()` | Clear active component |
| `clearAllStreamingContent()` | Clear all streaming content and reset component type |

---

## Navigation Flow

### User Actions

```
HomeScreen
  |
  +-- Quick Action Card or Nav Menu
  |     |
  |     +-- appProvider.switchTo(ComponentType.chat)
  |     +-- appProvider.switchTo(ComponentType.savedBlackboards)
  |     +-- appProvider.switchTo(ComponentType.savedWorkbooks)
  |     +-- appProvider.switchTo(ComponentType.savedNotebooks)
  |
  +-- Saved List Item Click
        |
        +-- appProvider.loadHistoricalConversation(conversationId)
```

### AI Actions (Split View Activation)

```
AIService receives AI response with streaming content
  |
  +-- setActiveComponentType(ActiveComponentType.blackboard)
  |     → ComponentChatLayout shows BlackboardWidget at top
  |
  +-- setActiveComponentType(ActiveComponentType.workbook)
  |     → ComponentChatLayout shows WorkbookWidget at top
  |
  +-- setActiveComponentType(ActiveComponentType.notebook)
        → ComponentChatLayout shows NotebookWidget at top
```

---

## Related Documents

- [STREAMING_PROTOCOL.md](./STREAMING_PROTOCOL.md) - How content streams to UI
- [TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md) - Tool call indicator details
- [DATA_MODELS.md](./DATA_MODELS.md) - Message and ChatChunk structures
- [GENERAL.md](./GENERAL.md) - Overall architecture overview
- [UI_REFACTORING_MIGRATION_GUIDE.md](./UI_REFACTORING_MIGRATION_GUIDE.md) - Historical migration guide (April 2026)

---

## Appendix: Migration History

### April 2026 UI Refactoring Summary

**Before:** Multi-tab UI with separate Blackboard, Workbook, Notebook, and Chat tabs. AI would auto-switch between tabs.

**After:** Chat-centric UI with split-view layout. When AI calls tools, the top area shows the dedicated component while chat continues below. Historical content accessible via Saved Lists.

**Key Changes:**
- `ComponentType.blackboard/workbook/notebook` → replaced by `savedBlackboards/savedWorkbooks/savedNotebooks`
- AI no longer auto-switches tabs
- Content displayed inline via split-view layout

**Orphaned File:**
- `lib/widgets/blackboard_chat_view.dart` - deprecated, not referenced, can be deleted