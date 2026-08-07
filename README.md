# A2A AI 伴学探索工作区

工作区目标是建立贴近 HarmonyOS 实际边界的 AI 伴学产品：小艺作为系统 Agent 负责系统入口、系统 UI、系统能力和必要的最小协作；应用内 App Agent 负责学习业务、个性化与长期演进。

建议从以下文档开始：

- [Agent 职责模型](docs/product/agent-responsibility-model.md)
- [公开意图与 A2A 模型](docs/product/intent-and-a2a-model.md)
- [A2A / App 双状态模型](docs/product/a2a-ux-state-model.md)
- [公开 Skill 契约](docs/product/skill-contracts.md)
- [端 A2A 能力规格](docs/engineering/a2a-capability-spec.md)
- [云调试可执行路径与自动化边界](docs/engineering/cloud-debug-execution-path.md)
- [Web V0.3 原型](apps/prototype-web/README.md)

## 当前阶段

- 已重建四层职责：小艺系统 Agent、A2A Adapter、App Agent、App UI。
- Web V0.3 已覆盖应用交接、系统侧快速辨析、系统提醒待验证、显式系统伴随四类边界，并通过交互 smoke。
- HarmonyOS AgentCard 已升级到 0.4.0，声明三个公开 Skill：应用复习交接、系统侧快速辨析、应用深度练习交接。
- A2A Adapter 已改为纯公开意图适配器；交接/短结果一次性完成，`CANCEL/CLEAR_CONTEXT` 不影响 App 学习 session。
- ArkUI 已去掉伪造的“小艺伴随任务”，显示交接结束与 App Agent 本地会话的独立状态。
- `PublicIntentEngine` 与 App Agent 候选学习领域引擎分别有 smoke 覆盖；API 26 Release ArkTS 构建已通过。
- 当前 HAP 仍为 unsigned。Agent 发现、真实 App 跳转、系统 UI、提醒/计划、显式系统伴随和 HiLog 必须通过签名包与目标设备验证。
- 云调试已收敛为可执行的 L2 半自动方案：本地一键预检，AGC 控制台执行固定黄金链路，导出后自动校验 HiLog；无人值守 E2E 仍需要官方云机/小艺自动化接口或自有设备实验室。

## 目录

```text
apps/prototype-web/   Web V0.3 交互原型
apps/harmonyos/       DevEco Stage 工程与端侧 A2A Adapter
docs/product/         产品职责、意图、状态和 Skill 契约
docs/engineering/     SDK 能力、构建、云调试和日志规范
docs/research/        研究结论与待验证项
artifacts/            构建和设备调试证据
```

## 手动签名 HAP（Sign HAP workflow）

CI 默认产出 **unsigned** HAP（`a2a-explore-hap` artifact）。需要真机 / AGC 验证时，由维护者手动触发签名流水线，得到 signed HAP：

### 1. 创建 "signing" Environment
仓库 → **Settings → Environments → New environment**，名称填 `signing`。
建议在环境的 **Required reviewers** 中添加你自己 / 受信维护者，使签名 job 需人工批准后才执行。

### 2. 添加 Environment Secrets（全部添加到 "signing" 环境，禁止提交到仓库）
| Secret | 值 |
|---|---|
| `HAP_P12_BASE64` | keystore 文件 base64：`base64 -w0 app.p12` |
| `HAP_CER_BASE64` | 应用证书 base64：`base64 -w0 app.cer` |
| `HAP_P7B_BASE64` | Profile base64：`base64 -w0 app.p7b`（与具体应用绑定，含包名/证书/权限） |
| `HAP_KEY_ALIAS` | key alias |
| `HAP_KEY_PASSWORD` | key 密码 |
| `HAP_STORE_PASSWORD` | keystore 密码 |

### 3. 找到 Build run_id
Actions → 选择最近成功的 **Build HAP** 运行 → 运行编号（或地址栏 `/actions/runs/<run_id>`）。

### 4. 手动运行签名
Actions → **Sign HAP (Manual)** → **Run workflow** → 填入 `run_id` → **Run**。
流水线先校验该 run：必须属于本仓库、必须是 Build HAP 工作流、结论为 success、来源为默认分支 push（或手动触发）、artifact 未过期，任一不满足则拒绝。

### 5. 下载 signed artifact
运行结束 → **a2a-explore-signed-hap** artifact → **Download**（默认仅保留 2 天，不发布 GitHub Release）。
