# 本机 SDK 能力矩阵

核验日期：2026-08-02

## 环境

| 项目 | 本机证据 |
|---|---|
| DevEco Studio | 26.0.0.621，build `261.23567.138.36.2600621` |
| SDK | HarmonyOS 26.0.0 Beta2，API 26，组件版本 26.0.0.32 |
| Hvigor | 6.26.2 |
| Hvigor OHOS Plugin | 6.26.2 |
| OHPM | 26.0.0.410 |

IDE：`E:\DevEnviorment\DevEco Studio`  
SDK：`E:\DevEnviorment\DevEco Studio\sdk\default`

## 声明核验

| 能力 | SDK 声明起始版本 | 本机声明位置 | 结论 |
|---|---:|---|---|
| `AgentExtensionAbility` | API 24 | `openharmony/ets/api/@ohos.app.agent.AgentExtensionAbility.d.ts` | API 24 提供 Agent 生命周期、连接、数据、认证和断连回调 |
| `AgentUIExtensionAbility` | API 24 | `openharmony/ets/api/@ohos.app.agent.AgentUIExtensionAbility.d.ts` | API 24 提供 Agent 富 UI 容器 |
| `AgentCard` | API 24 | `openharmony/ets/api/application/AgentCard.d.ts` | API 24 提供能力名片和 skills 描述 |
| `createA2AServer` | 26.0.0 | `hms/ets/api/@hms.ai.A2A.d.ts` | 完整标准 A2A Server 需要 26.0.0 |
| `TaskState` / `Artifact` | 26.0.0 | `hms/ets/api/@hms.ai.A2A.d.ts` | UX 状态与结构化产物映射只能在该 API 上直接实现 |
| `PERCEPTION_SUGGEST` | 26.0.0 | `hms/ets/api/@hms.ai.A2A.d.ts` | OnApp Chips 入口存在，但负载和系统渲染仍需真机验证 |
| `AgentFrameworkKit` UI 控件 | 6.0.0(20) 起 | `hms/ets/api/@hms.ai.AgentFramework.d.ets` | 与 A2A Server 不是同一版本边界 |

## 对原始判断的修正

“端侧 A2A 需要 API 24”只描述了 Agent 容器相关系统能力的最低边界。若采用当前官方 `createA2AServer` 封装来管理 Task、Message、Artifact 和状态，则项目最低兼容版本应为 26.0.0，除非另行实现和验证 API 24 下的底层协议适配。

因此当前工程选择：

- `compatibleSdkVersion`: `26.0.0`
- `targetSdkVersion`: `26.0.0`
- `runtimeOS`: `HarmonyOS`

这是基于本机 SDK 声明的保守且可验证选择，不把 API 26 调用部署到 API 24 设备上冒险。

## 官方示例中的具体风险

在线实现摘要曾出现 `createA2AServer(card, onData, want=want)`。本机声明的函数签名是：

```ts
createA2AServer(agentCard, onData, want?)
```

当前工程使用 `createA2AServer(this.context.agentCard, this.handleOperation, want)`，避免把赋值表达式误当参数。所有后续示例都以本机 `.d.ts`、实际编译和云设备运行三者共同作为证据。

## `iconUrl` 的本机校验边界

本机 `openharmony/toolchains/modulecheck/agentCard.json` 只要求 `iconUrl` 是长度 1–512 的字符串，没有声明 URL scheme、`common/` 到 `resources/base/media/` 的映射规则或文件存在性校验。当前 Release HAP 已包含 `resources/base/media/word_companion.svg`，且 `iconUrl: common/word_companion.svg` 能通过打包检查，但这仍不能证明系统注册/小艺展示时会正确解析该路径。

因此在云设备验证前保留现值，并把“Agent 被发现且图标可见”作为注册期验收项；不依据命名相似性猜测改成另一种路径。
