# A2A HiLog 采集与公开意图轨迹复原

核验日期：2026-08-02  
本机 hdc：`E:\DevEnviorment\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`，版本 `3.2.0e`

当前没有连接设备，因此本机已验证 hdc 可执行文件和版本。下面“本地设备采集”要求真实 HDC target；AGC 云调试公开文档提供的是网页控制面板中的 HDC shell 输入框和独立 HiLog 页签，没有说明会向本地暴露 connect key。

## 日志标签

| Tag | 内容 |
|---|---|
| `EchoWordAgent` | Agent 生命周期、operation、公开意图路由、TaskStatus、Artifact、认证和 IPC 错误 |
| `EchoWordEntry` | 普通应用 UIAbility 生命周期与页面加载 |

Agent 每次实例创建会生成一个 runId。核心日志格式：

```text
runId=<uuid> operation=<n> taskId=<uuid> contextId=<uuid> clientSessionId=<uuid> explicitIntent=<id> relatedCount=<n>
runId=<uuid> route taskId=<uuid> publicIntent=<intent> mode=<mode> continuation=<policy> rejected=<bool> reason=<reason>
runId=<uuid> taskId=<uuid> contextId=<uuid> previousState=<n> nextState=<n> messageId=<uuid> publicIntent=<intent> mode=<mode> continuation=<policy> durationMs=<n>
runId=<uuid> taskId=<uuid> publicIntent=<intent> mode=<mode> continuation=<policy> artifactType=<type> artifactId=<uuid> lastChunk=true durationMs=<n>
```

状态数字以本机 `TaskState` 为准：

```text
0 SUBMITTED
1 WORKING
2 INPUT_REQUIRED
3 COMPLETED
4 CANCELED
5 FAILED
6 REJECTED
7 AUTH_REQUIRED
8 UNSPECIFIED
```

## 本地设备采集

PowerShell：

```powershell
$hdc = 'E:\DevEnviorment\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc list targets -v
```

确认 connect key 后：

```powershell
$target = '<connect-key>'
& $hdc -t $target hilog |
  Select-String -Pattern 'EchoWordAgent|EchoWordEntry'
```

保存到当前调试证据目录：

```powershell
$runDir = 'artifacts\debug\2026-08-02\<run-id>'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
& $hdc -t $target hilog |
  Select-String -Pattern 'EchoWordAgent|EchoWordEntry' |
  Tee-Object -FilePath "$runDir\hilog.txt"
```

采集是持续命令；完成测试后用 Ctrl+C 停止。不要在命令中写入设备账号、证书或签名口令。

## AGC 云调试

HarmonyOS 5 及以上云设备使用 AGC 的 **HiLog** 页签：

1. 先按 `EchoWordAgent` 过滤，确认 `onCreate → onConnect`。
2. 发起一次应用交接或快速辨析，在第一条 operation 日志中复制 runId。
3. 再按该 runId 过滤，避免其他应用或旧实例日志混入。
4. 完成测试后导出原始日志，不只保存截图。
5. 将设备型号、系统版本、包 SHA-256 和操作步骤写入同一证据目录。

官方当前说明：页面可实时展示 500 条日志，下载最多 15000 条。长链路应按单个用例清空/筛选和导出，避免最后一次性抓取导致前段轨迹被截断。

控制面板也允许输入 HDC shell 命令并识别 `hilog` 等持续输出命令，但该能力由网页转发；除非实际页面另外提供连接信息，不要把它写成本地 `hdc -t <cloud-target>` 自动化能力。

如果 AGC 页签不能同时按 tag/runId 过滤，先导出全部相关 tag，再在本地使用 `Select-String -Pattern 'runId=<uuid>'` 二次筛选。

## 首轮必跑轨迹

### 应用交接

预期：

```text
onCreate
onConnect
EXECUTE
SUBMITTED → WORKING
route publicIntent=START_REVIEW_IN_APP mode=APP_HANDOFF continuation=COMPLETE_AFTER_HANDOFF
addArtifact(lastChunk=true)
WORKING → COMPLETED
onDisconnect
```

检查：Artifact 为 `learning.app-handoff.v1`，`handoffStatus=REQUESTED_NOT_OBSERVED`；记录系统是否实际拉起 App，以及完成交接后连接是否结束。`COMPLETED` 不表示 App 学习完成。

### 系统侧快速结果

预期路由字段：

```text
publicIntent=QUICK_CONFUSION_QA
mode=SYSTEM_RESULT
continuation=COMPLETE_AFTER_RESULT
```

检查：Artifact 为 `learning.quick-confusion-answer.v1`，包含可选 App continuation，但没有自动启动 App 内练习。

### 取消

预期：

```text
CANCEL
<current> → CANCELED
```

取消后不得出现完成 Artifact；同时检查 App 内已有学习 session 未被删除或改写。

### CLEAR_CONTEXT

预期出现 `clearedAdapterTasks=<n> appSessionsAffected=0`。这只证明 Adapter 内存关联被清理；App Agent 的 session 恢复应在 App 自身日志和数据源中另行验证。

### 故障

重点搜索：

```text
createA2AServer failed
updateStatus failed
addArtifact failed
sendData failed
authorize failed
unsupported_public_intent
system_capability_not_verified
system_companion_not_verified
nextState=5
```

## 证据完整性检查

一次 run 只有同时具备以下内容才算可复现：

- environment.md：IDE、SDK、设备、系统、小艺/框架版本、HAP SHA-256。
- steps.md：话术、点击、期望与实际结果。
- hilog.txt：未加工的相关日志。
- trace.md：按 runId/taskId 归纳的状态序列和结论。
- screenshots/：发现、恢复、完成等可见 UI；截图不能替代日志。

日志不应包含原始账号凭据、握手数据、完整敏感语音文本或不必要的用户答案。目前实现只记录关联 ID、状态、耗时和错误对象。
