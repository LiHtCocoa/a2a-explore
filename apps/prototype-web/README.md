# 回声词伴 Web UX 原型 V0.3

这个无构建依赖的原型用于验证小艺系统 Agent、A2A Adapter、应用内 Agent 与 App UI 的职责边界。系统侧是语义线框，不是应用可以控制的小艺真实卡片样式。

## 核心修正

- 小艺负责系统意图、系统 UI、应用交接与系统能力代理。
- A2A Adapter 只公开需要系统协作的产品意图，不承载全部教学逻辑。
- App Agent 独立负责词表选择、提示、解释、迁移题、复盘和个性化。
- 打开 App 与继续 A2A 是两个决策；默认交接完成后结束通信。
- 只有系统侧短答、系统计划确认或用户显式开启伴随时才保持相应协作。

## 四个场景

1. **打开应用复习**：小艺识别 `START_REVIEW_IN_APP` 并完成交接；App Agent 随后独立运行，逐词学习不会同步到小艺。
2. **系统内快速辨析**：`QUICK_CONFUSION_QA` 在系统侧返回最小解释；只有用户选择“去应用练习”才进入 App 的迁移题。
3. **委托系统提醒**：展示 `SCHEDULE_REVIEW_WITH_SYSTEM` 的确认/授权边界，不伪造未验证的系统计划成功或计划 ID。
4. **显式系统伴随**：用户明确要求后才建立最小进度投影；关闭 A2A 不会终止 App 学习 session。

应用内仍验证学习不变量：两级提示后再次回忆、答案后置、一次作答一条证据、深度辨析先判断后解释。

## 本地运行

```powershell
Set-Location apps/prototype-web
python -m http.server 8890 --bind 127.0.0.1
```

打开 `http://127.0.0.1:8890/`。

## 自动检查

```powershell
node --check app.js
node interaction-smoke.mjs
```

`interaction-smoke.mjs` 直接执行真实事件监听器，并验证：

- 应用交接前 App 不假装已收到意图；交接后 A2A 默认关闭。
- App 学习开始后不会暗中重新打开 A2A。
- 快速辨析先在系统侧给最小结果，深度练习需要单独交接。
- 系统提醒场景停在平台待验证边界，不伪造成功。
- 显式伴随只同步最小进度，停止伴随后 App session 仍继续。
- 两级提示都不会提前泄露答案。

## 仍需设备验证

- 小艺交接应用的真实触发方式与 EntryAbility Want 字段。
- 系统侧短结果、CTA、Chips 与 TaskState 的真实渲染。
- 计划/提醒能力的实际协议、授权和回执。
- 显式伴随应使用一个长 Task 还是多个短协作 Task。
- 桌面、窄屏和 HarmonyOS 字体下的截图级视觉表现。
