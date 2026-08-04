# 调研基线：端侧 A2A 与学习优先的 AI 伴学

日期：2026-08-02  
用途：把“官方现在怎么说”“我们据此做什么”“哪里仍不确定”分开记录，避免产品和工程建立在印象上。

## 结论摘要

1. 端侧 A2A 是系统 Agent 与应用公开 Agent 能力之间的协作边界，不是应用内 Agent 的远程 UI，也不应承载全部学习业务。
2. 其主要产品价值包括：让小艺发现并交接到 App、在系统 UI 内完成适合的短结果、委托应用无法直接完成的系统能力，以及在确有需要时发布最小任务投影。拉起 App 后是否维持通信应按这些目的决定，而不是默认长连接。
3. AI 伴学不能以“更快给出答案”为目标。背词场景首先要保护主动提取和适度困难，再用分级提示、对比解释和情境练习帮助理解。
4. “单次抽背”适合作为首个垂直切口：任务边界明确、状态可枚举、结果可形成 Artifact，也能同时覆盖短问答与较长的陪伴任务。
5. 云调试可以解决缺少真机的问题，但它不是本地调试的完全替代：当前官方 FAQ 强调上传 Release 包、共享设备限制以及通过 HiLog 页签查看日志。

## 官方 A2A 证据

### 方舟智能开发框架的能力分层

官方将能力开放分为意图、Skill、端侧 A2A：意图偏单一明确调用，Skill 偏复杂功能，端侧 A2A 面向应用智能体与系统智能体的双向通信协商和复杂任务。

- 来源：[方舟智能开发框架概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkaf-overview)
- 产品含义：“陪我复习 10 个易错词”首先是一个应用交接意图；进入 App 后由应用内 Agent 负责教学过程。只有用户仍需要系统进度、系统计划或跨界面控制时，才继续作为长时 A2A 协作。

### 连接、通信、认证与富交互

端侧 A2A 概述描述了连接建立、双向数据通信、可选安全认证、可选 `AgentUIExtensionAbility` 富交互以及断开连接。

- 来源：[端侧 A2A 框架概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-overview)
- 产品含义：系统入口负责发现、系统 UI 和交接；应用内 Agent 负责学习任务。可选 AgentUIExtension 是应用富 UI 的一种承载方式，不等于应用能控制小艺原生系统 UI。

### AgentCard 是能力契约

`agent_config.json` 中的 AgentCard 描述 agentId、名称、说明、能力、输入输出模式、skills、示例、设备类型和最低应用版本。能力还包括 streaming、pushNotifications、stateTransitionHistory 等声明。

- 来源：[AgentExtensionAbility 配置文件说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/agent-extension-configuration)
- 产品含义：未来的 skill 不应写成笼统的“英语学习”，而应以用户可说出的任务表达，例如“抽背易错词”“解释两个近义词的区别”“继续上次复习”。

### 协议状态可以直接驱动 UX

当前 `@kit.AgentFrameworkKit` 的 A2A API 文档列出：

- `TaskState.SUBMITTED`
- `TaskState.WORKING`
- `TaskState.INPUT_REQUIRED`
- `TaskState.COMPLETED`
- `TaskState.CANCELED`
- `TaskState.FAILED`
- `TaskState.REJECTED`
- `TaskState.AUTH_REQUIRED`
- `TaskState.UNSPECIFIED`

同时提供 `Message`、`Part`、`Task`、`TaskStatus`、`Artifact`、`metadata`，以及 `updateStatus()`、`addArtifact()`、`getUserInput()`、`getRelatedTasks()` 等接口。

- 来源：[A2A（A2A 协议）API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/hmaf-a2a-protocol)
- 来源：[通过 AgentAbilityExtension 实现智能体间 A2A 协议通信](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hmaf-a2a-dev-guide)
- 产品含义：这些状态只描述当前 A2A 协作 Task。系统侧可以据此展示语义进度；应用内学习状态由 App Agent 独立建模，只有显式系统伴随场景才向 A2A 投影必要子集。

### 本机 SDK 已澄清容器与 A2A Server 的版本边界

原始 `INTRO.md` 记录目标设备为 HarmonyOS 6.1.1、API 24；当前官方搜索结果中 `AgentCard` 可见 24+ 标记，但 `@kit.AgentFrameworkKit` A2A 服务端 API 标注起始版本为 26.0.0。端 A2A 技术规范搜索摘要显示文档版本 V0.6，最后修改时间 2026-06-11。

- 来源：[端 A2A 协议技术规范](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-device-0000002624952279)
- 来源：[端 A2A 协议消息指令定义](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-device-commands-0000002594605828)
- 本机证据：DevEco Studio 26.0.0.621、HarmonyOS 26.0.0 Beta2 SDK（组件 26.0.0.32）的声明显示 `AgentExtensionAbility`、`AgentUIExtensionAbility` 与 AgentCard 从 API 24 提供；`createA2AServer`、TaskState、Artifact 与 `PERCEPTION_SUGGEST` 从 26.0.0 提供。
- 编译证据：采用 `compatibleSdkVersion` / `targetSdkVersion` 26.0.0 的最小工程已通过干净 Hvigor 构建，并在 HAP 中打包 `agent` extension 与 AgentCard metadata。
- 结论：不能把“Agent 容器存在”和“当前标准 A2A Server API 可用”视为同一件事。API 24 下若要实现完整协议，需要另一套低层实现与设备证据；当前工程不作这一未经验证的声明。

## 云调试证据

官方 FAQ 当前说明：

- 云调试为在线真机调试方案，部分优惠机型按账号每天提供 360 分钟优惠时长。
- 线上提供 HarmonyOS 5 及以上的直屏手机、折叠屏、平板和 PC。
- HarmonyOS 5 及以上设备通过 “HiLog” 页签查看日志。
- 当前上传包要求 Release，而非 Debug。
- Release 包必须配置发布证书；上传后系统自动安装，HarmonyOS HAP/APP 安装成功后自动打开。
- 网页控制面板可以输入 HDC shell 命令，但官方流程没有说明向本地开放 HDC connect key。
- HiLog 页面实时展示 500 条，下载最多 15000 条；支持关键字筛选和导出。
- 官方公开文档描述的是 AGC 控制台交互流程，本次调查未找到云机申请、应用上传、小艺输入或日志下载的公开 API/CLI。
- 预约调试最多支持两台设备。
- 共享设备对高风险权限、锁屏或无法退出的界面有限制。

- 来源：[云调试](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-0000002235870046)
- 来源：[云调试 FAQ](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-faq-0000002254916526)
- 来源：[调试应用](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-debugapp-0000002289629821)
- 来源：[使用控制面板调试](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-location-0000002289516745)
- 来源：[查看和导出日志](https://developer.huawei.com/consumer/cn/doc/app/agc-help-clouddebug-viewlog-0000002289629825)
- 工程含义：当前可落地到 L2 半自动——本地门禁和证据判定自动化，中间 AGC 申请设备、上传包和操作小艺人工执行。无人值守 E2E 需要额外的官方接口或自有设备实验室。

## 学习科学与相邻产品

### 主动提取优先于重复展示

Karpicke 与 Roediger 的经典研究强调 retrieval practice 对长期学习的重要性；间隔效应研究则支持将复习安排分散到时间上，而不是一次集中灌输。

- 来源：[The Critical Importance of Retrieval for Learning](https://www.science.org/doi/10.1126/science.1152408)
- 来源：[Spacing Effects in Learning](https://journals.sagepub.com/doi/abs/10.1111/j.1467-9280.2008.02209.x)
- 产品含义：默认先让用户回忆；AI 不应在题目出现时同步给出释义、例句和联想，提示应逐级揭示。

### AI 要保护“有益的困难”

2026 年的 AI learning companion 框架指出，生产力型 AI 倾向减少摩擦和直接给答案，而学习型 AI 应保留 productive struggle，并围绕教学、适应和责任设计，以持久理解、元认知和学习者自主性为目标。

- 来源：[Building AI Companions that Prioritise Learning over Performance](https://arxiv.org/html/2605.04816v1)
- 产品含义：伴学智能体的成功指标不是回答长度或即时完成率，而是延迟回忆、提示依赖下降、错误模式被用户理解。

### 生成式对话更适合成为练习的“第二层”

Duolingo Max 把 Roleplay、Video Call 放在课程路径和已学主题旁边，并在对话后提供 transcript 复盘，而不是用开放聊天替代全部课程结构。

- 来源：[Duolingo Max](https://blog.duolingo.com/duolingo-max/)
- 来源：[Video Call](https://blog.duolingo.com/video-call/)
- 产品含义：我们的 AI 深聊应从一次具体答题或错误进入，完成后沉淀到复习记录；开放聊天不是首页主入口。

## 对首版产品的约束

- 一题一目标：每次只评估一个可观察的记忆或辨析目标。
- 先答后助：用户明确求助前，不泄露完整答案。
- 分级提示：词形/语境方向 → 近义词对比 → 完整解释。
- 分层协作：小艺负责发现、系统 UI、交接与系统能力；App Agent 负责高密度学习和长期个性化。
- 按目的续连：应用交接后默认结束 A2A；系统侧短答、计划确认或显式伴随才维持到对应目的完成。
- 产物化结束：每次任务输出易错词、提示依赖、误区和下次复习建议。
- 可恢复：从后台或系统伴随态返回时，恢复当前词和提示层级，而不是重开一轮。
- 可解释自适应：告诉用户“为什么今天出现这个词”，避免黑盒推荐。

## 仍需验证

1. HarmonyOS 6.1.1 目标云设备实际开放的 API 等级、方舟框架版本与小艺能力；本机 SDK 和编译已解决组件声明边界，但不能替代设备运行证据。
2. 小艺侧对 streaming、pushNotifications、stateTransitionHistory 的实际渲染行为。
3. `PERCEPTION_SUGGEST` / OnApp Chips 在当前系统版本中的展示边界。
4. 小艺交接到普通应用页面的真实触发方式、Want 字段，以及 `AgentUIExtensionAbility` 与普通页面的边界。
5. Release 包云调试条件下，A2A 服务注册、发现和 HiLog 的可观测范围。
