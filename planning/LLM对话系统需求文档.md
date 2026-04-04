# LLM 对话系统需求文档 (Requirements)

## 1. 对话持久化 (Persistence)
- **数据库同步**: 所有消息（User/AI/System/Tool）必须持久化存储于 `messages` 表。
- **上下文回滚**: 每次对话启动时，能够从数据库加载最近的 N 条历史记录作为 LLM 的上下文。

## 2. 工具与 Agent 架构 (Tools & Agents)
- **全局工具池 (Shared Tools)**: 工具（如 `update_blackboard`）定义为全局单例或插件化集合，支持程序主流程和各 Agent 共享调用。
- **Agent 定制化**: 不同 Agent（如数学老师、英语助手）可以装载工具池中的不同子集。
- **自主循环 (ReAct Loop)**: 系统需支持 Agentic 工作流。当 LLM 决定调用工具时，后端执行工具并将结果返回给 LLM，循环持续直至 LLM 给出最终回复或达到最大迭代次数。

## 3. 通信与信令 (Communication & Signaling)
- **流式多模态响应**: 后端通过流（Stream）不仅发送文本片段，还要发送**信令 (Signals)**，例如：
  - `[STATUS: THINKING]`
  - `[STATUS: CALLING_TOOL: update_blackboard]`
  - `[STATUS: DB_QUERYING]`
- **动作多样性 (Action Variety)**: 前端发送的不仅是文本消息，还可以是特定的 Action 指令。后端应能拦截 Action，先行处理逻辑（如查询本地错题集），再决定是否调用 LLM。
- **全时段反馈**: 即使后端在执行复杂的本地计算（非 LLM 任务），也必须持续向前端发送进度信令，防止界面死锁感。

## 4. 交互控制 (Control Flow)
- **打断能力 (Interruption)**: 后端具备主动打断前端状态的能力（如强制弹出提示或中止当前 UI 动画）。
- **取消机制**: 用户应能随时中止当前的流式生成或工具执行循环。

## 5. 测试环境 (Test Environment)
- **局域网优先**: 默认支持连接局域网内的 Ollama 服务。
- **配置化**: 支持动态修改 Ollama 服务 IP 和模型名称。
