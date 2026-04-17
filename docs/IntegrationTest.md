# Integration Test 指南

## 什么是 Integration Test

Integration Test 在**真实设备**上运行完整的 App，发送真实网络请求，使用真实数据库。

| 类型 | 运行环境 | 数据 | 速度 |
|------|----------|------|------|
| Unit Test | 纯 Dart | Mock | 快 |
| Widget Test | Flutter 环境 | Mock | 快 |
| **Integration Test** | **真实设备/模拟器** | **真实** | 慢 |

## 常用命令

```bash
# 运行所有集成测试
flutter test integration_test/

# 运行单个测试文件
flutter test integration_test/app_test.dart

# 指定设备（Windows 为例）
flutter test integration_test/app_test.dart -d windows

# 查看可用设备
flutter devices
```

## 测试文件位置

```
integration_test/
└── app_test.dart
```

## 如何编写测试

### 1. 模板结构

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_family_teacher/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('测试组名称', () {
    testWidgets('测试用例名称', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 执行操作
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // 验证结果
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
```

### 2. 常用查找器

```dart
// 按 Key 查找（推荐）
find.byKey(const Key('my_button'))

// 按文本查找
find.text('提交')

// 按图标查找
find.byIcon(Icons.send)

// 按类型查找
find.byType(Scaffold)
```

### 3. 常用操作

```dart
// 点击
await tester.tap(find.byKey(const Key('button')));

// 输入文本
await tester.enterText(find.byKey(const Key('input')), 'hello');

// 等待
await tester.pumpAndSettle(const Duration(seconds: 5));
```

## 运行测试前的检查清单

1. **数据库**：如果是首次运行或新增表，确保测试数据库是最新的（删除旧的测试数据库）
   ```bash
   # Windows
   Remove-Item "C:\ai-family-teacher\.dart_tool\sqflite_common_ffi\databases\ai_family_teacher.db" -Force
   ```

2. **设备**：确认设备可用
   ```bash
   flutter devices
   ```

3. **依赖**：确保依赖已安装
   ```bash
   flutter pub get
   ```

## 调试技巧

### 打印当前 UI 树
```dart
await tester.pumpAndSettle();
print(tester.widgetList(find.byType(Widget)).toList());
```

### 截屏
```dart
final screenshot = await tester.takeScreenshot();
await File('screenshot.png').writeAsBytes(screenshot);
```

## 常见问题

### Q: 测试卡在 pumpAndSettle 不动
A: 使用带超时的版本
```dart
await tester.pumpAndSettle(const Duration(seconds: 10));
```

### Q: 找不到 widget
A: 确保 widget 已渲染，可加延迟
```dart
await tester.pump(const Duration(milliseconds: 500));
```

## 数据库注意事项

Integration Test 使用**独立的测试数据库**，位于：
```
C:\ai-family-teacher\.dart_tool\sqflite_common_ffi\databases\ai_family_teacher.db
```

每次运行测试前，可以删除这个文件让数据库重新创建。

关于数据库更新，参见 [DatabaseMigration.md](DatabaseMigration.md)
