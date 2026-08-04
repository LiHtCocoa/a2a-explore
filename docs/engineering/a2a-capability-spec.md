# 端侧 A2A 应用能力规格基线

核验日期：2026-08-02  
适用工程：`apps/harmonyos`  
依据：本机 HarmonyOS 26.0.0 Beta2 SDK（组件 26.0.0.32）的公开声明、实际 Release 构建，以及华为端侧 A2A / AgentExtensionAbility 官方文档。

这份规格完整枚举当前 SDK 暴露给三方应用的 Agent 容器与标准 A2A Server 编程面，并标明“当前工程已实现”“只能由框架声明”“必须上设备验证”的边界。它不把尚未观测的小艺 UI 行为或底层线缆报文猜成既定能力。

## 1. 分层与版本边界

| 层 | 主要能力 | 起始版本 | 当前工程 |
|---|---|---:|---|
| Agent 容器 | `AgentExtensionAbility` 生命周期、连接、字符串数据、认证、AgentCard context | API 24 | 已注册并实现 |
| Agent 富 UI 容器 | `AgentUIExtensionAbility`，继承通用 `UIExtensionAbility` | API 24 | 未注册；首版仍用普通应用页面 |
| AgentCard 基础模型 | 名称、skills、输入输出模式、appInfo、图标等 | API 24 | 已配置三个公开 Skill |
| AgentCard 类型 | `APP` / `ATOMIC_SERVICE` | 26.0.0 | 当前未显式填写，使用默认应用型语义 |
| 标准 A2A Server | `createA2AServer`、Task、Message、Artifact、状态和操作回调 | 26.0.0 | 已接入最小实现 |

工程因此使用 `compatibleSdkVersion` / `targetSdkVersion` 26.0.0。API 24 只证明容器存在，不能证明当前标准 A2A Server 封装可用。

## 2. 注册与发现契约

应用通过 `module.json5` 注册：

```json
{
  "name": "WordReviewAgentAbility",
  "type": "agent",
  "metadata": [{
    "name": "ohos.extension.agent",
    "resource": "$profile:agent_config"
  }]
}
```

`agent_config.json` 中的 AgentCard 是系统发现和能力匹配契约，不是展示文案的随意集合。当前公开 Skills：

```text
start_word_review_in_app
quick_word_confusion_qa
practice_word_confusion_in_app
```

### AgentCard 字段面

| 字段组 | 字段 | 作用 |
|---|---|---|
| 身份 | `agentId`, `name`, `description`, `version`, `category`, `type?` | 唯一识别、展示和版本治理 |
| 提供方 | `provider?`, `documentationUrl?` | 组织与说明入口 |
| 能力 | `capabilities?` | 声明 streaming、push、状态历史、扩展名片 |
| 模态 | `defaultInputModes`, `defaultOutputModes` | Agent 默认接受与产生的 MIME 类型 |
| 技能 | `skills[]` | `id`, `name`, `description`, `tags`, `examples?`, skill 级输入输出模式和扩展 |
| 展示 | `iconUrl`, `extension?` | Agent 图标和自定义扩展配置 |
| 应用定位 | `appInfo` | bundle、module、ability、设备类型和最低应用版本 |

本机 schema 对 `iconUrl` 只校验 1–512 字符，没有定义本地资源映射；打包通过不等于小艺能解析图标。

### 能力声明不是实现证明

| AgentCapabilities | 声明含义 | 当前值 | 证据边界 |
|---|---|---:|---|
| `streaming` | 支持流式结果 | `false` | 当前不发送分块输出 |
| `pushNotifications` | 支持任务推送通知 | `false` | 没有对应运行链路 |
| `stateTransitionHistory` | 支持状态历史 | `true` | 需设备确认系统是否返回/渲染历史；应用已提供有序状态更新 |
| `extendedAgentCard` | 支持扩展 AgentCard | `false` | 当前不使用 |

声明为 `true` 只能表示能力承诺，不能用来替代端到端测试。

## 3. Agent 容器生命周期

`AgentExtensionAbility` 提供以下回调：

| 回调 | 系统事件 | 应用职责 | 当前实现 |
|---|---|---|---|
| `onCreate(want)` | 扩展实例创建 | 从 `context.agentCard` 创建 A2A Server | 已实现，失败写 HiLog |
| `onConnect(want, proxy)` | Agent host 建立连接 | 启动 Server，保存/使用连接代理 | 已调用 `server.start()` |
| `onAuth(proxy, handshakeData)` | host 发起握手 | 交给 Server 生成应答，再调用 `proxy.authorize()` | 已实现 |
| `onData(proxy, data)` | host 发送协议数据 | 交给 `server.onMessage()`，通过 `proxy.sendData()` 回传 | 已实现 |
| `onDisconnect(want, proxy)` | 连接断开 | 停止 Server，释放连接级资源 | 已实现 |
| `onDestroy()` | 扩展销毁 | 停止并清空 Server | 已实现 |

`AgentHostProxy` 的应用可见能力只有：

- `sendData(data: string)`：向 Agent host 发送字符串数据。
- `authorize(handshakeData: string)`：回传认证握手数据。

两者都可能抛出 IPC 发送失败 `BusinessError 35600002`，设备联调必须覆盖该失败路径。

## 4. 标准 A2A Server 适配层

创建入口：

```ts
createA2AServer(agentCard, onData, want?)
```

返回的 `Server` 暴露：

| 方法 | 作用 | 当前使用 |
|---|---|---|
| `start()` / `stop()` | 控制协议服务生命周期 | 已使用 |
| `onMessage(data, sender)` | 解析 host 数据并生成回包 | 已使用 |
| `onAuth(data)` | 处理密钥协商握手 | 已使用 |
| `updateStatus(taskId, status)` | 更新 Task 状态和关联消息 | 已使用 |
| `addArtifact(taskId, params)` | 添加或追加任务产物 | 已使用一次性 JSON Artifact |

应用不应自己重复实现 Server 已封装的线缆解析；业务入口是 `OnDataCallback(method, context)`。

## 5. AgentOperation

| 操作 | 触发来源 | taskId 要求 | 当前处理 |
|---|---|---|---|
| `EXECUTE` | 新公开意图请求 | 当前实现要求存在 | 解析公开意图并生成一次性交接或系统侧结果 |
| `CANCEL` | 客户端取消 A2A Task | 当前实现要求存在 | 只取消系统协作，不删除 App 学习 session |
| `CLEAR_CONTEXT` | 清理会话上下文 | 不应强制要求 taskId | 只清理 Adapter 的 task/context 关联 |
| `PERCEPTION_SUGGEST` | 小艺请求 OnApp 建议 Chips | 不应强制要求 taskId | 仅记录日志，负载/返回契约待设备与文档确认 |

操作分派必须先判断 operation，再只对 `EXECUTE` / `CANCEL` 强制 taskId。否则无任务级 ID 的上下文清理或感知建议会被错误丢弃；当前工程已修正这一点。

## 6. RequestContext

回调可读取：

| 方法 | 数据 | 产品/工程用途 |
|---|---|---|
| `getAgentId()` | Agent 标识或 undefined | 多 Agent 路由与日志关联 |
| `getClientSessionId()` | 客户端会话 UUID 或 undefined | 连接/会话清理与跨 task 关联 |
| `getUserInput(delimiter?)` | 聚合后的用户文本 | 简单文本 skill 输入 |
| `getMessage()` | 当前 Message 或 undefined | 保留多 Part、metadata、引用任务等完整语义 |
| `getRelatedTasks()` | 相关 Task 列表 | 长任务恢复、引用历史任务 |
| `getCurrentTask()` | 当前 Task 或 undefined | 校验当前状态、恢复和幂等 |
| `getTaskId()` | Task UUID 或 undefined | 状态更新与 Artifact 归属 |
| `getContextId()` | Context UUID 或 undefined | 多轮消息归属 |
| `getMetadata()` | 自定义 metadata | 版本、幂等键、产品上下文扩展 |

当前 Adapter 使用 taskId、contextId、clientSessionId、currentTask、related task 数量、聚合文本，以及 RequestContext / Message metadata 中可能存在的 `intentId` / `intent_id` / `skillId` / `skill_id`。currentTask 只为缺失 task/context getter 提供 ID 回退；relatedTasks 不再用于恢复 App 学习会话。metadata 明确标识优先于文本回退。SDK 没有规定标准公开意图字段名，因此设备联调仍必须核对真实脱敏报文。具体入口见 [公开 Skill 契约](../product/skill-contracts.md)。

## 7. 协议数据模型

### Part

一条 Part 可携带：

- `text`：文本。
- `raw`：原始字符串数据。
- `url`：标准 `file://` / `https://` / `http://` 内容地址。
- `data`：对象、数组、字符串、数字或布尔值形式的 JSON 数据。
- `mediaType`、`filename`、`metadata`。

当前消息使用 `text/plain + text`；应用交接和系统侧快速结果使用 `application/json + raw`。

### Message

必填：`messageId`、`role`、至少一个 `parts` 元素。可选：`contextId`、`taskId`、`extensions`、`metadata`、`referenceTaskIds`。

约束：

- messageId 必须是消息创建者生成的 UUID，不能在多个状态消息中复用 taskId。
- 服务端任务消息应关联 contextId，并在已有 Task 时关联 taskId。
- Role 为 `AGENT`、`USER` 或 `UNSPECIFIED`。

当前工程为每条服务端消息生成独立 UUID，携带 taskId，并在 RequestContext 提供时携带 contextId。

### Task / TaskStatus

Task 包含 `id`、`contextId`、当前 `status`，以及可选 `artifacts`、`history`、`metadata`。TaskStatus 包含 `state`，以及可选 ISO 8601 `timestamp` 和关联 Message。

Adapter 必须把 taskId 视为 A2A 系统协作主键。App Agent 的 sessionId 属于应用权威数据源，可以记录来源 task/context 关联，但不能被 A2A Task 替代。

### Artifact / TaskArtifactParam

Artifact 是 Task 的结构化输出，至少包含一个 Part。可带 name、description、metadata、extensions。

`addArtifact()` 还支持：

- `append`：追加到已有 Artifact。
- `lastChunk`：标记最后一个分块。
- `artifactId`：可选 GUID；若应用提供，必须使用 UUID。

当前工程使用独立 UUID、`lastChunk: true` 的一次性应用交接或快速解释 JSON。Streaming 开启前，应先在设备上验证 append / lastChunk 的组合和系统渲染。

## 8. TaskState 及产品语义

| 状态 | 协议含义 | 回声词伴语义 | 当前覆盖 |
|---|---|---|---|
| `SUBMITTED` | 已提交 | 系统已接收公开意图请求 | 由客户端/Server 创建 |
| `WORKING` | 执行中 | Adapter 正在解析并准备交付 | 已更新 |
| `INPUT_REQUIRED` | 等待输入 | 仅未来系统确认/授权需要时使用 | 当前公开 Skill 不使用 |
| `COMPLETED` | 成功完成 | 交接请求或系统侧短结果已形成；不等于学习完成 | 已更新 |
| `CANCELED` | 已取消 | 系统协作取消，App session 不受影响 | 已更新 |
| `FAILED` | 执行失败 | 可重试的协议/适配故障 | 已实现、设备待验 |
| `REJECTED` | 请求被拒绝 | 不支持的公开意图，或系统能力尚未验证 | 已实现 |
| `AUTH_REQUIRED` | 任务需授权 | 跳转应用内安全授权 | 未实现；不同于连接握手 |
| `UNSPECIFIED` | 未指定 | 只能作为异常兜底，不应用作正常 UX | 未使用 |

A2A 状态更新描述系统协作，不承载 App 学习状态。当前三个公开 Skill 都是一次性交付；未来系统授权可引入 `INPUT_REQUIRED`，但不得借此把完整教学流程重新搬回小艺侧。

## 9. AgentUIExtensionAbility

本机声明显示它只是 `UIExtensionAbility` 的 Agent 专用子类，模块注册类型为 `agentUI`，没有额外 A2A 协议方法；具体页面生命周期沿用 UIExtensionAbility。已知限制包括 Agent UI extension 不能创建子窗口。

对本产品的决策：

- 首版高密度学习交互继续放在普通应用页面，由 App Agent 独立维护学习连续性。
- 只有当真机证明确实需要系统内嵌富 UI，才新增 `agentUI` extension。
- 不把“类和 module type 存在”解释为小艺一定会以某种卡片样式渲染。

## 10. 当前工程覆盖矩阵

| 能力 | 状态 | 证据或缺口 |
|---|---|---|
| agent extension 注册与 metadata | 已编译 | Release HAP 包内 manifest |
| AgentCard 与三个公开 Skill | 已编译 | 包内 `agent_config.json` 0.4.0 |
| create/start/stop Server | 已实现、未运行验证 | ArkTS 类型检查与 HAP |
| host 字符串收发 | 已实现、未运行验证 | `onData → onMessage → sendData` |
| 认证握手 | 已实现、未运行验证 | `onAuth → authorize` |
| EXECUTE / CANCEL | 已实现、未运行验证 | 公开意图一次性交付；取消不触碰 App session |
| CLEAR_CONTEXT | 已清理 Adapter 内存态 | 按 contextId 删除 task 关联；不触碰 App session |
| PERCEPTION_SUGGEST | 仅日志 | Chips 契约未知 |
| WORKING / COMPLETED / CANCELED | 已实现、未运行验证 | 编译通过；云设备待验 |
| INPUT_REQUIRED | 当前 Skill 未使用 | 留给未来系统确认/授权场景 |
| FAILED | 已实现、未运行验证 | 领域执行异常进入 `FAILED` |
| REJECTED | 已实现、未运行验证 | 无关输入、未知 ID、未验证系统能力路由测试通过 |
| AUTH_REQUIRED | 未实现 | 需要账号、权限或隐私授权场景 |
| Message / Artifact UUID | 已实现 | `util.generateRandomUUID()` |
| Artifact 一次性 JSON | 已实现、未渲染验证 | `lastChunk: true` |
| streaming / append | 未实现 | AgentCard 为 false |
| push notifications | 未实现 | AgentCard 为 false |
| App 学习会话 | 领域原型已实现、尚未接正式 App Agent 数据服务 | ReviewTaskEngine/Preferences 验证提示与证据恢复算法 |
| current/related tasks | Adapter 仅做协议关联 | 不再用于恢复 App 学习会话 |
| 多进程共享状态 | 未实现 | 正式 App Agent 需单写者数据服务或关系型存储 |
| AgentUIExtensionAbility | 未实现 | 普通应用页面承担学习 UI |
| 图标解析、Agent 发现、小艺 UI | 未验证 | 必须签名包 + 设备 |

“已实现、未运行验证”只证明应用代码和 SDK 类型对齐，不证明系统服务已接受或小艺已正确展示。

## 11. 日志与故障规范

每次真实运行至少记录：

```text
runId
agentId
clientSessionId
taskId
contextId
operation
previousState
nextState
messageId
artifactId
durationMs
errorCode
```

当前实现已在 operation、TaskStatus 和 Artifact 路径记录上述核心关联字段；errorCode 目前以捕获到的 BusinessError/序列化错误文本保留，云调试后再根据真实错误对象补充稳定的数值字段。

不得记录账号凭据、认证原文或完整敏感语音文本。以下故障必须进入明确状态或可观测日志：

- Server 创建、start/stop 失败。
- `sendData` / `authorize` 的 IPC 错误。
- 缺失 taskId/contextId 或非法 UUID。
- 非法/重复状态迁移。
- Artifact 序列化、追加和结束标志错误。
- 不支持的 skill 或输入模态。
- 领域执行异常、超时和用户取消竞态。

## 12. 设备验证顺序

1. Release 签名、安装、冷启动与 HiLog。
2. AgentCard 注册、Agent 发现、图标和示例话术命中。
3. 连接、认证、一次字符串请求与成对断连。
4. 三个公开 Skill 的 `WORKING → COMPLETED`、JSON Artifact 与 metadata。
5. 复习/深练交接的真实 Want/CTA，以及交接后默认结束 A2A 的行为。
6. 快速辨析只在系统侧返回短结果，不自动进入 App 深度练习。
7. `CANCEL → CANCELED` 和 `CLEAR_CONTEXT` 均不影响 App 学习 session。
8. `FAILED` / `REJECTED` / `AUTH_REQUIRED` 的系统展示。
9. 系统提醒与显式系统伴随单独验证，未验证前不加入 AgentCard。
10. 最后再验证 streaming、push、Agent UI 和 `PERCEPTION_SUGGEST`。

## 13. 当前仍存在的 SDK/文档歧义

- AgentCard schema 允许普通非空 `agentId` 字符串，而 `RequestContext.getAgentId()` 注释称返回 UUID；两者是否为同一标识需设备证据。
- `AgentCard.type` 注释提到 `LOW_CODE`，但本机 `AgentCardType` 只导出 `APP` / `ATOMIC_SERVICE`，当前工程不依赖该不一致内容。
- `iconUrl` 没有本地资源路径解析规则。
- capabilities 标志没有在本机 A2A Server 表面暴露对应的完整运行控制接口。
- `PERCEPTION_SUGGEST` 只有操作枚举，当前声明没有给出 OnApp Chips 专用返回结构。

这些项均不得以猜测补齐；应把实际设备报文、HiLog 和可见 UI 归档后再更新规格。

## 参考

- [方舟智能开发框架概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkaf-overview)
- [端侧 A2A 框架概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-overview)
- [AgentExtensionAbility 配置文件说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-extension-configuration)
- [A2A 协议 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/hmaf-a2a-protocol)
- [A2A 开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hmaf-a2a-dev-guide)
- [端 A2A 协议技术规范](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-device-0000002624952279)
- [端 A2A 协议消息指令定义](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-device-commands-0000002594605828)
