# App Agent 学习会话持久化与恢复设计

实现日期：2026-08-02  
领域原型位置：`entry/src/main/ets/data/ReviewSessionStore.ets`、`domain/ReviewTaskEngine.ets`

> 重要：这里描述的是 App Agent 的学习 session 设计，不是默认 A2A Task 持久化。`WordReviewAgentAbility` 0.4.0 已不再直接加载、修改或删除这些快照；A2A Task 只描述系统协作。

## 目标

长时抽背不能把“页面重新打开”当成恢复。App Agent 或其未来的数据服务重建、用户重新进入应用、或公开意图要求继续上次学习时，都应恢复：

- 当前词序号。
- 已使用的提示层级。
- 已完成词及 outcome。
- 学习模式与易混词判断证据。
- App sessionId，以及可选的来源 taskId / contextId 关联。

## 快照结构

```json
{
  "schemaVersion": 2,
  "taskId": "UUID",
  "contextId": "UUID",
  "mode": "review",
  "currentIndex": 1,
  "hintLevel": 1,
  "attempts": [
    { "word": "resilient", "outcome": "hinted", "hintLevel": 1 }
  ],
  "confusionAttempts": [],
  "updatedAt": "2026-08-02T02:00:00.000Z"
}
```

`mode` 为 `review` 或 `confusion`。易混词模式会把选择、是否正确和提示层级写入 `confusionAttempts`。不持久化原始用户语音/文本答案，只保存完成恢复和学习统计所需的最少证据。

## 存储选择

当前领域原型使用 Agent 进程独占的 ArkData Preferences，这一实现早于职责重构，保留用于验证恢复算法：

- `getPreferencesSync()` 在 `onCreate()` 时取得实例。
- 所有活动会话仍以 `sessions_v1` JSON 数组保存；这是 Preferences 集合键名，不等同于快照 schema 版本。
- 当前快照 schema 为 v2；读取 v1 快照时自动补充 `mode: review` 与空 `confusionAttempts`，再按 v2 保存。
- 每次提示层级或 attempts 变化后 `putSync()` + `flushSync()`。
- 完成、取消或 CLEAR_CONTEXT 后立即删除并 flush。

选择同步 API 是因为当前数据只有少量短 JSON，且 A2A operation callback 本身为同步 `void`。真实设备必须测量 flush 延迟；若写入影响交互，改为内存先行、串行异步落盘，同时维持状态更新的顺序保证。

Preferences 官方声明不适合多进程并发访问。正式接入 App Agent 时，应由 App 侧单写者数据服务、关系型数据库或 DataShare 承担权威存储；不能让 A2A Adapter 成为学习事实所有者。

## 领域原型恢复算法

```text
1. RequestContext.getTaskId()，缺失时回退 currentTask.id
2. 用 taskId 直接加载快照
3. 若没有：按 relatedTaskIds 顺序查找活动快照
4. 若仍没有且用户明确说“继续/恢复”：加载同 context 最新快照
5. 恢复成功时把快照所有权迁移到当前 taskId
6. 返回当前词、完成数量和提示层级，不把“继续”误判为一次答案
7. 只有没有任何可恢复快照时才创建新会话
```

这些 task/context 规则仅用于验证旧领域原型的迁移算法。0.4.0 公开 Adapter 不再用 related task 恢复学习会话；App Agent 应根据公开意图中的最小实体和自身 session 索引决定恢复策略。

## 生命周期规则

| 事件 | 持久化行为 |
|---|---|
| 新 task | 创建 schema v2 快照，并记录 `mode` |
| 提示 1 / 2 | 更新 hintLevel 并 flush |
| 本词作答 | 追加一次 attempt，进入下一词并 flush |
| 易混词提示/判断 | 保存 hintLevel；完成时记录 confusion attempt 并删除活动快照 |
| 进程重建 | 同 taskId 直接加载 |
| related task 继续 | 删除旧 task key，迁移到新 taskId |
| 生成复盘 | 先构造 Artifact，再删除活动快照 |
| App 内明确放弃会话 | 由 App Agent 按产品规则删除或归档 session |
| A2A `CANCEL` | 只取消系统协作，不触碰 App session |
| A2A `CLEAR_CONTEXT` | 只清理 Adapter 关联，不触碰 App session |
| 存储运行异常 | operation 进入 `FAILED`，而不是假装恢复成功 |

## 自动验证

`apps/harmonyos/tools/review-engine-smoke.mjs` 直接读取真实 `.ets` 领域源文件，使用 DevEco 自带 TypeScript 仅做测试环境转译，并验证：

- 引擎重建后同 task 恢复提示层级。
- related task 会迁移当前词和 attempts。
- 明确恢复意图可从同 context 最新会话恢复。
- 普通新 task 不会因为 context 相同而误吞并旧会话。
- 部分 Artifact 使用实际完成数和提示依赖。
- 易混词首次响应不泄露解释，提示可跨引擎重建恢复，正确/错误选择分别形成真实证据。
- 两种模式生成各自的 Artifact type，完成后都清理活动快照。
- 完成、取消与 CLEAR_CONTEXT 清理活动快照。

该测试证明 App Agent 候选领域算法，不证明 0.4.0 A2A 流程会驱动这些步骤，也不证明 HarmonyOS Preferences 在设备上的文件行为。

## 待验证与演进

- Preferences `flushSync()` 在云设备上的时延和失败码。
- Agent extension 是否可能被配置或系统调度到多进程。
- 系统重启、应用升级，以及 v1 → v2 之外的后续 schemaVersion 迁移。
- related tasks 的顺序和小艺实际提供时机。
- Task 已完成但本地删除前崩溃时的幂等清理。
- 持久化数据的保留期限与用户清除入口。
