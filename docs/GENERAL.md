# AI Family Teacher - General Documentation

> **Project:** 小书童 (AI Family Teacher) - AI-powered learning companion for students
> **Last updated:** 2026-04-13 (UI Refactoring)

---

## Overview

AI Family Teacher is a Flutter-based educational application that provides AI-powered tutoring for primary school students. The app features real-time streaming communication with LLMs, interactive blackboard, workbook management, and study notes.

### Key Features

- **Real-time Streaming Chat**: Stream responses from LLMs (GLM, DeepSeek, Ollama) with zero-latency parsing
- **Chat-Centric UI**: All content (blackboard, workbook, notebook) appears inline in chat - no tab switching
- **Saved Lists**: Browse historical blackboard, workbook, and notebook content with one-click jump to original chat context
- **Tool Calling System**: LLM can create workbooks, add questions, grade answers via function calling
- **Multimodal Support**: Image analysis for homework help
- **Bilingual**: Chinese and English interface

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Provider (ChangeNotifier) |
| Database | SQLite (sqflite) |
| LLM Providers | GLM (智谱AI), DeepSeek, Ollama |
| Markdown | flutter_markdown |
| Math Rendering | flutter_math_fork (LaTeX) |

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│                                                              │
│  MAIN: Chat with Split View (ComponentChatLayout)           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Top Component Area (when AI calls tools):          │  │
│  │  - BlackboardWidget (B> prefix content)              │  │
│  │  - WorkbookWidget (tool call results)               │  │
│  │  - NotebookWidget (N> prefix content)                │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  Bottom: DialogArea (Messages + Input)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  SAVED LISTS:                                               │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │Saved         │ │Saved         │ │Saved         │       │
│  │Blackboards   │ │Workbooks     │ │Notebooks     │       │
│  └──────────────┘ └──────────────┘ └──────────────┘       │
│                            │                                 │
│                     AppProvider (State)                      │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ AIService    │  │ RAGService   │  │ ToolExecutor     │  │
│  │ (Streaming)  │  │ (Syllabus)   │  │ (Workbook CRUD)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│                    External Providers                        │
│  GLM (智谱AI) │ DeepSeek │ Ollama (local)                   │
└──────────────────────────────────────────────────────────────┘
```

---

## Documentation Index

| Document | Purpose | Key Topics |
|----------|---------|------------|
| **[STREAMING_PROTOCOL.md](./STREAMING_PROTOCOL.md)** | How LLM responses stream to UI | Line-prefix protocol (B>/N>), SSE parsing, zero-latency state machine |
| **[TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md)** | LLM function calling | Tool definitions, execution flow, UI indicators |
| **[UI_COMPONENTS.md](./UI_COMPONENTS.md)** | Frontend component design | Chat-centric UI, saved lists, tool call indicators |
| **[DATA_MODELS.md](./DATA_MODELS.md)** | Data structures | ChatChunk, Message, Conversation, ToolCallEvent, SavedItem |
| **[LOGGING_AND_DEBUGGING.md](./LOGGING_AND_DEBUGGING.md)** | Debugging guide | Log format, troubleshooting, common issues |
| **[BUG_FIXES_HISTORY.md](./BUG_FIXES_HISTORY.md)** | Historical bug fixes | Past issues and solutions |

---

## Quick Start

### For New Developers

1. **Understand the flow**: Read [STREAMING_PROTOCOL.md](./STREAMING_PROTOCOL.md) first
2. **Learn tool calling**: Read [TOOL_CALL_SYSTEM.md](./TOOL_CALL_SYSTEM.md)
3. **Explore UI**: Read [UI_COMPONENTS.md](./UI_COMPONENTS.md)

### Common Tasks

| Task | Document | Section |
|------|----------|---------|
| Add new LLM provider | STREAMING_PROTOCOL.md | Provider Selection |
| Add new tool | TOOL_CALL_SYSTEM.md | Tool Definition |
| Modify chat UI | UI_COMPONENTS.md | dialog_area.dart |
| Debug streaming issues | LOGGING_AND_DEBUGGING.md | Stream Parsing |
| Understand data flow | DATA_MODELS.md | ChatChunk |

---

## Key Design Decisions

### 1. Chat as Central Interface with Split View (Updated April 2026)
**The chat view uses a split layout when AI generates component content.** When AI calls workbook/blackboard/notebook tools, the top area shows the dedicated component (45% default) while chat continues below. The AI no longer auto-switches between tabs - it stays in chat.

### 2. Saved Lists for History (New April 2026)
**Former standalone tabs are now saved lists** that show historical content. Click an item to jump to the original chat context where that content was created.

### 3. Line-Prefix Protocol
Content routing uses line prefixes (`B>` for blackboard, `N>` for notebook) instead of separate API calls. This enables real-time multiplexing.

### 4. Tool Call UI Indicators
Tool calls are displayed as collapsible indicators in the chat, grouped by function name, with category icons (📚 workbook, ✏️ question).

### 5. Zero-Latency Streaming
Per-character parsing with 2-char lookahead ensures no buffering delays. Content is emitted instantly as it arrives.

---

## Development Workflow

### Before Making Changes
1. Check if the feature already exists (search docs/)
2. Read relevant documentation
3. Add unit tests for edge cases

### After Making Changes
1. Update relevant documentation
2. Add entries to BUG_FIXES_HISTORY.md if fixing bugs
3. Run `flutter test` to verify

---

## Related Resources

- **System Prompt**: `system_prompt.md`
- **Product Requirements**: `planning/PRD.md`
- **API Configuration**: See `APIConfigService` in code
- **Database Schema**: `lib/services/database_service.dart`
