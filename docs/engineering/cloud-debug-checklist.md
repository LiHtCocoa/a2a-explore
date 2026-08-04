# 云调试单次执行检查表

完整配置方法、官方依据和自动化边界见 [云调试可执行路径](cloud-debug-execution-path.md)。这份清单用于操作者每次进入 AGC 时逐项执行，不再承担方案设计。

## Gate 0：本地候选包

```powershell
& .\apps\harmonyos\tools\cloud-preflight.ps1 -RequireCloudReady
```

- [ ] 输出 `LocalGate=PASS`。
- [ ] 输出 `SigningConfigured=True`、`SignatureVerified=True`。
- [ ] 输出 `CloudUploadReady=True`。
- [ ] 复制 HAP 路径与 SHA-256 到本次 `environment.md`。
- [ ] 如果未通过，不申请云机，先修复本地门禁。

## Gate 1：申请设备

- [ ] 进入 AGC“开发与服务 → 项目 → 质量 → 云调试”。
- [ ] 筛选 HarmonyOS 5+、API Level 26、phone/tablet。
- [ ] 记录设备型号、系统版本、API Level、优惠/付费状态。
- [ ] 点击“开始测试”并等待设备初始化。
- [ ] 网页投屏、控制面板、截屏和 HiLog 页签均可用。

## Gate 2：上传和基线

- [ ] 从“应用 → 本地上传”上传 Gate 0 的签名 Release HAP。
- [ ] 系统自动安装并自动打开 App。
- [ ] App 可直接冷启动并创建本地学习会话。
- [ ] App 有明确返回/退出路径，不会锁定共享设备。
- [ ] 返回桌面后能打开小艺并输入文本或语音。
- [ ] 如果小艺不可用、需要无法修改的系统设置或目标 A2A 版本不满足，停止并记录设备条件失败。

## Gate 3：黄金链路

每个用例开始前清空/重新筛选 HiLog，完成后立即截屏并记录 runId。

| 用例 | 话术 | 必须观察到 |
|---|---|---|
| A1 | 陪我复习今天到期的单词 | `START_REVIEW_IN_APP`、App handoff Artifact、真实应用交接 |
| A2 | resilient 和 resistant 有什么区别 | `QUICK_CONFUSION_QA`、系统侧短结果、不自动进入深练 |
| A3 | 用一个情境帮我区分 resilient 和 resistant | `PRACTICE_CONFUSION_IN_APP`、深练交接 |
| N1 | 帮我写一封邮件 | `REJECTED`，不创建伪学习会话 |

- [ ] A1 通过。
- [ ] A2 通过。
- [ ] A3 通过。
- [ ] N1 通过。
- [ ] 交接后 A2A 结束，App 学习仍继续。
- [ ] 记录 EntryAbility 收到的 Want/action/URI/parameters；没有字段也明确记录。

黄金链路通过后再执行：

- [ ] `CANCEL → CANCELED`，App session 不受影响。
- [ ] `CLEAR_CONTEXT` 日志包含 `appSessionsAffected=0`。
- [ ] 系统提醒请求不伪造计划成功。
- [ ] 系统伴随请求不伪造开启成功。

## Gate 4：日志和证据

- [ ] HiLog 等级选择 `info` 或更低。
- [ ] 先用 `EchoWordAgent` 筛选，再用 runId 筛选。
- [ ] 导出日志；注意在线 500 条、下载 15000 条上限。
- [ ] 保存关键截图；截图进入测试报告。
- [ ] 结束测试并释放设备。
- [ ] 在测试报告中核对安装记录和历史截图。

归档：

```text
artifacts/debug/YYYY-MM-DD/<run-id>/
├─ environment.md
├─ steps.md
├─ hilog.txt
├─ trace.md
└─ screenshots/
```

## Gate 5：本地自动判定

```powershell
node apps/harmonyos/tools/verify-cloud-evidence.mjs `
  artifacts/debug/YYYY-MM-DD/<run-id>/hilog.txt `
  --require-all
```

- [ ] `requiredCasesPassed=true`。
- [ ] 三个公开意图均有 route、正确 Artifact type 和 `COMPLETED`。
- [ ] `steps.md` 记录了小艺可见 UI；日志不能替代视觉证据。
- [ ] `trace.md` 明确区分“已观察”“未观察”和“平台不支持”。

只有 Gate 0–5 全部通过，才称为“云调试黄金链路跑通”。
