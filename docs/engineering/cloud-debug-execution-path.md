# 云调试可执行路径与自动化边界

核验日期：2026-08-02  
适用工程：`apps/harmonyos` 0.4.0  
目标：在没有自有真机的条件下，完成“小艺发现公开 Agent → A2A 一次性交付 → App 交接/系统侧短结果 → HiLog 与截图归档”的首轮真实设备验证。

## 1. 调查结论

AGC 云调试可以承担首轮真实设备验证，但官方当前公开的是交互式控制台流程：

- 在 AGC 项目中申请一台云端真机。
- 上传带发布证书、以 release 模式构建的 HAP/APP。
- 系统自动安装并自动打开 HarmonyOS 应用。
- 操作者通过网页投屏鼠标控制设备，也可以在控制面板输入 HDC shell 命令。
- HiLog 页签支持按等级和关键字获取日志，页面实时展示 500 条、下载最多 15000 条。
- 支持截屏、日志导出和测试报告回看。

本次查阅的官方“云调试、单机调试、控制面板、日志、FAQ”文档没有公开云机申请、应用上传、远程点击、小艺输入或日志下载的服务端 API/CLI。因此，当前可行目标不是无人值守全自动，而是：

```text
一键本地预检/构建/签名核验
  → 人工申请云机并执行小艺黄金链路
  → 导出 HiLog/截图/报告
  → 一键本地解析和判定证据
```

如果未来拿到华为公开/白名单自动化接口，或改用自有设备实验室，再把中间的人工段替换为设备编排和系统 UI 自动化。

## 2. 配置完成后的能力等级

| 等级 | 条件 | 能做到什么 | 不能证明什么 |
|---|---|---|---|
| L0 当前 | unsigned Release HAP、本地 SDK | smoke、ArkTS 编译、AgentCard/Artifact 静态契约 | 安装、Agent 发现、小艺系统 UI |
| L1 云机可运行 | 开发者账号、AGC 项目、额度、发布证书/profile、签名 HAP | 上传后自动安装/打开；人工操作小艺；HiLog、截屏、报告 | 无人值守重复执行 |
| L2 半自动回归 | L1 + 本地预检脚本 + 固定话术矩阵 + 日志分析脚本 | 一条命令生成候选包，人工执行约 10–20 分钟，导出后自动判定轨迹 | 自动申请云机、自动说话/点击小艺 |
| L3 无人值守 E2E | 官方云机 API/CLI 或自有设备编排，并具备系统级小艺输入能力 | 定时/CI 自动跑完整系统链路 | 当前公开云调试文档未提供这些条件 |

本项目当前处于 L0，完成第 3 节的一次性配置后进入 L1；完成第 4、5 节和配套脚本后进入 L2。

## 3. 一次性配置

### 3.1 开发者账号与 AGC 项目

1. 注册并完成华为开发者账号所需认证。
2. 登录 AppGallery Connect，创建或选择测试项目。
3. 在“开发与服务 → 项目 → 质量 → 云调试”确认服务可访问。
4. 确认账号优惠时长、套餐余额或按量付费状态。

官方规则：账号每天有 360 分钟优惠时长，优惠机型单次首先分配 20 分钟，可按页面提示延长；单机调试每次申请一台设备，同一账号最多同时占用两台。13:00–23:00 是高峰，首次验证优先安排在 08:00–12:00。

完成判据：能进入云调试机型选择页，并能看到可用额度和空闲设备。

### 3.2 配置发布签名

云调试只接受配置发布证书、以 `release` 模式构建的 HAP/APP；不接受 debug 或 In-house 包。当前工程的 `signingConfigs` 为空，所以现有 `entry-default-unsigned.hap` 不能上传作为有效候选包。

需要准备：

- 发布 keystore 及 key alias。
- 发布证书。
- 与 `com.example.echowordcompanion` 匹配的发布 Provision Profile。
- keystore/key 密码的安全保存方式。

推荐首次在 DevEco Studio 的 `File → Project Structure → Project → Signing Configs` 中配置 release 签名，确认 IDE 能生成签名包后，再将非秘密路径配置固化到工程；密码不得写入仓库，应通过本地安全配置或 CI secret 注入。

Hvigor 构建后使用本机 SDK 的 `hap-sign-tool.jar verify-app` 校验签名。配套 `cloud-preflight.ps1` 会在存在 signing config 时执行该校验。

完成判据：

- `clean assembleHap` 不再出现 `Will skip sign 'hos_hap'`。
- 产物通过 `verify-app`。
- 包内版本、bundleName、AgentCard 版本和三个公开 Skill 仍然匹配。

### 3.3 选择目标设备

在云调试筛选条件中选择：

- HarmonyOS 5 及以上真机。
- API Level 26 或能够运行当前 `compatibleSdkVersion: 26.0.0` 的系统。
- 手机或平板，与 AgentCard `deviceTypes` 一致。
- 优先选择空闲优惠机型。

申请后记录设备型号、系统版本、API Level、小艺/方舟智能框架可见版本。云调试允许按 API Level、系统版本和设备形态筛选，但“设备是 HarmonyOS 5+”不能自动证明它包含目标 A2A/小艺版本。

完成判据：设备初始化成功，网页投屏可操作，控制面板和 HiLog 页签可见。

### 3.4 准备测试矩阵与退出路径

应用必须能够正常退出或返回桌面，避免触发共享设备的安全限制。准备固定话术：

| 编号 | 话术 | 预期公开意图/结果 |
|---|---|---|
| A1 | 陪我复习今天到期的单词 | `START_REVIEW_IN_APP`，应用交接 |
| A2 | resilient 和 resistant 有什么区别 | `QUICK_CONFUSION_QA`，系统侧短结果 |
| A3 | 用一个情境帮我区分 resilient 和 resistant | `PRACTICE_CONFUSION_IN_APP`，深练交接 |
| N1 | 帮我写一封邮件 | `REJECTED` |
| N2 | 每天晚上提醒我复习 | 系统能力未验证，不伪造成功 |
| N3 | 退出应用后继续在小艺显示进度 | 系统伴随未验证，不伪造成功 |

首轮不追求覆盖所有异常；先跑 A1、A2、A3 和 N1，确认黄金链路后再跑 N2/N3/CANCEL/CLEAR_CONTEXT。

## 4. 每次云调试的标准操作

### 第一步：本地候选包门禁

在仓库根目录执行：

```powershell
& .\apps\harmonyos\tools\cloud-preflight.ps1 -RequireCloudReady
```

脚本完成 smoke、Web 回归、Release 干净构建、AgentCard/版本检查、SHA-256 和签名验证。只有输出 `CLOUD_UPLOAD_READY=True` 才进入 AGC。

### 第二步：申请设备

1. AGC“开发与服务 → 项目 → 质量 → 云调试”。
2. 按系统版本、API Level 和设备形态筛选。
3. 对空闲设备点击“开始测试”，确认额度。
4. 等待系统初始化。

### 第三步：上传并安装

1. 在“单机调试 → 应用 → 本地上传”选择 preflight 输出的签名 HAP。
2. 记录上传文件 SHA-256。
3. 云调试自动安装，并在安装成功后自动打开应用。
4. 先确认 App 可直接冷启动并创建本地学习会话，作为 App Agent 独立性基线。

AGC 会对包名、版本和 SHA-256 做重复校验；三者完全相同的包不能重复上传，相同包名/版本但 SHA 不同可以上传。自动化构建应保留 SHA，不要仅靠文件名区分候选包。

### 第四步：确认小艺可用性

1. 返回桌面并打开小艺。
2. 确认可以通过文本或语音输入固定话术。
3. 如果小艺要求登录，使用云调试“获取控件树”处理隐私黑屏。
4. 如果必须修改被云调试禁止的高危系统设置，或目标小艺能力根本不可用，立即记录为设备条件不满足，不要用原始 A2A 报文注入替代系统验证。

这一关是云调试能否承担 A2A 验证的真正门槛。通过协议注入只能测试 Adapter，不能证明小艺发现、意图匹配和系统 UI。

### 第五步：执行黄金链路

按 A1 → A2 → A3 → N1 顺序执行，每个用例：

1. 清空或重新筛选 HiLog。
2. 输入话术。
3. 记录小艺可见结果和是否出现应用入口。
4. 如发生交接，记录 App 是否被拉起、前后台行为和 EntryAbility 日志。
5. 截取关键系统 UI 与 App UI。
6. 记下 `runId`、`taskId` 和实际结果。

不要一次连续输入全部话术后再区分日志；单个用例的 2–3 分钟证据更容易复原。

### 第六步：获取日志和报告

1. 在 HiLog 页签选择 `info` 或更低等级。
2. 先按 `EchoWordAgent` 获取，再按具体 `runId` 获取。
3. 导出日志；页面实时展示上限为 500 条，下载上限为 15000 条。
4. 使用“截屏”保存关键画面；截屏会进入测试报告。
5. 结束测试并释放设备，在“测试报告 → 单机调试”查看安装记录和历史截图。

控制面板支持输入 HDC shell 命令，但这是网页内的命令输入能力；当前官方文档没有说明会向本地暴露可供脚本连接的 HDC connect key。

### 第七步：本地证据判定

把导出的日志放入：

```text
artifacts/debug/YYYY-MM-DD/<run-id>/hilog.txt
```

执行：

```powershell
node apps/harmonyos/tools/verify-cloud-evidence.mjs `
  artifacts/debug/YYYY-MM-DD/<run-id>/hilog.txt
```

脚本检查三个公开意图的 mode、continuation、Artifact 和完成状态，并输出缺失项。截图、实际 Want 和小艺 UI 仍需人工写入 `steps.md` / `trace.md`，因为日志无法证明用户真正看到了什么。

## 5. 首轮通过标准

以下条件全部满足，才算云调试路径“跑通”：

- 签名 Release HAP 上传、安装、自动打开成功。
- AgentCard 被小艺发现，至少 A1/A2/A3 能稳定命中对应公开意图。
- A1/A3 发生真实应用交接，记录到 EntryAbility 的 Want/action/URI/parameters；没有字段时也要形成明确证据。
- A2 在系统侧返回短结果，不自动启动 App 深练。
- 交接后 A2A Task 完成/断连，App 学习仍能独立继续。
- N1 进入 `REJECTED`，N2/N3 不伪造系统能力成功。
- HiLog、截图、测试报告、设备环境和 HAP SHA-256 已归档。

如果仅完成上传安装和 App UI 操作，只能说明云机兼容，不能说明 A2A 跑通。

## 6. 自动化继续演进的决策

完成一次人工黄金链路后，按实际平台能力选择：

### 路径 A：AGC 提供正式自动化接口

若华为提供或为项目开通设备申请、应用上传、远程输入、日志下载接口，则将人工步骤封装为 CI job，并使用服务账号/短期 token；不得抓取网页内部私有接口作为生产自动化方案。

### 路径 B：云调试保持控制台交互

保留 L2 半自动：CI 生成签名候选包和 preflight 报告，操作者运行固定 10–20 分钟矩阵，随后脚本自动解析日志。这是当前基于公开文档最可行的方案。

### 路径 C：需要无人值守且 AGC 无接口

采购或借用支持目标小艺/A2A 版本的自有设备，建立 HDC 设备池；应用 UI 可用测试框架驱动，但小艺系统 UI/语音输入仍需要系统级测试能力或华为提供的专用测试入口。直接调用 A2A Adapter 只能作为协议回归，不等价于端到端测试。

## 7. 官方依据

- [云调试](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-0000002235870046)
- [业务介绍](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-introduction-0000002254916514)
- [申请调试设备](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-applyequip-0000002254916518)
- [调试应用](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-debugapp-0000002289629821)
- [使用控制面板调试](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-location-0000002289516745)
- [查看和导出日志](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-viewlog-0000002289629825)
- [使用限制](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-restriction-0000002289516741)
- [云调试 FAQ](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-faq-0000002254916526)
