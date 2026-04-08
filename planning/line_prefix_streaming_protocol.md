# 行前缀流式协议方案

## 概述

本方案采用"行前缀"方式实现多组件流式输出路由，替代原有的 XML 标签法和 Function Calling 法。

---

## 核心设计

### 格式定义

```
C: 普通聊天内容（默认路由）
B: 黑板内容（公式、步骤、图示）
W: 做题册内容（题目、选项）
N: 笔记本内容（笔记、重点）
```

### 示例输出

```
C: 好的，让我来讲解这道一元二次方程的题目！
B: $$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$
C: 这就是著名的求根公式。让我们一步步来计算。
B: 已知：a = 1, b = 2, c = -3
C: 现在我们将这些值代入公式中。
B: $$x = \frac{-2 \pm \sqrt{4 - 4(1)(-3)}}{2}$$
C: 接下来计算根号内的部分...
```

---

## 与其他方案的对比

| 对比项 | XML标签法 | Function Calling | 行前缀法 ✓ |
|--------|-----------|------------------|------------|
| 格式示例 | `[BLACKBOARD]...[/BLACKBOARD]` | `tool_calls` | `B: 内容` |
| 闭合需求 | 需要闭合 | 不需要 | 不需要 |
| 容错性 | 忘记闭合 → 灾难 | 需要循环调用 | 忘记前缀 → 仅影响当前行 |
| 流式友好 | 需等待完整标签 | 通常在响应末尾 | 零延迟 |
| 实现复杂度 | 状态机 | 多次请求 | 行首判断 |
| Token开销 | 较高 | 较高 | 最低 |

---

## 前端解析器逻辑

### 状态机设计

```dart
enum RenderTarget {
  chat,      // C: 聊天区
  blackboard, // B: 黑板
  workbook,   // W: 做题册
  notebook,   // N: 笔记本
}

class LinePrefixParser {
  RenderTarget currentTarget = RenderTarget.chat;
  
  void parseLine(String line) {
    // 检测行首前缀
    if (line.startsWith('B:')) {
      currentTarget = RenderTarget.blackboard;
      routeTo(line.substring(2), currentTarget);
    } else if (line.startsWith('C:')) {
      currentTarget = RenderTarget.chat;
      routeTo(line.substring(2), currentTarget);
    } else if (line.startsWith('W:')) {
      currentTarget = RenderTarget.workbook;
      routeTo(line.substring(2), currentTarget);
    } else if (line.startsWith('N:')) {
      currentTarget = RenderTarget.notebook;
      routeTo(line.substring(2), currentTarget);
    } else {
      // 无前缀 → 默认发到聊天区
      routeTo(line, RenderTarget.chat);
    }
  }
}
```

### 流式处理

```
流数据到达 → 按行分割 → 检测行首 → 路由到对应组件
     ↓
  逐字符到达时：
  - 累积到当前行buffer
  - 遇到换行符 → 完成一行 → 解析行首 → 路由
```

---

## System Prompt 设计

```markdown
你是"小书童"，一个亲切、耐心的AI学习伙伴。

【输出格式要求 - 重要】
你的每一行输出必须以特定的前缀开头：

- C: 普通对话内容（解释、引导、鼓励等）
- B: 黑板内容（公式、步骤、图示说明）
- W: 做题册内容（题目、选项）
- N: 笔记本内容（重点笔记、知识总结）

格式示例：
C: 好的，让我来讲解这道题！
B: 第一步：列出已知条件
C: 我们先看题目给了我们什么信息...
B: x + 5 = 12
C: 接下来我们要解出 x 的值...

【数学公式】
使用 LaTeX 格式，用 $$ 包裹：
B: $$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$

【注意事项】
1. 每一行都必须有前缀
2. 黑板内容要简洁，公式为主
3. 解释内容放在 C: 开头的行
4. 不同组件的内容分行书写
```

---

## 需要修改的文件

### 1. lib/prompts/base_prompt.dart
- 更新 System Prompt，添加前缀格式说明

### 2. lib/services/agents_service.dart
- 重写 `StreamingResponseParser`
- 实现行首前缀检测
- 移除 XML 标签解析逻辑

### 3. lib/widgets/dialog_area.dart
- 接收路由后的聊天内容
- 处理黑板块的路由

### 4. lib/providers/app_provider.dart
- 添加 `routeToComponent()` 方法
- 根据前缀更新对应组件状态

### 5. lib/widgets/blackboard.dart
- 接收流式的黑板内容
- 支持 LaTeX 公式渲染

---

## 数学公式渲染

### 依赖添加

```yaml
# pubspec.yaml
dependencies:
  flutter_math_fork: ^0.7.2  # LaTeX 渲染
```

### 使用示例

```dart
// 检测到 $$...$$ 时，使用 LaTeX 渲染
if (content.contains(r'$$')) {
  return Math.tex(extractLatex(content));
}
```

---

## UI 显示效果

```
┌─────────────────────────────────┐
│  ┌───────────────────────────┐  │
│  │ 黑板 (B:)                 │  │
│  │                           │  │
│  │ x = (-b ± √(b²-4ac)) / 2a │  │
│  │                           │  │
│  └───────────────────────────┘  │
├─────────────────────────────────┤
│  对话区 (C:)                    │
│  ┌───────────────────────────┐  │
│  │ AI: 这就是求根公式...     │  │
│  │     接下来我们代入数值    │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 输入框...          [发送] │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## 实现步骤

1. **Phase 1: 解析器重写**
   - 重写 `StreamingResponseParser`
   - 实现行首前缀检测
   - 添加单元测试

2. **Phase 2: Prompt 更新**
   - 更新 `base_prompt.dart`
   - 测试模型输出格式

3. **Phase 3: 路由集成**
   - 修改 `app_provider.dart`
   - 连接解析器与组件

4. **Phase 4: LaTeX 支持**
   - 添加 `flutter_math_fork`
   - 黑板组件支持公式渲染

5. **Phase 5: 测试验证**
   - 端到端测试
   - 边界情况处理

---

## 容错处理

### 情况1: 模型忘记加前缀
```
解决: 默认路由到聊天区 (C:)
```

### 情况2: 模型在黑板行写了大量解释文字
```
解决: 前端可添加启发式检测
- 黑板内容通常较短
- 包含"所以"、"接下来"等词 → 可能应该路由到 C:
```

### 情况3: 流式传输中断
```
解决: 当前行的 buffer 在超时后自动路由到当前目标
```

---

## 扩展性

未来可以轻松添加新的组件前缀：
- `T:` 时间线
- `Q:` 问答题
- `P:` 编程题

---

## 参考文档

- `memory/2026-04-07_ai_communication_architecture.md` - 原有通信架构
- `memory/2026-04-07_question_display_flow.md` - 原有显示流程
- `planning/component chat interaction.txt` - Gemini 讨论记录
