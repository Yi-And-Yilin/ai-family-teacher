# UI Refactoring Migration Guide

> **Date:** 2026-04-13  
> **Status:** Superseded by `docs/UI_COMPONENTS.md`  
> **Type:** Architecture Change  
> **Impact:** High - Changes core navigation flow

**Note:** This document describes the migration that was completed on April 2026. The current architecture is documented in `docs/UI_COMPONENTS.md`. This guide is kept for historical reference.

---

## Overview

This document describes the April 2026 UI architecture refactoring that transformed the app from a **multi-tab interface** to a **chat-centric interface** with saved lists for historical content.

---

## What Changed

### Before (Multi-Tab UI)

```
┌──────────────────────────────────────┐
│  [Blackboard] [Workbook] [Notebook] [Chat]  │
├──────────────────────────────────────┤
│                                      │
│   ┌─ Active Tab Content ──────────┐ │
│   │  Blackboard / Workbook /      │ │
│   │  Notebook (standalone pages)  │ │
│   └───────────────────────────────┘ │
│   ┌─ Chat (Bottom Sheet) ────────┐ │
│   │  Messages + Input             │ │
│   └───────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Problems:**
- Users lost context when switching tabs
- AI auto-switched tabs, confusing users
- No easy way to revisit historical content

### After (Chat-Centric UI)

```
┌──────────────────────────────────────┐
│  [Chat] [Saved Blackboards] [Saved Workbooks] [Saved Notebooks] │
├──────────────────────────────────────┤
│                                      │
│   ┌─ Chat (Full Screen) ──────────┐ │
│   │  Messages with inline content │ │
│   │  - Blackboard (B> prefix)     │ │
│   │  - Workbook (tool calls)      │ │
│   │  - Notebook (N> prefix)       │ │
│   │  - Tool call indicators       │ │
│   └───────────────────────────────┘ │
│                                      │
│   OR                                 │
│                                      │
│   ┌─ Saved List View ─────────────┐ │
│   │  - List of historical items   │ │
│   │  - Click → jump to chat       │ │
│   └───────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Benefits:**
- Single context - users never lose track
- All content appears inline in chat
- Historical content easily accessible via saved lists

---

## Migration for Developers

### 1. ComponentType Enum Changed

**Before:**
```dart
enum ComponentType {
  landing,
  blackboard,     // ❌ REMOVED
  workbook,       // ❌ REMOVED
  notebook,       // ❌ REMOVED
  dialog,         // ❌ RENAMED to chat
  blackboardChat, // ❌ REMOVED
}
```

**After:**
```dart
enum ComponentType {
  landing,
  chat,              // ✅ NEW (replaces dialog)
  savedBlackboards,  // ✅ NEW
  savedWorkbooks,    // ✅ NEW
  savedNotebooks,    // ✅ NEW
  settings,          // ✅ NEW
}
```

**Action Required:**
- Search for `ComponentType.blackboard`, `ComponentType.workbook`, `ComponentType.notebook`, `ComponentType.dialog`, `ComponentType.blackboardChat`
- Update to use new enum values

### 2. No More Auto-Switching

**Before:**
```dart
onBlackboardUpdate: (content) {
  appProvider.updateBlackboard([...]);
  appProvider.switchTo(ComponentType.blackboard); // ❌ Auto-switch
}
```

**After:**
```dart
onBlackboardUpdate: (content) {
  appProvider.updateBlackboard([...]);
  // ✅ Stay in chat, don't switch
}
```

**Action Required:**
- Remove all `appProvider.switchTo()` calls from AIService callbacks
- Content should appear inline in chat

### 3. New Saved Lists

**Location:** `lib/widgets/saved_lists.dart`

Three new widgets:
- `SavedBlackboardList` - Shows conversations with blackboard content
- `SavedWorkbookList` - Shows conversations with workbook tool calls
- `SavedNotebookList` - Shows conversations with notebook content

**Usage:**
```dart
ComponentController(
  currentComponent: appProvider.currentComponent,
)
// Routes to saved list views automatically
```

### 4. Loading Historical Conversations

**New Method:** `AppProvider.loadHistoricalConversation(conversationId)`

```dart
// In saved list item click handler:
onTap: () {
  appProvider.loadHistoricalConversation(conversation.id);
  // Switches to chat view with historical messages
}
```

### 5. Blackboard Chat View Deprecated

**File:** `lib/widgets/blackboard_chat_view.dart`

This file is now **orphaned** (not referenced anywhere). The combined blackboard+chat view is replaced by inline content in `dialog_area.dart`.

**Action:**
- Can be safely deleted in future cleanup
- Currently kept for reference only

---

## Testing

### Unit Tests

New tests added:
- `test/ui_refactoring_test.dart` - AppProvider state management
- `test/saved_item_model_test.dart` - SavedItem model serialization

Run tests:
```bash
flutter test test/ui_refactoring_test.dart test/saved_item_model_test.dart
```

### Manual Testing Checklist

- [ ] Landing page quick actions navigate correctly
- [ ] Navigation menu shows correct items
- [ ] Switcher bar works (Chat, Saved Blackboards, Saved Workbooks, Saved Notebooks)
- [ ] AI responses stay in chat (no auto-switching)
- [ ] Blackboard content appears inline (B> prefix)
- [ ] Workbook content appears inline (tool calls)
- [ ] Notebook content appears inline (N> prefix)
- [ ] Saved lists show correct historical items
- [ ] Clicking saved item loads historical conversation
- [ ] All existing features still work (image upload, voice input, etc.)

---

## Documentation Updated

- ✅ `docs/UI_COMPONENTS.md` - Complete rewrite
- ✅ `docs/GENERAL.md` - Architecture overview updated
- ✅ `docs/DATA_MODELS.md` - Added SavedItem model
- ✅ `docs/BUG_FIXES_HISTORY.md` - Added refactoring entry

---

## Common Issues & Solutions

### Issue: App still shows old tabs

**Solution:** Clear app state and restart. The default component is now `chat` instead of `landing`.

### Issue: Blackboard content not appearing

**Solution:** Check that AI response contains `B>` prefix. The streaming parser routes this to `appProvider.appendToBlackboardContent()`.

### Issue: Saved lists empty

**Solution:** Saved lists filter conversations by relevant tool calls. Only conversations that contain blackboard/workbook/notebook content will appear.

### Issue: "setBlackboardWithChatMode is not defined"

**Solution:** This method was replaced by `setBlackboardInlineMode`. Search and replace all occurrences.

---

## Future Work

1. **Delete orphaned files:**
   - `lib/widgets/blackboard_chat_view.dart`
   - Potentially `lib/widgets/blackboard.dart`, `workbook.dart`, `notebook.dart` if no longer needed

2. **Add saved item persistence:**
   - Currently saved lists scan all conversations
   - Consider caching saved items in a separate database table for performance

3. **Improve saved list filtering:**
   - Add date range filters
   - Add search functionality
   - Add tags/categories

4. **Enhanced historical view:**
   - Highlight the specific content that triggered the save
   - Show timeline of content creation within conversation

---

## Questions?

Refer to:
- `docs/UI_COMPONENTS.md` - Detailed UI architecture
- `docs/GENERAL.md` - Overall system design
- `docs/STREAMING_PROTOCOL.md` - How content streams work
