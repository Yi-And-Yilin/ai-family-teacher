# 后端集成测试 (Backend Integration Test)

## 概念定义

**不是 Unit Test**：单元测试通常隔离测试单个函数或模块。

**不是传统意义上的 E2E Test**：传统端到端测试从用户操作 UI 开始，经过前端、后端，直到数据库/API。

**这是 Backend Integration Test**：
- 跳过前端 UI 层
- 从后端的入口（handler function）开始
- 一路到底层（API 调用、数据库等）
- 模拟 UI 层发出的信号作为输入
- 验证 handler function 的返回结果

```
传统 E2E:    User → UI → State → Handler → API → Response
我们的测试:          [模拟] → Handler → API → Response
```

## Handler Function 位置

| Handler | 文件位置 | 输入 | 输出 |
|---------|---------|------|------|
| `answerQuestionStream()` | `lib/services/ai_service.dart` | `history`, `images` | `Stream<ChatChunk>` |

## 测试例子

```dart
// test/backend_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/services/ai_service.dart';
import 'package:ai_family_teacher/services/api_config.dart';
import 'package:ai_family_teacher/models/conversation.dart';

void main() {
  group('AIService Backend Integration Tests', () {
    setUpAll(() async {
      // 唯一需要的准备：初始化配置（幂等，多次调用无副作用）
      await APIConfigService.instance.init();
    });

    test('纯文本对话 - Handler 应返回有效响应', () async {
      // ========== 1. 模拟 UI 层发出的信号 ==========
      final history = [
        Message(
          id: '1',
          conversationId: 'test',
          role: MessageRole.user,
          content: '你好，请介绍一下自己',
          timestamp: DateTime.now(),
        ),
      ];

      // ========== 2. 直接调用 Handler（无需准备） ==========
      final aiService = AIService();
      final chunks = <ChatChunk>[];
      await for (final chunk in aiService.answerQuestionStream(history: history)) {
        chunks.add(chunk);
      }

      // ========== 3. 验证返回结果 ==========
      final fullContent = chunks
          .where((c) => c.content != null)
          .map((c) => c.content!)
          .join();

      expect(fullContent.length, greaterThan(0), reason: 'Handler 应返回内容');
      print('Handler 返回内容长度: ${fullContent.length}');
    });
  });
}
```

## 运行测试

```bash
flutter test test/backend_integration_test.dart
```

## 核心要点

1. **模拟输入**：构造 `Message` 列表作为 UI 层发出的信号
2. **调用 Handler**：直接调用 `answerQuestionStream()`
3. **收集输出**：遍历 `Stream<ChatChunk>` 收集所有 chunk
4. **验证结果**：检查内容长度、特定字段、错误标记等
