# A2A 协作状态与应用学习状态的双模型

修订日期：2026-08-02  
依赖：[公开意图与 A2A 通信目的模型](intent-and-a2a-model.md)

## 为什么必须是两个状态机

A2A TaskState 描述“小艺与应用公开 Agent 的协作进行到哪”，不等于“用户在应用里学到哪个词”。应用内 Agent 必须在没有小艺连接时也能独立完成学习。

```text
A2A 协作状态机                    App 学习状态机
SUBMITTED                         SESSION_CREATED
WORKING                           RECALLING
INPUT_REQUIRED                    HINT_1 / HINT_2
COMPLETED                         FEEDBACK
CANCELED / FAILED / REJECTED      TRANSFER / REVIEW_SUMMARY
```

两者通过公开意图、session reference 和最小投影关联，而不是共享一个枚举。

## A2A 状态只服务通信目的

| A2A 状态 | 协作含义 | 系统侧可表达 | 不能推断 |
|---|---|---|---|
| `SUBMITTED` | 小艺已向应用公开 Agent 提交请求 | 正在联系应用 | App 已创建学习会话 |
| `WORKING` | Adapter/App Agent 正在解析意图或生成结果 | 正在准备入口、短答或计划参数 | 用户正在应用内答题 |
| `INPUT_REQUIRED` | 当前系统协作需要用户在小艺侧确认/补充 | 选择“去应用”、确认时间、授权或澄清 | App 内正在等待某词答案 |
| `COMPLETED` | 本次系统协作目的已完成 | 已给出短答、已完成交接、系统计划已确认 | App 学习任务已经完成 |
| `CANCELED` | 用户取消当前系统协作 | 不再继续跳转/计划/伴随 | App 本地 session 必须被删除 |
| `FAILED` | 协作执行失败 | 提供重试或进入 App 的替代路径 | App 内数据一定失败 |
| `REJECTED` | 应用不支持该公开意图 | 解释能力边界 | 应用不能处理任何相邻任务 |
| `AUTH_REQUIRED` | 系统协作需要授权 | 由系统侧提供安全授权路径 | 应用可以索取敏感凭据 |

关键修正：`COMPLETED` 可以只表示“成功把用户交接到 App”，并不表示三词复习完成。

## 按意图定义状态路径

### 应用交接

```text
SUBMITTED
  → WORKING（解析入口与实体）
  → INPUT_REQUIRED（可选：小艺侧确认“打开应用”）
  → COMPLETED（系统完成交接）
```

App 拉起后进入自己的 `SESSION_CREATED → RECALLING ...`，默认不再依赖 A2A。

### 系统侧快速问答

```text
SUBMITTED
  → WORKING（App Agent 生成最小结果）
  → COMPLETED（小艺系统 UI 展示结果与可选 App 入口）
```

如果问题缺少词对，可用 `INPUT_REQUIRED` 在小艺侧澄清，不应先打开 App。

### 系统计划/提醒

```text
SUBMITTED
  → WORKING（归一化时间与内容引用）
  → INPUT_REQUIRED / AUTH_REQUIRED（系统确认或授权）
  → COMPLETED（收到系统计划确认）
```

在没有真实系统计划 ID 或成功回执前不得进入 `COMPLETED`。

### 显式系统伴随

```text
SUBMITTED → WORKING → COMPLETED（建立投影）
                    ↘ 后续查询/取消形成新的协作消息或 Task
```

是否用一个长 Task 或多个短 Task 必须依据小艺实际协议行为确定。无论哪种方式，App session 都是业务权威，A2A 断开只会让系统投影暂时不可用。

## App 学习状态

首版应用内 Agent 使用独立状态：

```text
IDLE
  → PLANNING
  → RECALLING
  → HINT_1 → RECALLING
  → HINT_2 → RECALLING
  → FEEDBACK
  → TRANSFER（需要时）
  → NEXT_ITEM / SUMMARY
```

学习不变量保持不变：提示后再次回忆、解释后置、一条作答只生成一条证据、取消不伪装完成。

## 最小关联对象

```json
{
  "publicIntent": "START_REVIEW_IN_APP",
  "a2aTaskId": "optional-system-task-id",
  "appSessionRef": "opaque-app-owned-reference",
  "appRoute": "review/start",
  "projectionVersion": 1
}
```

`appSessionRef` 由应用拥有；系统侧不需要获得完整学习快照。实际能否通过 Want/metadata 传递这些字段仍需设备验证。

## UI 原型规则

- 小艺系统侧和 App 页面必须画在清晰分隔的两个表面中。
- 系统侧只展示应用能提供的语义信息，不模拟可由应用任意设计的系统卡片布局。
- App 内不得出现“小艺伴随任务”控制卡作为真实产品组件。
- 原型必须标注当前 A2A 是否已结束、正在等待系统确认，还是显式保持投影。
- “打开 App”与“继续 A2A”是两个独立决策。
