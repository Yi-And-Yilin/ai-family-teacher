---
name: widget-test
description: Test UI components in isolation using flutter test with mock data. Covers basic template, common finders, pump vs pumpAndSettle, and troubleshooting tips.
---

# Widget Test

Test UI components in isolation (fast, uses mock data).

## When to Use

| Use Widget Test | Use Integration Test |
|-----------------|---------------------|
| Single widget/component | Full app flow |
| UI rendering logic | Real database/network |
| Quick feedback during development | Pre-release verification |
| CI/CD on every push | On merge/release |

## Basic Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_family_teacher/widgets/your_widget.dart';

void main() {
  testWidgets('description', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: MaterialApp(home: YourWidget()),
      ),
    );

    expect(find.text('expected'), findsOneWidget);
  });
}
```

## Common Finders

```dart
find.text('Submit')
find.byKey(const Key('my_button'))
find.byIcon(Icons.send)
find.byType(Scaffold)
```

## Common Actions

```dart
await tester.tap(find.byKey(const Key('button')));
await tester.enterText(find.byKey(const Key('input')), 'hello');
await tester.pump();              // 推进一帧
await tester.pumpAndSettle();     // 等待所有动画/异步完成
```

## pump vs pumpAndSettle

| 方法 | 用途 | 场景 |
|------|------|------|
| `pump()` | 推进指定时间 | 有定时动画 |
| `pumpAndSettle()` | 等到完全静止 | 无动画/网络请求 |

## Complete Example with Provider

```dart
testWidgets('displays message', (tester) async {
  final appProvider = AppProvider();
  appProvider.addMessage(Message(content: 'Hello'));

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: MaterialApp(home: DialogArea()),
    ),
  );

  expect(find.text('Hello'), findsOneWidget);
});
```

## Troubleshooting

| 问题 | 解决 |
|------|------|
| 测试卡住 | 用 `pumpAndSettle(const Duration(seconds: 5))` 加超时 |
| 找不到 widget | 加 `await tester.pump()` 等待渲染 |
| 数据没更新 | 确保 Provider notifyListeners() 被调用 |

## Run Tests

```bash
# Run all widget tests
flutter test

# Run single file
flutter test test/your_test.dart

# Verbose
flutter test test/your_test.dart -v
```

## Key Limitation

Widget test uses **mock data** - it cannot catch bugs in real data flow (e.g., database serialization). Use Integration Test for that.