# AGENTS.md - AI Family Teacher

## Flutter Commands (Windows)

**Flutter is NOT in Bash PATH.** Use CMD/PowerShell directly:

```cmd
flutter build apk --release --split-per-abi
flutter run -d chrome
flutter analyze
flutter format .
```

## AI Service Configuration

- **Ollama URL**: `http://192.168.4.22:11434/api/chat` in `lib/services/ai_service.dart`
- **Models**: `qwen3.5:9b` (text), `qwen3-vl:8b` (vision)
- **If IP changes**: Update both `AIService` and `VLService` URLs

## Database Migrations

1. Increment `_databaseVersion` in `lib/services/database_service.dart`
2. Add migration in `_upgradeDatabase()` using `CREATE TABLE IF NOT EXISTS`
3. Delete test DB at `C:\ai-family-teacher\.dart_tool\sqflite_common_ffi\databases\ai_family_teacher.db` before running integration tests after schema changes

## Testing

```cmd
# Widget tests
flutter test

# Single test file
flutter test test/workbook_display_test.dart

# Integration tests (requires device)
flutter test integration_test/

# Delete old test DB if tests fail due to schema changes
Remove-Item "C:\ai-family-teacher\.dart_tool\sqflite_common_ffi\databases\ai_family_teacher.db" -Force
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/ai_service.dart` | LLM streaming, tool calling, RAG |
| `lib/services/database_service.dart` | SQLite schema, migrations |
| `lib/widgets/component_chat_layout.dart` | Split view (top component + bottom chat) |
| `lib/widgets/dialog_area.dart` | Main chat UI |
| `lib/widgets/workbook.dart` | Workbook component (B> prefix) |
| `lib/widgets/blackboard.dart` | Blackboard component |
| `lib/widgets/notebook.dart` | Notebook component (N> prefix) |

## Architecture Notes

- **Chat-centric UI**: All components (workbook/blackboard/notebook) display inline in chat with split layout when AI calls tools
- **State**: `AppProvider` manages `activeComponentType`, `streamingWorkbookContent`, `streamingBlackboardContent`, `streamingNotebookContent`
- **Line-prefix protocol**: `B>` = blackboard, `N>` = notebook content in streaming

## Documentation

See `docs/` for detailed architecture docs:
- `GENERAL.md` - Architecture overview
- `STREAMING_PROTOCOL.md` - LLM streaming
- `TOOL_CALL_SYSTEM.md` - Function calling
- `UI_COMPONENTS.md` - Component design
