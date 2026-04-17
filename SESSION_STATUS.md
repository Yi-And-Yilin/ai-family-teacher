# Session 状态报告

**日期**: 2026-04-09  
**最后更新**: 本文件创建时刻

---

## 一、程序目前大概情况

### 1.1 项目概述

这是一个 **AI 家庭教师** Flutter 应用，主要功能：
- AI 对话辅导（支持 GLM 和 Ollama）
- 出题功能
- 黑板讲解
- 做题册（Workbook）
- 多模态支持（图片识别）

### 1.2 技术架构

```
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── conversation.dart     # 对话消息
│   │   ├── workbook.dart         # 作业本模型（新增）
│   │   └── ...
│   ├── providers/
│   │   └── app_provider.dart     # 全局状态管理
│   ├── screens/
│   │   ├── home_screen.dart      # 主界面
│   │   └── settings_screen.dart  # 设置界面
│   ├── services/
│   │   ├── ai_service.dart       # AI 服务核心
│   │   ├── api_config.dart       # API 配置（单例模式）
│   │   ├── database_service.dart # 数据库服务
│   │   ├── workbook_tools.dart   # LLM 工具定义（新增）
│   │   ├── workbook_tool_executor.dart  # 工具执行器（新增）
│   │   └── ...
│   ├── widgets/
│   │   ├── dialog_area.dart      # 对话区域（处理 AI 响应）
│   │   ├── blackboard.dart       # 黑板组件
│   │   ├── workbook.dart         # 做题册组件
│   │   └── ...
│   └── prompts/
│       └── base_prompt.dart      # 系统 prompt
└── test/
    └── backend_integration_test.dart  # 后端集成测试
```

### 1.3 API 配置

- **GLM API**: 智谱 AI 在线服务（默认）
- **Ollama**: 本地模型服务（192.168.4.22:11434）
- API Key 存储在 SQLite 数据库 `app_config` 表中（加密存储）

### 1.4 数据库版本

当前版本: **6**

主要表：
- `users` - 用户信息
- `conversations` - 对话会话
- `messages` - 消息记录
- `app_config` - 应用配置（API Key 等）
- `workbooks` - 作业本（新增）
- `workbook_questions` - 题目（新增）
- `workbook_user_answers` - 用户作答（新增）
- `workbook_gradings` - 批改记录（新增）

---

## 二、本 Session 需要完成的任务

### 2.1 任务背景

用户希望将现有的 **行前缀协议**（C>/B>/W>/N>）切换为 **Function Calling / Tool Calling** 模式。

### 2.2 任务目标

1. **设计作业本系统数据结构**
   - 作业本（Workbook）：标题、科目、年级、创建时间
   - 题目（Question）：题号、类型、题干、选项、正确答案、解答过程
   - 用户作答（UserAnswer）：用户答案、是否正确、反馈
   - 批改记录（Grading）：总分、正确数、错误数

2. **设计 LLM 配套工具**
   - 作业本管理：create_workbook, get_workbooks, get_workbook
   - 题目管理：create_question, get_questions, update_question, delete_question
   - 作答获取：get_user_answer, get_all_user_answers
   - 批改：grade_answer, grade_answers, grade_workbook
   - 讲解：explain_solution（切换黑板模式）
   - 上传：upload_user_answer（拍照识别手写答案）

3. **实现工具执行逻辑**
   - 工具定义（JSON schema）
   - 工具执行器（调用数据库）
   - UI 处理工具结果

4. **保留旧代码**
   - 行前缀解析器移到单独文件保留备用

---

## 三、任务当前状态及下一步

### 3.1 已完成 ✅

| 任务 | 文件 | 说明 |
|------|------|------|
| 数据库表设计 | `database_service.dart` | 版本升级到 6，添加 4 张新表 |
| Model 类 | `lib/models/workbook.dart` | Workbook, WorkbookQuestion, WorkbookUserAnswer, WorkbookGrading |
| 数据库方法 | `database_service.dart` | CRUD 方法（注意：有命名冲突需要修复） |
| 工具定义 | `lib/services/workbook_tools.dart` | 15 个工具的 JSON schema |
| 工具执行器 | `lib/services/workbook_tool_executor.dart` | 处理 LLM 工具调用 |
| AIService 集成 | `ai_service.dart` | 添加工具到请求，处理工具结果 |
| UI 处理 | `dialog_area.dart` | 处理 toolResult，UI 动作 |
| ChatChunk 扩展 | `ai_service.dart` | 添加 toolResult 字段 |
| 旧代码保留 | `line_prefix_parser_deprecated.dart` | 行前缀解析器备用 |

### 3.2 当前问题 ❌

**命名冲突**：`database_service.dart` 中有重复定义：
- `insertQuestion` - 旧方法操作 `questions` 表，新方法操作 `workbook_questions` 表
- `getQuestion` - 同上
- `insertUserAnswer` - 同上

**修复方案**：重命名新方法：
- `insertQuestion` → `insertWorkbookQuestion`
- `getQuestion` → `getWorkbookQuestion`
- `updateQuestion` → `updateWorkbookQuestion`
- `deleteQuestion` → `deleteWorkbookQuestion`

### 3.3 下一步操作

1. **修复命名冲突**
   ```
   文件: lib/services/database_service.dart
   
   需要重命名的方法：
   - insertQuestion → insertWorkbookQuestion（已改）
   - getQuestion → getWorkbookQuestion（已改）
   - updateQuestion → updateWorkbookQuestion（已改）
   - deleteQuestion → deleteWorkbookQuestion（待改）
   - insertUserAnswer → insertWorkbookUserAnswer（待改）
   - getUserAnswer → getWorkbookUserAnswer（待改）
   ```

2. **同步修改 tool_executor**
   ```
   文件: lib/services/workbook_tool_executor.dart
   
   需要更新方法调用名称以匹配 database_service 的新命名
   ```

3. **编译测试**
   ```
   flutter analyze
   flutter test test/backend_integration_test.dart
   ```

4. **运行应用测试工具调用**
   - 启动应用
   - 让 AI 出一道题
   - 观察是否调用 create_workbook 和 create_question 工具
   - 观察 UI 是否正确显示

### 3.4 重要文件清单

| 文件 | 用途 | 状态 |
|------|------|------|
| `lib/models/workbook.dart` | 数据模型 | ✅ 完成 |
| `lib/services/workbook_tools.dart` | 工具定义 | ✅ 完成 |
| `lib/services/workbook_tool_executor.dart` | 工具执行 | ⚠️ 需同步方法名 |
| `lib/services/database_service.dart` | 数据库 | ⚠️ 有命名冲突 |
| `lib/services/ai_service.dart` | AI 服务 | ✅ 已集成工具 |
| `lib/widgets/dialog_area.dart` | UI 处理 | ✅ 已处理工具结果 |

---

## 四、工具调用流程

```
用户: "给我出一道五年级数学题"
        ↓
AIService 发送请求（包含 tools）
        ↓
LLM 返回: tool_calls: [{name: "create_workbook", args: {...}}]
        ↓
AIService 执行工具 → WorkbookToolExecutor.execute()
        ↓
工具调用 DatabaseService.insertWorkbook()
        ↓
返回结果: {success: true, workbook_id: "wb_xxx"}
        ↓
AIService yield ChatChunk(toolResult: {...})
        ↓
DialogArea 处理 toolResult
        ↓
UI 动作: 切换到 Workbook 组件
```

---

## 五、测试命令

```bash
# 检查编译错误
flutter analyze

# 运行后端集成测试
flutter test test/backend_integration_test.dart

# 运行应用
flutter run
```

---

## 六、注意事项

1. **GLM API 速率限制**：免费 API 有调用限制，频繁测试可能触发限流
2. **Ollama 配置**：Ollama 在另一台机器（192.168.4.22），确保网络可达
3. **数据库迁移**：数据库版本从 5 升级到 6，旧数据保留
4. **行前缀代码**：保留在 `line_prefix_parser_deprecated.dart`，如果需要回退可以恢复

---

## 七、作业本系统详细设计

### 7.1 系统概述

作业本系统是一个完整的学习闭环：
1. **创建作业本** → AI 生成题目
2. **学生作答** → 用户在 UI 上填写答案
3. **批改作业** → AI 判断对错并给出反馈
4. **讲解题目** → AI 在黑板上详细讲解
5. **错题回顾** → 重新练习错题

### 7.2 数据结构详细定义

#### 7.2.1 作业本（Workbook）

```
字段说明：
- id: 唯一标识，格式 "wb_{timestamp}"
- title: 标题，如 "五年级数学练习"
- description: 描述，如 "本练习包含乘法、除法题目"
- subject: 科目，枚举值 ["数学", "语文", "英语", "科学"]
- grade_level: 年级，整数 1-12
- created_at: 创建时间戳
- updated_at: 更新时间戳
```

#### 7.2.2 题目（WorkbookQuestion）

```
字段说明：
- id: 唯一标识，格式 "q_{timestamp}"
- workbook_id: 所属作业本 ID
- question_number: 题号，从 1 开始递增
- question_type: 题目类型，枚举值：
    - "choice": 选择题
    - "fill_blank": 填空题
    - "essay": 问答题
- content: 题干内容
- options: 选项列表（仅选择题），JSON 数组格式：
    ["A. 48支", "B. 54支", "C. 60支", "D. 72支"]
- correct_answer: 正确答案
    - 选择题：选项字母，如 "B"
    - 填空题：具体答案，如 "48"
    - 问答题：参考答案
- solution: 解答过程（可选）
- difficulty: 难度等级 1-5
- created_at: 创建时间戳
```

#### 7.2.3 用户作答（WorkbookUserAnswer）

```
字段说明：
- id: 唯一标识，格式 "ua_{timestamp}"
- question_id: 题目 ID
- user_answer: 用户填写的答案
- is_correct: 是否正确（0/1/null）
    - null: 未批改
    - 0: 错误
    - 1: 正确
- feedback: AI 给出的反馈/讲解
- submitted_at: 提交时间戳
- graded_at: 批改时间戳
```

#### 7.2.4 批改记录（WorkbookGrading）

```
字段说明：
- id: 唯一标识，格式 "gr_{timestamp}"
- workbook_id: 作业本 ID
- total_questions: 总题数
- correct_count: 正确数
- wrong_count: 错误数
- score: 得分率（0-100）
- graded_at: 批改时间戳
```

### 7.3 数据库 Schema（SQL）

```sql
-- 作业本表
CREATE TABLE workbooks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  subject TEXT,
  grade_level INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- 题目表
CREATE TABLE workbook_questions (
  id TEXT PRIMARY KEY,
  workbook_id TEXT NOT NULL,
  question_number INTEGER NOT NULL,
  question_type TEXT NOT NULL,
  content TEXT NOT NULL,
  options TEXT,                    -- JSON 数组字符串
  correct_answer TEXT NOT NULL,
  solution TEXT,
  difficulty INTEGER,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (workbook_id) REFERENCES workbooks (id)
);

-- 用户作答表
CREATE TABLE workbook_user_answers (
  id TEXT PRIMARY KEY,
  question_id TEXT NOT NULL,
  user_answer TEXT NOT NULL,
  is_correct INTEGER,              -- null=未批改, 0=错误, 1=正确
  feedback TEXT,
  submitted_at INTEGER NOT NULL,
  graded_at INTEGER,
  FOREIGN KEY (question_id) REFERENCES workbook_questions (id)
);

-- 批改记录表
CREATE TABLE workbook_gradings (
  id TEXT PRIMARY KEY,
  workbook_id TEXT NOT NULL,
  total_questions INTEGER NOT NULL,
  correct_count INTEGER NOT NULL,
  wrong_count INTEGER NOT NULL,
  score REAL NOT NULL,             -- 0-100
  graded_at INTEGER NOT NULL,
  FOREIGN KEY (workbook_id) REFERENCES workbooks (id)
);
```

---

## 八、LLM 工具详细定义

### 8.1 工具总览

| 类别 | 工具名 | 功能 |
|------|--------|------|
| **作业本管理** | create_workbook | 创建新作业本 |
| | get_workbooks | 获取作业本列表 |
| | get_workbook | 获取单个作业本详情 |
| **题目管理** | create_question | 添加题目到作业本 |
| | get_questions | 获取作业本的题目列表 |
| | get_question | 获取单道题目详情 |
| | update_question | 修改题目 |
| | delete_question | 删除题目 |
| **作答获取** | get_user_answer | 获取某题的用户答案 |
| | get_all_user_answers | 获取作业本所有用户答案 |
| **批改** | grade_answer | 批改单道题目 |
| | grade_answers | 批改多道题目 |
| | grade_workbook | 批改整个作业本 |
| **讲解** | explain_solution | 讲解题目（切换黑板模式） |
| **上传** | upload_user_answer | 上传作业照片识别手写答案 |

### 8.2 各工具详细定义

#### 8.2.1 create_workbook

```json
{
  "name": "create_workbook",
  "description": "创建新的作业本",
  "parameters": {
    "type": "object",
    "properties": {
      "title": {
        "type": "string",
        "description": "作业本标题，如'五年级数学练习'"
      },
      "subject": {
        "type": "string",
        "enum": ["数学", "语文", "英语", "科学"],
        "description": "科目"
      },
      "grade_level": {
        "type": "integer",
        "description": "年级，如 3、4、5"
      },
      "description": {
        "type": "string",
        "description": "作业本描述"
      }
    },
    "required": ["title"]
  }
}
```

返回：
```json
{
  "success": true,
  "workbook_id": "wb_1712345678901",
  "message": "作业本创建成功"
}
```

#### 8.2.2 create_question

```json
{
  "name": "create_question",
  "description": "在作业本中添加题目",
  "parameters": {
    "type": "object",
    "properties": {
      "workbook_id": {
        "type": "string",
        "description": "作业本ID"
      },
      "question_type": {
        "type": "string",
        "enum": ["choice", "fill_blank", "essay"],
        "description": "题目类型：choice=选择题，fill_blank=填空题，essay=问答题"
      },
      "content": {
        "type": "string",
        "description": "题干内容"
      },
      "options": {
        "type": "array",
        "items": {"type": "string"},
        "description": "选项列表（选择题用），如 ['A. 48支', 'B. 54支', 'C. 60支', 'D. 72支']"
      },
      "correct_answer": {
        "type": "string",
        "description": "正确答案。选择题填选项字母如'A'，填空题填具体答案"
      },
      "solution": {
        "type": "string",
        "description": "解答过程"
      },
      "difficulty": {
        "type": "integer",
        "minimum": 1,
        "maximum": 5,
        "description": "难度等级 1-5"
      }
    },
    "required": ["workbook_id", "question_type", "content", "correct_answer"]
  }
}
```

返回：
```json
{
  "success": true,
  "question_id": "q_1712345678902",
  "question_number": 1,
  "message": "题目添加成功"
}
```

#### 8.2.3 grade_answer

```json
{
  "name": "grade_answer",
  "description": "批改单道题目，返回是否正确和反馈。UI会根据结果显示叉号或勾，错误时背景变浅红色。",
  "parameters": {
    "type": "object",
    "properties": {
      "question_id": {
        "type": "string",
        "description": "题目ID"
      },
      "is_correct": {
        "type": "boolean",
        "description": "是否正确"
      },
      "feedback": {
        "type": "string",
        "description": "反馈/讲解内容"
      }
    },
    "required": ["question_id", "is_correct"]
  }
}
```

返回：
```json
{
  "success": true,
  "is_correct": false,
  "feedback": "再想想呢？应该是6×8=48支，选B才对。",
  "ui_action": "show_wrong_mark"
}
```

**UI 动作说明**：
- `show_correct_mark`: 显示绿色勾号
- `show_wrong_mark`: 显示红色叉号，题目背景变浅红色

#### 8.2.4 grade_answers

```json
{
  "name": "grade_answers",
  "description": "批改多道题目",
  "parameters": {
    "type": "object",
    "properties": {
      "answers": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "question_id": {"type": "string"},
            "is_correct": {"type": "boolean"},
            "feedback": {"type": "string"}
          },
          "required": ["question_id", "is_correct"]
        },
        "description": "批改结果列表"
      }
    },
    "required": ["answers"]
  }
}
```

#### 8.2.5 grade_workbook

```json
{
  "name": "grade_workbook",
  "description": "批改整个作业本，计算总分。UI会在作业本右上角显示百分制评分。",
  "parameters": {
    "type": "object",
    "properties": {
      "workbook_id": {
        "type": "string",
        "description": "作业本ID"
      }
    },
    "required": ["workbook_id"]
  }
}
```

返回：
```json
{
  "success": true,
  "grading_id": "gr_1712345678903",
  "total_questions": 5,
  "answered_count": 5,
  "correct_count": 3,
  "wrong_count": 2,
  "unanswered_count": 0,
  "score": 60.0,
  "ui_action": "show_score"
}
```

**UI 动作说明**：
- `show_score`: 在作业本右上角显示分数（如 "60分"）

#### 8.2.6 explain_solution

```json
{
  "name": "explain_solution",
  "description": "讲解题目解答过程。会切换到黑板模式，在黑板上展示题目和解答步骤。",
  "parameters": {
    "type": "object",
    "properties": {
      "question_id": {
        "type": "string",
        "description": "要讲解的题目ID"
      }
    },
    "required": ["question_id"]
  }
}
```

返回：
```json
{
  "success": true,
  "question": {...},
  "ui_action": "switch_to_blackboard",
  "content": "每盒钢笔有6支，买8盒钢笔，一共有多少支？",
  "solution": "6 × 8 = 48支"
}
```

**UI 动作说明**：
- `switch_to_blackboard`: 切换到黑板组件
- 黑板上显示题目和解答步骤

#### 8.2.7 upload_user_answer

```json
{
  "name": "upload_user_answer",
  "description": "处理用户上传的作业照片。读取手写答案并更新到系统。用于用户打印作业本后手写完成再拍照上传的场景。",
  "parameters": {
    "type": "object",
    "properties": {
      "workbook_id": {
        "type": "string",
        "description": "作业本ID"
      },
      "image_base64": {
        "type": "string",
        "description": "作业照片的base64编码"
      }
    },
    "required": ["workbook_id", "image_base64"]
  }
}
```

**使用场景**：
1. 用户打印作业本
2. 手写完成答案
3. 拍照上传
4. LLM 使用 VL 模型识别手写内容
5. 自动更新到系统

---

## 九、UI 配合详解

### 9.1 批改结果显示

#### 9.1.1 单题批改（grade_answer）

**正确时**：
- 题目旁边显示绿色勾号 ✓
- 可选：短暂闪烁绿色背景

**错误时**：
- 题目旁边显示红色叉号 ✗
- 题目背景变为浅红色 (#FFEBEE)
- 显示 AI 反馈内容

#### 9.1.2 整体评分（grade_workbook）

**显示位置**：作业本右上角

**显示内容**：
```
┌────────────────────────────┐
│ 得分: 60分 (3/5)           │
└────────────────────────────┘
```

### 9.2 黑板讲解模式

当调用 `explain_solution` 时：

1. **切换组件**：从做题册切换到黑板
2. **显示题目**：黑板上显示题干
3. **逐步讲解**：AI 流式输出解题步骤
4. **公式渲染**：LaTeX 公式正确显示

### 9.3 工具结果处理流程

```dart
// dialog_area.dart 中的处理逻辑

if (chunk.hasToolResult) {
  final result = chunk.toolResult!;
  final toolName = result['tool_name'] as String;
  final toolResult = result['result'] as Map<String, dynamic>;
  
  // 处理 UI 动作
  if (toolResult.containsKey('ui_action')) {
    final uiAction = toolResult['ui_action'] as String;
    
    switch (uiAction) {
      case 'show_correct_mark':
        // 显示正确标记
        break;
      case 'show_wrong_mark':
        // 显示错误标记 + 浅红背景
        break;
      case 'show_score':
        // 显示分数
        break;
      case 'switch_to_blackboard':
        appProvider.switchTo(ComponentType.blackboard);
        break;
    }
  }
  
  // 处理创建作业本
  if (toolName == 'create_workbook' && toolResult['success'] == true) {
    appProvider.switchTo(ComponentType.workbook);
  }
  
  // 处理创建题目
  if (toolName == 'create_question' && toolResult['success'] == true) {
    appProvider.switchTo(ComponentType.workbook);
  }
}
```

---

## 十、使用场景示例

### 10.1 场景一：AI 出题

```
用户: "给我出一道五年级数学题"

AI 内部流程:
1. 调用 create_workbook(title="五年级数学练习", grade_level=5)
   → 返回 workbook_id

2. 调用 create_question(
     workbook_id=...,
     question_type="choice",
     content="每盒钢笔有6支，买8盒，一共有多少支？",
     options=["A. 42支", "B. 48支", "C. 54支", "D. 56支"],
     correct_answer="B",
     solution="6 × 8 = 48支"
   )

AI 回复: "题目已出好，请看做题册完成作答。"

UI 动作: 切换到做题册组件，显示题目
```

### 10.2 场景二：批改单题

```
用户: "我选 B"

AI 内部流程:
1. 调用 get_user_answer(question_id=...) 获取用户答案
   → 用户答案是 "B"

2. 调用 grade_answer(
     question_id=...,
     is_correct=true,
     feedback="做对了！6×8=48支"
   )

AI 回复: "做对了！6乘以8等于48支。"

UI 动作: 题目旁边显示绿色勾号
```

### 10.3 场景三：批改整本作业

```
用户: "帮我批改整本作业"

AI 内部流程:
1. 调用 get_all_user_answers(workbook_id=...)
   → 返回所有题目的用户答案

2. 逐题判断对错，调用 grade_answer(...)

3. 调用 grade_workbook(workbook_id=...)
   → 计算总分

AI 回复: "批改完成！你得了60分，5道题做对3道。"

UI 动作: 
- 每题显示勾/叉
- 右上角显示 "得分: 60分 (3/5)"
```

### 10.4 场景四：讲解题目

```
用户: "第2题不懂，能讲讲吗？"

AI 内部流程:
1. 调用 get_question(question_id=...)
   → 获取题目详情

2. 调用 explain_solution(question_id=...)

AI 回复: 在黑板上逐步讲解

UI 动作: 切换到黑板，显示题目和解答步骤
```

### 10.5 场景五：拍照上传

```
用户: [上传作业照片]

AI 内部流程:
1. 调用 upload_user_answer(workbook_id=..., image_base64=...)
   → VL 模型识别手写答案
   → 更新到 workbook_user_answers 表

AI 回复: "已识别你的答案：第1题选B，第2题选A..."

UI 动作: 做题册显示识别出的答案
```

---

## 十一、待实现功能

### 11.1 短期

- [ ] 修复 database_service.dart 命名冲突
- [ ] 同步 workbook_tool_executor.dart 方法名
- [ ] UI 批改标记组件（勾号/叉号/浅红背景）
- [ ] UI 分数显示组件

### 11.2 中期

- [ ] 作业本打印功能
- [ ] VL 模型识别手写答案
- [ ] 错题本功能（从批改结果生成错题集）
- [ ] 题目难度自适应

### 11.3 长期

- [ ] 多科目支持
- [ ] 学习进度追踪
- [ ] 家长端查看报告