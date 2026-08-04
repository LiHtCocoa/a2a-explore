# 公开意图与 A2A 通信目的模型

修订日期：2026-08-02  
依赖：[系统 Agent、应用 Agent 与 UI 职责模型](agent-responsibility-model.md)

## 三层概念必须分开

| 层 | 示例 | 作用 |
|---|---|---|
| 协议 operation | `EXECUTE`、`CANCEL`、`CLEAR_CONTEXT` | A2A 连接上的传输动作，不说明业务目的 |
| 公开产品意图 | `START_REVIEW_IN_APP`、`QUICK_CONFUSION_QA` | 系统 Agent 可以发现和请求的应用能力 |
| 应用内部命令 | `REQUEST_HINT`、`SUBMIT_RECALL`、`GENERATE_TRANSFER` | App Agent 内部演进，不应全部暴露为 AgentCard Skill |

当前工程把多轮单词作答直接放进 `EXECUTE` 是过度耦合。V0.4 起，A2A Adapter 应先得到公开产品意图，再决定通信生命周期。

## 六种通信目的

| 目的 | 典型用户话术 | 小艺侧职责 | App Agent 职责 | 默认连接策略 |
|---|---|---|---|---|
| 发现与交接 | “打开回声词伴复习今天的词” | 匹配应用、确认并引导进入 App | 接收意图，创建本地学习会话 | 交接确认后结束 A2A |
| 系统侧快速问答 | “resilient 和 resistant 有什么区别” | 在系统 UI 展示简短结果和进入 App 的可选入口 | 生成最小解释或一题判断结果 | 返回结果后结束 |
| 应用内深度任务 | “用练习帮我真正区分这两个词” | 识别深度练习并拉起 App | 完成迁移题、反馈、复测安排 | 默认交接后结束 |
| 查询应用状态 | “我上次学到哪里了” | 在系统 UI 展示最小摘要 | 查询长期学习数据并返回只读投影 | 查询完成后结束 |
| 委托系统能力 | “每天晚上九点提醒我复习” | 处理系统计划 UI、授权和执行 | 给出内容引用、建议时间并保存系统计划关联 | 直到系统确认/失败 |
| 显式系统伴随 | “我退出应用后继续在小艺里显示进度” | 保持系统任务 UI、继续/取消入口 | 推送最小进度投影并处理跨界面命令 | 仅用户明确需要时维持 |

计划/提醒等具体系统能力、返回 ID 和权限行为必须在云设备核验，当前只定义产品意图，不虚构报文字段。

## 公开意图目录 V0.1

### `START_REVIEW_IN_APP`

- 目标：把用户交接到 App，启动到期/易错词复习。
- 实体：目标数量、词表范围、是否恢复、来源话术。
- App route：`review/start` 或 `review/resume`。
- 默认 continuation：`COMPLETE_AFTER_HANDOFF`。
- App Agent 接管：选择词、教学策略、提示、复盘和个性化。

### `QUICK_CONFUSION_QA`

- 目标：在系统 UI 内快速解释两个词的关键区别。
- 实体：wordA、wordB、可选最近错误上下文。
- 输出：一条最小解释、一个示例和“去应用练习”建议；不在小艺侧模拟完整训练。
- 默认 continuation：`COMPLETE_AFTER_RESULT`。

### `PRACTICE_CONFUSION_IN_APP`

- 目标：进入 App 做先判断后解释的深度练习。
- 实体：wordA、wordB、触发错误或来源 session。
- App route：`confusion/practice`。
- 默认 continuation：`COMPLETE_AFTER_HANDOFF`。

### `QUERY_LEARNING_PROGRESS`

- 目标：向系统侧返回“上次学到哪、今天还有多少”等最小摘要。
- 输出不得包含完整答案历史或不必要的原始作答文本。
- 默认 continuation：`COMPLETE_AFTER_RESULT`。

### `SCHEDULE_REVIEW_WITH_SYSTEM`

- 目标：让小艺/系统能力创建或修改复习计划。
- 实体：时间表达、重复规则、内容范围、时区。
- 需要系统确认、授权、计划 ID 与失败原因；当前为设备待验意图。
- 默认 continuation：`WAIT_FOR_SYSTEM_CONFIRMATION`。

### `ENABLE_SYSTEM_COMPANION`

- 目标：用户明确要求在离开 App 后继续使用系统 UI 查看进度或控制任务。
- 这是长时 A2A 的显式入口，不是所有复习任务的默认行为。
- 默认 continuation：`KEEP_MINIMAL_PROJECTION`。

## 归一化意图信封

下面是 App 内部的适配对象，不是假设小艺一定按此 JSON 发报文：

```json
{
  "schema": "learning.public-intent.v1",
  "intent": "START_REVIEW_IN_APP",
  "source": "xiaoyi",
  "interactionMode": "APP_HANDOFF",
  "continuation": "COMPLETE_AFTER_HANDOFF",
  "entities": {
    "count": 10,
    "scope": "due_and_weak",
    "resume": false
  },
  "appRoute": "review/start",
  "systemCapability": null
}
```

A2A Adapter 的工作是从 AgentCard Skill、metadata、Message Parts 和文本中构造这个对象。若平台提供稳定意图 ID，应优先使用；文本解析只做兼容回退。

## 连接是否继续的决策

```text
公开意图已识别
  ├─ 只需系统侧展示一个结果？
  │    └─ 返回结果后结束
  ├─ 主要体验在 App？
  │    ├─ 不再需要系统能力 → 完成交接后结束
  │    └─ 仍需计划/系统 UI → 保留最小投影
  └─ 用户明确要求系统伴随？
       └─ 维持 Task，但 App Agent 仍是业务状态权威
```

## 场景细化

### 场景 A：今日抽背

1. 用户对小艺说“陪我复习今天到期的单词”。
2. 小艺匹配 `START_REVIEW_IN_APP`，展示系统确认或应用入口。
3. 系统拉起 App，并尽可能传递公开意图与实体。
4. App Agent 查询到期词和用户画像，创建本地 session。
5. 默认不维持 A2A；答题、提示和复盘全部在 App 内完成。
6. 用户另行要求提醒或系统伴随时，才创建相应系统协作。

### 场景 B：易混词快速问答

1. 用户问两个词的区别。
2. 小艺通过 A2A 请求 `QUICK_CONFUSION_QA`。
3. App Agent 返回简短差异和一个例子，小艺在系统 UI 展示。
4. 用户选择“去练习”后再交接到 `PRACTICE_CONFUSION_IN_APP`。

### 场景 C：计划明晚复习

1. App Agent 在复盘中建议明晚复测。
2. 只有用户选择“让小艺提醒我”时，才进入 `SCHEDULE_REVIEW_WITH_SYSTEM`。
3. 小艺负责系统确认、授权与计划执行；App 保存关联结果，但不伪造系统计划成功。

### 场景 D：显式伴随

1. 用户主动要求离开 App 后仍在系统侧看进度。
2. App Agent 继续本地学习任务，A2A Task 只发布完成数、当前阶段和可执行命令。
3. 小艺系统 UI 的布局、卡片和通知由系统决定。
4. 断开 A2A 不得损坏 App 内学习 session；重新连接时重新生成投影。

## 需要设备证据的字段

- 小艺实际如何触发 App 交接，以及 EntryAbility 收到的 Want/action/URI/parameters。
- AgentCard Skill 或 RequestContext metadata 是否携带稳定意图/Skill ID。
- 系统计划能力通过什么指令、Part 或扩展表达，如何返回计划 ID。
- `PERCEPTION_SUGGEST` 与系统 Chips 在上述入口中的真实作用。
- 完成 A2A Task 后是否仍能保留系统 CTA，以及 CTA 如何关联应用路由。
