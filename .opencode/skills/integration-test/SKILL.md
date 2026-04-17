---
name: integration-test
description: Execute integration tests on real device/emulator. Covers pre-run checklist, commands, and troubleshooting tips for database and widget testing issues.
---

# Run Integration Tests

Execute integration tests on real device/emulator.

## Commands

```bash
# Run all integration tests
flutter test integration_test/

# Run single test file
flutter test integration_test/app_test.dart

# Specify device (check available devices with: flutter devices)
flutter test integration_test/app_test.dart -d windows
```

## Pre-run Checklist

1. Delete old test database if tables were added:
   ```powershell
   Remove-Item "C:\ai-family-teacher\.dart_tool\sqflite_common_ffi\databases\ai_family_teacher.db" -Force
   ```

2. Verify device is available:
   ```bash
   flutter devices
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

## Troubleshooting

- **Test hangs on pumpAndSettle**: Use `await tester.pumpAndSettle(const Duration(seconds: 10))`
- **Widget not found**: Add delay with `await tester.pump(const Duration(milliseconds: 500))`
- **Database errors**: Delete test database file and retry