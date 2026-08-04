# 公开 Skill 与 A2A 交付契约

实现版本：`0.4.0`  
AgentCard：`apps/harmonyos/entry/src/main/resources/base/profile/agent_config.json`

这三个 Skill 描述小艺系统 Agent 与应用公开 Agent 的协作目的，不描述 App 内部教学步骤。A2A operation、公开产品意图和 App Agent 内部命令是三个不同层级。

## 共同边界

- 小艺负责系统入口、系统 UI、适合系统侧展示的短结果，以及应用无法直接执行的系统能力。
- A2A Adapter 只解析公开意图并返回一次性交付结果，不持有完整学习会话。
- App Agent 拥有当前词、提示层级、作答证据、个性化策略和长期学习事实。
- 应用交接完成后默认 `COMPLETED` 并结束本次 A2A 协作；该状态只表示系统协作完成，不表示学习完成。
- 当前 Adapter 不调用或虚构 `startAbility()`；交接 Artifact 使用 `REQUESTED_NOT_OBSERVED`，真实跳转由小艺/系统侧行为和设备验证决定。
- `CANCEL` 只取消系统协作，不能删除或改写 App 学习 session；`CLEAR_CONTEXT` 只清理 Adapter 的 task/context 关联。

## `start_word_review_in_app`

| 项目 | 契约 |
|---|---|
| 公开意图 | `START_REVIEW_IN_APP` |
| 典型话术 | “陪我复习今天到期的单词”“抽背十个易错词”“打开回声词伴继续上次复习” |
| 交互模式 | `APP_HANDOFF` |
| A2A 状态 | `WORKING → COMPLETED` |
| Artifact | `learning.app-handoff.v1` |
| continuation | `COMPLETE_AFTER_HANDOFF` |
| App route | `review/start` |

Artifact 只携带公开意图、应用定位、最小实体和 `handoffStatus: REQUESTED_NOT_OBSERVED`。进入 App 后，由 App Agent 决定新建还是恢复本地会话。

## `quick_word_confusion_qa`

| 项目 | 契约 |
|---|---|
| 公开意图 | `QUICK_CONFUSION_QA` |
| 典型话术 | “resilient 和 resistant 有什么区别”“我总是混淆 resilient 和 resistant” |
| 交互模式 | `SYSTEM_RESULT` |
| A2A 状态 | `WORKING → COMPLETED` |
| Artifact | `learning.quick-confusion-answer.v1` |
| continuation | `COMPLETE_AFTER_RESULT` |

系统侧只返回最小解释，不模拟完整训练。Artifact 可提供 `appContinuation.publicIntent: PRACTICE_CONFUSION_IN_APP`，但不得自动启动深度练习。

## `practice_word_confusion_in_app`

| 项目 | 契约 |
|---|---|
| 公开意图 | `PRACTICE_CONFUSION_IN_APP` |
| 典型话术 | “用一个情境帮我区分 resilient 和 resistant”“打开应用练习这两个词” |
| 交互模式 | `APP_HANDOFF` |
| A2A 状态 | `WORKING → COMPLETED` |
| Artifact | `learning.app-handoff.v1` |
| continuation | `COMPLETE_AFTER_HANDOFF` |
| App route | `confusion/practice` |

情境判断、解释时机、作答证据和复测计划全部属于 App Agent 的内部学习流程。

## 当前不声明的系统能力

`SCHEDULE_REVIEW_WITH_SYSTEM` 与 `ENABLE_SYSTEM_COMPANION` 已进入产品意图模型，但当前不写入 AgentCard Skill：

- 目标设备上的系统计划/提醒调用契约尚未验证。
- 退出应用后的系统伴随、最小进度投影和关闭语义尚未验证。
- 文本路由命中这两类请求时返回 `REJECTED`，原因分别为 `system_capability_not_verified` 与 `system_companion_not_verified`，不生成伪造的计划 ID 或成功 Artifact。

## metadata 路由

本机 API 26 的 `RequestContext` 没有强类型 public intent getter。Adapter 按以下顺序读取 RequestContext metadata，再读取 Message metadata：

```text
intentId → intent_id → skillId → skill_id
```

明确 ID 优先于文本回退。Message 和 Artifact metadata 写入：

```text
publicIntent
skillId
interactionMode
continuation
```

设备联调必须核对小艺实际提供的稳定字段名和脱敏报文；当前兼容字段不是对系统协议的最终假设。
