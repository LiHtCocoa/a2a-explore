# HarmonyOS A2A 最小工程

这是基于 DevEco Studio 26.0.0.621 与 HarmonyOS 26.0.0 Beta2 SDK 的真实 Stage 工程，用于验证“小艺系统 Agent ↔ A2A Adapter ↔ App Agent”边界。

## 当前实现

- `WordReviewAgentAbility` 只处理公开意图，不再直接驱动三词学习或持有 App 学习快照。
- AgentCard 0.4.0 声明三个 Skill：
  - `start_word_review_in_app`
  - `quick_word_confusion_qa`
  - `practice_word_confusion_in_app`
- `PublicIntentRouter` 支持 `intentId` / `intent_id` / `skillId` / `skill_id` metadata 优先、文本回退。
- `PublicIntentEngine` 产生两类一次性 Artifact：
  - `learning.app-handoff.v1`
  - `learning.quick-confusion-answer.v1`
- App 交接使用 `REQUESTED_NOT_OBSERVED`，不调用或虚构 `startAbility()`。
- A2A `CANCEL` 与 `CLEAR_CONTEXT` 只影响系统协作关联，不删除 App 学习 session。
- ArkUI 显示“公开意图交接已结束”和“App Agent 本地会话”两个独立状态；系统提醒/系统伴随明确标为待设备验证。
- `ReviewTaskEngine`、`ReviewSessionStore` 和共享学习内容继续作为 App Agent 候选领域能力，不是小艺侧流程。

## 本机验证

```powershell
node tools/public-intent-smoke.mjs
node tools/review-engine-smoke.mjs

$env:DEVECO_SDK_HOME = 'E:\DevEnviorment\DevEco Studio\sdk'
$env:NODE_HOME = 'E:\DevEnviorment\DevEco Studio\tools\node'
$env:JAVA_HOME = 'E:\DevEnviorment\DevEco Studio\jbr'
$env:Path = 'E:\DevEnviorment\DevEco Studio\jbr\bin;E:\DevEnviorment\DevEco Studio\tools\node;' + $env:Path
& 'E:\DevEnviorment\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p buildMode=release clean assembleHap
```

输出：`entry/build/default/outputs/default/entry-default-unsigned.hap`。

云调试候选包门禁：

```powershell
& .\tools\cloud-preflight.ps1 -RequireCloudReady
```

当前签名配置为空，因此该命令会在本地回归通过后以 `CLOUD_UPLOAD_READY=False` 结束。配置发布签名后，它还会调用 SDK `verify-app` 校验签名。完整操作见 [云调试可执行路径](../../docs/engineering/cloud-debug-execution-path.md)。

最低兼容版本暂设为 API 26，因为标准 A2A Server API 从 26.0.0 提供。未配置账号相关 `signingConfigs`，跳过签名是预期结果，不能作为云设备可安装证据。

## 待设备验证

- 小艺如何依据公开 Skill 触发普通应用交接，以及真实 Want/action/URI/parameters。
- 交接完成后连接是否按预期结束，App 学习是否完全独立继续。
- 快速辨析 Artifact 的系统 UI 展示与 appContinuation 行为。
- metadata 中真实稳定的公开意图字段名。
- `CANCEL`、`CLEAR_CONTEXT`、`REJECTED` 与 `FAILED` 的系统侧展示。
- 系统提醒/计划和显式系统伴随能力；验证前不声明对应 Skill。
- `iconUrl`、Agent 发现、Release 签名、安装、认证和 HiLog 证据链。
