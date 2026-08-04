# App Agent 与可选 A2A 投影桥接

状态：设备证据前的架构基线  
核验日期：2026-08-02

## 当前事实

- `WordReviewAgentAbility` 0.4.0 已改为公开意图 Adapter，不再直接调用 `ReviewTaskEngine` 或 Preferences repository。
- ArkUI 已覆盖今日抽背、深度理解和本地恢复，并明确显示“交接完成后 A2A 关闭”与“App Agent 会话继续”两套状态。
- ArkUI 与 Agent 已共同引用 `domain/LearningContent.ets`，因此词库、提示、答案与迁移情境不会分叉；实时 task 状态仍未打通。
- Preferences 官方约束不支持多进程并发访问。没有设备证据前，不能假设 UIAbility 与 AgentExtensionAbility 永远位于同一进程，也不能让两侧直接打开同一个 Preferences 实例。

因此，当前可以证明“协议状态机”和“应用交互”分别正确，但不能证明小艺入口打开应用后会自动落到同一题。产品文案和验收记录必须保留这个边界。

## 目标契约

App Agent 的学习 session 应成为业务权威；只有需要系统 UI 或系统能力时才建立 A2A 投影：

```text
App Agent 学习 session
  ├─ App UI：当前题、提示层级、证据与复盘
  └─ 可选 A2A Projection
       └─ taskId / contextId / publicIntent / system capability status
```

最小投影字段：

| 字段 | 用途 |
|---|---|
| `taskId` | 可选的协议协作主键，不替代应用 session |
| `contextId` | 多轮归属与显式恢复 |
| `skillId` | 系统发现命中的公开 Skill，不作为 App 内命令 |
| `interactionMode` | `APP_HANDOFF`、`SYSTEM_RESULT` 等系统协作方式 |
| `appSessionRef` | 应用拥有的不透明会话引用 |
| `publicIntent` | 交接、短答、计划或显式伴随 |
| `projection` | 系统目的所需的最小只读摘要 |
| `taskState` | 当前 A2A 协作状态，不等于 App 学习状态 |
| `updatedAt` | 冲突判断与恢复排序，不作为主键 |

不得让 A2A Task 反向覆盖长期学习事实，也不得通过跳到某页来冒充 App session 恢复。

## 设备证据前不做的假设

- 不假设系统打开应用时一定通过某个固定 Want parameter 传递 taskId。
- 不假设 `RequestContext.getMetadata()` 中一定存在标准公开意图字段；当前兼容 `intentId` / `intent_id` / `skillId` / `skill_id`。
- 不假设 UIAbility 和 AgentExtensionAbility 同进程。
- 不让 UI 与 Agent 同时写 `echo_word_review_sessions` Preferences。
- 不在未观察到系统跳转行为前注册虚构的 URI scheme 或 AgentUIExtensionAbility。

## 首轮云机必须采集的桥接证据

1. 分别记录 `EchoWordEntry` 与 `EchoWordAgent` 的进程 ID，确认是否同进程以及重建行为。
2. 从小艺的应用交接入口打开应用，记录 EntryAbility 收到的 Want action、URI 与 parameters 的字段名；值需脱敏。
3. 检查公开意图、实体、appSessionRef 或等价引用是否实际传递；不要预设一定传 taskId。
4. 验证后台、杀 Agent 进程、杀 UI 进程三种情况下，哪一侧被重建以及 Task 是否仍可定位。
5. 检查交接完成后 A2A Task 是否结束，以及 App session 是否在无 A2A 连接时继续运行。

这些证据应放入 `artifacts/debug/YYYY-MM-DD/<run-id>/bridge.md`，并附相应 HiLog 与截图。

## 证据后的实现分支

### A. 框架提供稳定 Task 引用与同进程保证

若设备证明系统交接携带稳定应用会话引用，且 UI/Agent 在同一进程，可将 App Agent repository 提升为应用级单例单写者；A2A Adapter 只读取最小投影。

### B. 有稳定 Task 引用，但 UI/Agent 不同进程

采用单写者数据服务或支持明确跨进程访问的存储组件。App Agent 负责学习状态，A2A Adapter 按公开意图读取投影；禁止两侧各自维护可写学习缓存。

### C. 系统跳转不携带稳定 Task 引用

应用不能自动声称恢复同一 Task。首版应在 UI 中展示“从小艺继续需要重新确认任务”，并让用户从活动 task 列表选择；同时把缺失字段和系统行为作为平台问题记录，而不是用最近一条 context 猜测。

## 完成判据

状态桥接只有同时满足以下条件才算完成：

- 小艺交接到 App 后，App Agent 能依据公开意图创建或恢复正确的应用 session。
- 没有 A2A 连接时，App 内学习仍可完整运行并持久化。
- 只有显式伴随场景中，UI 动作才更新系统最小投影，且不重复生成学习证据。
- A2A `COMPLETED` 能明确区分“交接完成”“短答完成”“计划确认”和“学习完成”。
- UI/Agent 任一进程重建后仍能恢复；并发写入测试没有丢失或覆盖。
- 日志可以用 runId、taskId、contextId、publicIntent、interactionMode、continuation 串起系统入口、交接与 Artifact；App session 使用自己的关联 ID。
