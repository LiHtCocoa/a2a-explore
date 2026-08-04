# 工作区与推进方式

## 为什么先有 Web 原型，再建 HarmonyOS 工程

当前最大风险不是 ArkUI 页面写不出来，而是版本能力、小艺实际渲染和学习交互三者尚未对齐。Web 原型用于快速验证状态、信息密度和跨界面分工；HarmonyOS 最小工程已经根据本机 DevEco 26 与 API 26 SDK 模板、类型声明建立并通过干净 Hvigor 构建。签名、AGC 操作和自动化上限已经整理为 [云调试可执行路径](cloud-debug-execution-path.md)，不再只列等待条件。

## HarmonyOS 工程进入门槛

1. 在 DevEco Studio 中记录 IDE、SDK、构建工具版本。已完成，见 [本机 SDK 能力矩阵](sdk-capability-matrix.md)。
2. 确认 `AgentExtensionAbility`、`AgentUIExtensionAbility`、`@kit.AgentFrameworkKit` 在目标 API 下的声明和编译结果。声明与 API 26 工程编译已核验，见 [端 A2A 能力规格](a2a-capability-spec.md)；设备运行仍是独立门槛。
3. 确认目标云设备系统版本与小艺能力可用。
4. 用 AgentCard 0.4.0 注册三个公开 Skill，并分别验证应用交接、系统侧短答和深练交接。
5. 本地实现并编译一次性 `WORKING → COMPLETED`、Artifact、取消与 Adapter context 清理；App Agent 学习恢复作为独立链路验证。

## 预期目录

工程位于 `apps/harmonyos/`，业务按职责而非页面堆放：

```text
apps/harmonyos/
├─ entry/src/main/ets/
│  ├─ agent/          # AgentExtensionAbility、A2A adapter、AgentCard 读取
│  ├─ domain/         # 学习 session、word attempt、提示策略、状态机
│  ├─ data/           # 本地词库、复习队列、Agent 会话持久化
│  ├─ pages/          # ArkUI 页面组合
│  └─ components/     # 可复用学习组件
└─ entry/src/main/resources/
```

协议对象不要直接散落在页面中；`agent/` 只把 A2A 请求翻译为公开意图交付。App 内部命令、学习状态和个性化策略不通过小艺逐步驱动。

App Agent 候选持久恢复设计见 [App Agent 学习会话持久化与恢复](task-persistence.md)。现有 Preferences 实现是领域原型，正式数据源不能由 A2A Adapter 拥有。

ArkUI 与 Agent 已共享领域学习内容，但实时 task 进度尚未跨进程打通；设备证据、实现分支与完成判据见 [应用 UI 与 A2A Task 状态桥接](app-agent-state-bridge.md)。

## 每次云调试的证据包

```text
artifacts/debug/YYYY-MM-DD/<run-id>/
├─ environment.md     # IDE/SDK/设备/包版本
├─ steps.md           # 可复现步骤与实际结果
├─ hilog.txt          # 原始 HiLog 导出
├─ protocol.ndjson    # 脱敏后的协议收发和状态变化
└─ screenshots/       # 关键界面，不代替日志
```

日志至少包含 runId、taskId、contextId、operation、previousState、nextState、durationMs 和 errorCode；不要记录原始账号凭据或完整敏感语音文本。

本地 hdc 与 AGC HiLog 页签的采集步骤见 [A2A HiLog 采集与公开意图轨迹复原](hilog-runbook.md)。

当前目标自动化级别为 L2：本地构建/签名门禁与日志判定自动化，AGC 云机申请、上传和小艺系统 UI 操作按官方控制台流程人工执行。公开文档未提供这些云端步骤的 API/CLI，不能把网页内部接口当成稳定 CI 能力。
