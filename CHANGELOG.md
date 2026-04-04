# 开发日志 (Changelog)

所有本项目的关键开发节点都会在此记录。

---

## [0.1.0] - 2026-03-19

### ✨ 新增 (Added)

*   **核心架构: Agentic Workflow**
    *   构建了基于 `AIService` 的核心服务，实现了“思考-行动-观察”的 **ReAct 推理循环**。
    *   设立了 **`StudyBuddyAgent`** 智能体，包含独立的 System Prompt 和可配置的工具集。
    *   实现了多功能 **Function Calling** 机制，AI 可自主调用 `calculator`, `update_blackboard`, `mark_workbook`, `clear_blackboard` 等工具。

*   **人机协作 (Human-in-the-loop)**
    *   为 `clear_blackboard` 等高风险工具增加了**用户确认机制**，AI 执行前会弹窗请求许可。

*   **UI/UX: 沉浸式学习组件**
    *   **黑板**: 重构为带有木质边框和粉笔质感的复古黑板。
    *   **作业本**: 重构为米黄色横线本，并支持 AI **红色画笔批改**。
    *   **笔记本**: 重构为带有方格和螺旋装订效果的笔记本。

*   **多模态交互**
    *   **语音**: 集成 `speech_to_text` 和 `flutter_tts`，实现了完整的语音对话和 AI 朗读功能。
    *   **图像**: 添加了 `file_picker`，支持用户上传图片作为对话上下文，并在消息气泡中展示。

*   **知识集成: RAG**
    *   创建了 `RAGService`，内置了“一年级数学教纲”作为本地知识库。
    *   实现了基于关键词的**检索增强生成**，AI 回答会优先参考教纲内容。

*   **基础建设**
    *   建立了与本地 **Ollama** 的流式 (Streaming) 连接。
    *   使用 `Provider` 进行状态管理，使用 `sqflite` 进行对话历史的本地持久化。
    *   实现了长对话的**滑动窗口**管理和流式请求的**中断**功能。

### 🚀 下一步计划 (Next Steps)

*   **[ ] Requirement #7: 安全与审计 (Security & Observability)**
    *   **Token 消耗审计**: 统计每次 LLM 调用的 Token 使用量，用于成本分析。
    *   **调用全链路追踪**: 建立更详细的日志系统，记录 Agent 的每一步思考和决策。
    *   **提示词注入防护**: 为用户输入增加基础的过滤层。

*   **[ ] Requirement #5: 高级任务分解 (Advanced Task Decomposition)**
    *   探索如何让 AI 将“帮我制定一个为期一周的学习计划”这类复杂指令，自动分解为多个可执行的子任务。

*   **[ ] Requirement #6: 增强型 RAG (Advanced RAG)**
    *   引入本地向量化模型，将关键词检索升级为**语义检索**，提高知识库匹配的准确性。
    *   支持用户上传 `.txt`, `.md` 文件作为**自定义教纲**。
