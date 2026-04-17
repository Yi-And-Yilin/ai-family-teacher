# UI 布局恢复指南：为什么 workbook/blackboard/notebook 变成了绿色方框

> **日期**: 2026-04-14
> **来源 session**: 用户发现 workbook 在聊天中只显示为一个绿色小方框
> **状态**: 根因已定位，待修复

---

## 一、用户原来要什么

用户要求的是：**聊天页面中，当 AI 调用 workbook/blackboard/notebook 工具时，页面顶部专门辟出一块区域显示对应的专用组件，聊天内容在屏幕下半部分。**

### 原来的布局方案

```
┌──────────────────────────────────────────┐
│  顶部专用区域（当前活动的组件）           │
│                                          │
│  如果是 workbook：                        │
│    📝 作业本样式（纸张、横线、红边、      │
│       批改痕迹 CustomPainter）            │
│                                          │
│  如果是 blackboard：                      │
│    🖤 黑板样式（专门的黑板 UI）            │
│                                          │
│  如果是 notebook：                        │
│    📒 笔记本样式（螺旋装订孔、方格背景）   │
│                                          │
├──────────────────────────────────────────┤
│  底部：聊天对话区                         │
│  💬 用户消息                              │
│  🤖 AI 消息                              │
│  [输入框]                                 │
└──────────────────────────────────────────┘
```

### 现有的专用组件文件（都在，但没人引用）

| 文件 | 内容描述 | 状态 |
|------|---------|------|
| `lib/widgets/workbook.dart` | 作业本样式：米黄纸张色、纸张横线 CustomPainter、左侧红色装饰边线、AI 批改痕迹（圈/勾/叉/文字）、页眉日期页码 | ✅ 存在，无人引用 |
| `lib/widgets/notebook.dart` | 笔记本样式：螺旋装订孔、方格背景 CustomPainter、多层纸张堆叠阴影 | ✅ 存在，无人引用 |
| `lib/widgets/blackboard.dart` | 黑板样式 | ✅ 存在，无人引用 |
| `lib/widgets/blackboard_chat_view.dart` | 上方黑板 + 下方聊天的组合布局（含拖动调整高度） | ✅ 存在，无人引用 |

---

## 二、我改成了什么（错误的方案）

我在 `lib/widgets/dialog_area.dart` 里写了一个 `_buildInlineToolComponent` 方法，在**聊天记录流里直接插入一个绿色小方框**：

```dart
return Container(
  decoration: BoxDecoration(
    color: Colors.green[50],    // ← 绿色背景
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.green[200]!),
  ),
  child: Column(
    children: [
      Text('作业本已创建'),        // ← 一行文字
      Text(workbookContent),       // ← 纯文本内容
    ],
  ),
);
```

**结果**：整个聊天页面变成了一个纯聊天气泡流，workbook 只是其中一条消息旁边的绿色卡片。

### 当前布局（错误的）

```
┌──────────────────────────────────────────┐
│  全屏聊天                                │
│                                          │
│  💬 "好的，我来帮你出题。"               │
│                                          │
│  🟢 ┌──────────────────────┐             │
│     │ ✅ 作业本已创建       │  ← inline 绿色方框
│     │ 📝 小学三年级数学练习 │
│     └──────────────────────┘             │
│                                          │
│  💬 "题目已准备好，请查看。"             │
│                                          │
│  [输入框]                                 │
└──────────────────────────────────────────┘
```

---

## 三、我为什么会犯这个错误

### 根因分析

1. **我收到用户报告"workbook不显示"后，直接进入了"修bug"模式**
   - 我没有先问：workbook 本来应该长什么样？它应该出现在哪里？
   - 我没有查看现有的 `workbook.dart` 文件
   - 我直接在 `dialog_area.dart` 里自己发明了一个绿色方框

2. **我认为"能显示就是修好了"**
   - 我看到了 `streamingWorkbookContent` 有值
   - 我写了代码让那个值渲染到 UI 上
   - 我以为"任务完成"，从来没有问过这个方案本身是否正确

3. **我没有研究现有的架构就动手**
   - `workbook.dart`、`notebook.dart`、`blackboard.dart` 早就存在
   - `blackboard_chat_view.dart` 已经有"上方组件 + 下方聊天"的布局逻辑
   - 我完全没有引用它们，自己重写了一套

4. **测试只验证了"绿色方框能显示"，没有验证"这是不是用户要的"**
   - 我写了 6 个端到端测试，全部通过
   - 但测试验证的是一个错误的目标

---

## 四、当前代码状态

### 文件引用关系

```
lib/screens/home_screen.dart
  └── ComponentController (component_controller.dart)
        ├── ComponentType.chat → DialogArea(fullScreen: true)
        ├── ComponentType.savedBlackboards → SavedBlackboardList
        ├── ComponentType.savedWorkbooks → SavedWorkbookList
        └── ComponentType.savedNotebooks → SavedNotebookList

❌ workbook.dart 的 WorkbookWidget：无人引用
❌ notebook.dart 的 NotebookWidget：无人引用
❌ blackboard.dart 的 BlackboardWidget：仅被 blackboard_chat_view.dart 引用
❌ blackboard_chat_view.dart 的 BlackboardChatView：无人引用
```

### dialog_area.dart 中需要删除/重构的代码

| 代码段 | 位置 | 说明 |
|--------|------|------|
| `_buildInlineToolComponent` | ~line 727 | 返回绿色方框的方法，应该删除或替换 |
| `_buildGroupedToolCallIndicator` | ~line 630 | 工具调用指示器（可保留） |
| `_buildAIListItem` 中调用 `_buildInlineToolComponent` 的地方 | ~line 577 | 需要改为调用专用组件 |

### AppProvider 中已有的相关字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `streamingWorkbookContent` | String | 作业本内容（已有） |
| `streamingBlackboardContent` | String | 黑板内容（已有） |
| `streamingNotebookContent` | String | 笔记本内容（已有） |
| `blackboardWithChatMode` | bool | 是否启用黑板+聊天模式（已有） |
| `currentQuestionData` | Map? | 当前题目数据（已有） |
| `currentComponent` | ComponentType | 当前活动组件类型（已有） |

---

## 五、下一个 Session 应该做什么

### Step 1: 恢复顶部专用区域布局

修改 `lib/widgets/dialog_area.dart` 的布局结构，从"纯聊天"改为"上方组件 + 下方聊天"：

```dart
// 伪代码示意
Widget build(BuildContext context) {
  return Column(
    children: [
      // 顶部：专用组件区域（根据当前状态显示 workbook/blackboard/notebook）
      if (appProvider.hasActiveComponent)
        _buildActiveComponentView(appProvider),
      
      // 底部：聊天对话区
      Expanded(
        child: _buildChatArea(appProvider),
      ),
    ],
  );
}
```

### Step 2: 引用现有的专用组件

```dart
Widget _buildActiveComponentView(AppProvider appProvider) {
  // 如果有 workbook 内容，显示 WorkbookWidget
  if (appProvider.streamingWorkbookContent.isNotEmpty) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: const WorkbookWidget(),
    );
  }
  
  // 如果有黑板内容，显示 BlackboardWidget
  if (appProvider.streamingBlackboardContent.isNotEmpty) {
    return const BlackboardChatView();
  }
  
  // 如果有笔记本内容，显示 NotebookWidget
  if (appProvider.streamingNotebookContent.isNotEmpty) {
    return const NotebookWidget();
  }
  
  return const SizedBox.shrink();
}
```

### Step 3: 删除 inline 绿色方框代码

删除 `_buildInlineToolComponent` 中的 workbook/blackboard/notebook case，只保留工具调用指示器（ExpansionTile）。

### Step 4: 确认布局行为

- 当 AI 调用 `create_workbook` 时：顶部显示 workbook 组件，聊天区继续滚动
- 当 AI 使用 `B>` 前缀时：顶部显示黑板组件
- 当 AI 使用 `N>` 前缀时：顶部显示笔记本组件
- 当没有专用内容时：聊天区占满全屏

---

## 六、关键文件清单

| 文件 | 用途 |
|------|------|
| `lib/widgets/workbook.dart` | 作业本专用组件（纸张样式） |
| `lib/widgets/notebook.dart` | 笔记本专用组件（螺旋装订样式） |
| `lib/widgets/blackboard.dart` | 黑板专用组件 |
| `lib/widgets/blackboard_chat_view.dart` | 黑板+聊天组合布局（可参考其上下分栏逻辑） |
| `lib/widgets/dialog_area.dart` | 聊天页面（需要重构布局） |
| `lib/widgets/component_controller.dart` | 组件控制器（需要更新路由逻辑） |
| `lib/providers/app_provider.dart` | 状态管理（已有相关字段） |
| `lib/services/ai_service.dart` | AI 服务（包含 ToolCallEvent 解析修复） |

---

## 七、给下一个 Session 的重要提醒

1. **不要自己发明新的 UI 方案**，先看看 `lib/widgets/` 下已有的组件
2. **用户要的布局是"上下分栏"**，不是"聊天里插绿色方框"
3. **修改前先确认**："这是你要的效果吗？"
4. **`blackboard_chat_view.dart` 的布局逻辑可以参考**，它已经有上方组件 + 下方聊天的结构
5. **AppProvider 已经有 `streamingWorkbookContent` 等字段**，不需要新建

---

**最后更新**: 2026-04-14
**下一步**: 恢复 workbook/blackboard/notebook 的上下分栏布局
