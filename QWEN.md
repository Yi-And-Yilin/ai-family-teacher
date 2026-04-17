# Workflow Rules
- ALWAYS start a new task or sub-task by using the `EnterPlanMode` tool
- ALWAYS create a task list using TaskCreate for multi-step tasks (3+ steps or non-trivial work)
- Mark each task as `in_progress` before starting work, and `completed` only after QA passes
- Track task dependencies using `addBlocks`/`addBlockedBy` when tasks have ordering requirements
- Once coding is done, run a QA process

# QA Process
Before marking a task as completed, verify:
- **Requirements met**: Does the implementation satisfy all user **orignal** requirements?
- **Tests run**: Have relevant unit tests been executed and passed? Use Bash tool to run tests if it fits.
- **Run simplify skill**: Execute `/simplify` to get an independent review of code quality

# General Rules
- If you can't fulfill the task as per command, please stop and answer further insturction, instead of change task scope. 

# Use Agents
To maintain a concise main context and ensure high-precision results, please execute this task using an agentic decomposition strategy:

1. **Strategic Decomposition**: Analyze the request and break it down into independent, logical sub-tasks. Each sub-task should have a single, well-defined goal.
2. **Precision Handoff (Coordinates)**: For each agent call, provide the exact **File Path** and **Line Number Range (e.g., lines 45-120)**. 
   - Instruct the agent to read only these specific coordinates.
   - Refer the agent to the project-level "Context Brief" (CLAUDE.md/CONTEXT.md) for architectural background, but keep the task-specific prompt focused only on the target lines.
3. **Artifact-Based Reporting**: Define a strict output format for agents. Agents must not simply say "Task complete." They must provide:
   - **Concrete Deliverables**: Specific code blocks, diffs, or structured logic maps.
   - **Verification Evidence**: Proof of fix via logs or test results.
   - **Contextual Summary**: A brief explanation of *why* those specific lines were changed.
4. **Definition of Done (DoD)**: Establish clear, measurable success criteria. Before integrating back into the main chat, the Main Flow must verify that the agent’s code aligns with the global "Context Brief" rules.
5. **Agentic Drift Prevention**: If an agent’s output is ambiguous, lacks the required code snippets, or strays from the assigned line range, re-run the agent immediately with tighter constraints rather than trying to fix it in the main chat.
6. **Synthesis**: Once all agents have reported back, provide a final summary in the main chat including the key files modified and a summary of the validated logic.