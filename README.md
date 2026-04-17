# 小书童 (AI Family Teacher) - Flutter AI 教学应用

“小书童”是一个基于 Flutter 和本地大语言模型 (LLM) 构建的、高度可扩展的 AI 家庭教师应用。它不仅是一个简单的对话工具，更是一个集成了多模态交互、智能体工作流和动态知识库的综合学习平台。

## ✨ 核心功能 (Core Features)

*   **Chat-Centric 学习界面** (2026-04 重构):
    *   **统一聊天界面**: 所有内容（黑板、作业本、笔记本）都在聊天中内联显示，无需切换标签页
    *   **已保存列表**: 浏览历史内容（黑板、作业本、笔记本），点击即可跳转到原始聊天上下文
    *   **无自动切换**: AI 响应保留在聊天界面，用户始终保持上下文

*   **沉浸式学习组件** (内联显示):
    *   **复古黑板**: 模拟真实粉笔质感的书写和擦除，支持 AI 自动画图、写公式（通过 `B>` 前缀在聊天中显示）
    *   **护眼作业本**: 米黄色横线本设计，AI 可在上面用"红笔"进行批改、打分（通过工具调用在聊天中创建）
    *   **螺旋笔记本**: 方格纸背景，适合自由记录笔记和画图（通过 `N>` 前缀在聊天中显示）

*   **多模态交互 (Multi-modal)**:
    *   **文字对话**: 基础的文本输入。
    *   **语音对话**: 支持语音输入（自动转文字）和 AI 语音回复（自动朗读）。
    *   **图像理解**: 可上传图片（如题目照片），让 AI 进行识别和解答。

*   **智能体架构 (Agentic Workflow)**:
    *   **多工具调用 (Function Calling)**: AI 能够自主调用 `计算器`、`黑板控制器`、`作业本批改器` 等多种工具完成复杂任务。
    *   **闭环推理 (ReAct Loop)**: 支持“思考-行动-观察”的多步推理循环，AI 可根据工具返回的结果进行自我纠错和下一步决策。
    *   **人机协作 (Human-in-the-loop)**: 在执行清空黑板等高风险操作前，会主动弹窗征求用户同意。

*   **检索增强生成 (RAG)**:
    *   内置了系统教纲知识库。
    *   AI 在回答问题前会先检索相关教纲内容，确保回答的专业性和准确性。

## 🛠️ 技术架构 (Tech Stack)

*   **前端**: Flutter 3.x
*   **状态管理**: Provider
*   **本地大模型**: Ollama (本项目默认使用 `qwen3.5:9b` 模型)
*   **核心服务**:
    *   `AIService`: 驱动 Agentic 循环、工具调用和 RAG 的核心。
    *   `VoiceService`: 负责语音转文字 (STT) 和文字转语音 (TTS)。
    *   `RAGService`: 管理教纲知识库并提供检索能力。
*   **本地数据库**: SQLite (通过 `sqflite` 实现)，用于持久化对话历史。

## 🚀 如何运行 (How to Run)

1.  **环境准备**:
    *   确保已安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)。
    *   确保你的局域网内已运行 [Ollama](https://ollama.com/) 服务，并下载了相应的模型（如 `ollama pull qwen:4b`）。

2.  **修改配置**:
    *   在 `lib/services/ai_service.dart` 中，修改 `_ollamaUrl` 和 `_model` 以匹配你的本地服务地址和模型名称。

3.  **安装依赖**:
    ```bash
    flutter pub get
    ```

4.  **运行应用 (Web)**:
    ```bash
    flutter run -d chrome
    ```
    *应用会在 Chrome 浏览器中启动。由于使用了语音服务，请确保已授予浏览器麦克风权限。*

---

## 📚 开发者文档

如果你是贡献者或需要深入了解项目架构，请查阅以下文档：

| 文档 | 用途 | 适合人群 |
|------|------|----------|
| [GENERAL.md](docs/GENERAL.md) | 整体架构概览、技术决策 | 新加入的开发者 |
| [UI_COMPONENTS.md](docs/UI_COMPONENTS.md) | UI 组件设计、聊天中心架构 | 前端开发者 |
| [STREAMING_PROTOCOL.md](docs/STREAMING_PROTOCOL.md) | LLM 流式通信协议 | 后端/AI 开发者 |
| [TOOL_CALL_SYSTEM.md](docs/TOOL_CALL_SYSTEM.md) | 工具调用系统、Function Calling | AI 工作流开发者 |
| [DATA_MODELS.md](docs/DATA_MODELS.md) | 数据模型、数据库结构 | 全栈开发者 |
| [LOGGING_AND_DEBUGGING.md](docs/LOGGING_AND_DEBUGGING.md) | 调试指南、常见问题排查 | 所有开发者 |
| [UI_REFACTORING_MIGRATION_GUIDE.md](docs/UI_REFACTORING_MIGRATION_GUIDE.md) | 2026-04 UI 重构迁移指南 | 维护代码的开发者 |
| [BUG_FIXES_HISTORY.md](docs/BUG_FIXES_HISTORY.md) | 历史 Bug 修复记录 | 维护者 |

**快速开始路径：**
1. 先读 [GENERAL.md](docs/GENERAL.md) 了解架构
2. 再读 [UI_COMPONENTS.md](docs/UI_COMPONENTS.md) 理解界面
3. 如果需要修改代码，查阅 [UI_REFACTORING_MIGRATION_GUIDE.md](docs/UI_REFACTORING_MIGRATION_GUIDE.md)

---
*这个 README.md 旨在提供一个清晰的项目概览，方便任何新加入的开发者快速上手。详细技术文档请查阅 `docs/` 目录。*
