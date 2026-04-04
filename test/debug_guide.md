# Flutter Debug Guide

## 一、调试流程

### 1. 基本调试命令

```powershell
# 运行应用
flutter run -d chrome

# 查看可用设备
flutter devices

# 运行测试
flutter test

# 检查环境
flutter doctor
```

### 2. 运行时操作

| 快捷键 | 功能 |
|--------|------|
| `r` | Hot Reload（热重载，保留状态） |
| `R` | Hot Restart（完全重启） |
| `d` | 打开 DevTools |
| `q` | 退出 |

### 3. 日志调试

在关键位置添加日志：

```dart
// 基本日志
print('[标签] 信息内容');

// 调试专用日志（只在 debug 模式输出）
debugPrint('[AIService] 发送请求到 Ollama...');
debugPrint('[DatabaseService] 查询结果: $result');
```

---

## 二、调试工作流

```
1. 发现 Bug
     ↓
2. 添加 debugPrint() 到相关代码
     ↓
3. flutter run 观察日志
     ↓
4. 定位问题
     ↓
5. 修复代码
     ↓
6. Hot Reload (按 r) 验证
     ↓
7. 写单元测试防止回归
     ↓
8. flutter test 确认通过
```

---

## 三、单元测试

### 测试文件位置

```
test/
├── widget_test.dart      # UI 组件测试
├── unit/                 # 单元测试
│   ├── ai_service_test.dart
│   └── database_test.dart
└── integration/          # 集成测试
```

### 测试示例

```dart
// test/unit/ai_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/services/ai_service.dart';

void main() {
  test('AIService initializes correctly', () {
    final aiService = AIService();
    expect(aiService, isNotNull);
  });

  testWidgets('Dialog sends message correctly', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(find.text('你好'), findsOneWidget);
  });
}
```

---

## 四、DevTools

运行 `flutter run` 后按 `d` 打开 DevTools，可以：

| 功能 | 说明 |
|------|------|
| **Inspector** | 查看 Widget 树 |
| **Performance** | 性能分析 |
| **Memory** | 内存分析 |
| **Network** | 网络请求 |
| **Logging** | 日志查看 |

---

## 五、数据库调试

项目提供了 `lib/services/db_debug_tool.dart` 数据库调试工具，方便查看和调试数据库内容。

### 工具位置

`lib/services/db_debug_tool.dart`

### 引入方式

```dart
import 'services/db_debug_tool.dart';
```

### 可用方法

| 方法 | 说明 |
|------|------|
| `getAllTablesSummary(db)` | 查看所有表名和记录数 |
| `getTableContent(db, tableName)` | 查看指定表的内容 |
| `getTableSchema(db, tableName)` | 查看表结构 |
| `executeQuery(db, sql)` | 执行自定义 SQL 查询 |
| `getFullDatabaseState(db)` | 获取完整数据库状态（供 AI 分析） |
| `debugPrintAll(db)` | 直接打印到控制台 |

### 使用示例

#### 1. 查看所有表概览

```dart
final db = await DatabaseService().database;
print(await DBDebugTool.getAllTablesSummary(db));
```

输出示例：
```
=== 数据库表概览 ===
- users: 1 条记录
- messages: 25 条记录
- conversations: 3 条记录
- notes: 5 条记录
```

#### 2. 查看特定表内容

```dart
// 查看最近 10 条消息
print(await DBDebugTool.getTableContent(
  db, 
  'messages', 
  limit: 10,
  orderBy: 'timestamp DESC',
));

// 带条件查询
print(await DBDebugTool.getTableContent(
  db,
  'messages',
  where: 'role = ?',
  whereArgs: ['user'],
));
```

输出示例：
```
=== 表: messages ===
列: id, conversation_id, role, content, timestamp
--------------------------------------------------
[0] id=msg_001, conversation_id=conv_001, role=user, content=你好
[1] id=msg_002, conversation_id=conv_001, role=assistant, content=你好！有什么可以帮你的？
```

#### 3. 查看表结构

```dart
print(await DBDebugTool.getTableSchema(db, 'users'));
```

输出示例：
```
=== 表结构: users ===
- id: TEXT PRIMARY KEY
- name: TEXT NOT NULL
- grade: INTEGER NOT NULL
- curriculum: TEXT NOT NULL
- created_at: INTEGER NOT NULL
```

#### 4. 执行自定义 SQL

```dart
// 查询特定用户的消息
print(await DBDebugTool.executeQuery(
  db, 
  "SELECT * FROM messages WHERE content LIKE '%你好%' LIMIT 10",
));

// 统计查询
print(await DBDebugTool.executeQuery(
  db,
  "SELECT role, COUNT(*) as count FROM messages GROUP BY role",
));
```

#### 5. 获取完整数据库状态（供 AI 分析）

```dart
// 获取所有表的结构和内容，用于发给 AI 分析
print(await DBDebugTool.getFullDatabaseState(db));
```

### 在代码中快速调试

临时在需要调试的地方插入：

```dart
import 'services/db_debug_tool.dart';

// 在某个方法中
Future<void> someMethod() async {
  final db = await DatabaseService().database;
  
  // 快速打印数据库状态
  await DBDebugTool.debugPrintAll(db);
  
  // 或者获取字符串用于分析
  final state = await DBDebugTool.getFullDatabaseState(db);
  debugPrint(state);
}
```

### AI 辅助数据库调试

当你需要调试数据库问题时：

1. 在代码中插入 `DBDebugTool` 调用
2. 运行应用：`flutter run -d chrome`
3. 将输出结果发给 AI
4. AI 分析数据状态，定位问题

---

## 六、常见问题排查

### 编译错误

```powershell
# 清理构建缓存
flutter clean
flutter pub get
flutter run
```

### 依赖问题

```powershell
# 更新依赖
flutter pub upgrade

# 检查过期依赖
flutter pub outdated
```

### 网络问题

如果 `dartvm.exe` 被防火墙阻止：
1. 以管理员身份登录
2. 允许 `C:\flutter\bin\cache\dart-sdk\bin\dart.exe` 通过防火墙

---

## 七、AI 辅助调试

### 使用 iFlow CLI

```
1. 遇到错误时，直接将错误信息发给 AI
2. AI 自动读取相关代码文件
3. AI 分析问题并给出修复方案
4. AI 修改代码
5. 运行测试验证
```

### 主流 AI 调试工具对比

| 工具 | 自主程度 | 说明 |
|------|----------|------|
| ChatGPT/Claude Web | 低 | 手动复制粘贴 |
| GitHub Copilot Chat | 中 | IDE 内交互 |
| Cursor Agent | 高 | 自动修改文件 |
| iFlow CLI | 高 | 终端 Agent |

---

## 八、数据库表结构参考

本项目使用的表：

| 表名 | 说明 |
|------|------|
| users | 用户信息 |
| user_stats | 用户统计 |
| questions | 题目 |
| user_answers | 用户答案 |
| mistake_records | 错题记录 |
| knowledge_points | 知识点 |
| user_knowledge_progress | 知识点进度 |
| notes | 笔记 |
| handwriting_strokes | 手写笔画 |
| ai_summaries | AI 摘要 |
| conversations | 对话会话 |
| messages | 消息 |
