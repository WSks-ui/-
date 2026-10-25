# AI 观察导览与 AI 辅助手账

最近更新：2026-10-21（C08 定向验收完成）；首发记录日期：2026-10-18。目标工程：HarmonyOS 7 / API 26，ArkTS / ArkUI 原生应用。

本文记录当前代码中已经接入的 AI 观察路径、真实模型配置、请求契约、数据格式和验证边界。2026-10-18 首发设备截图见[AI 观察图集](design/ai-observation/README.md)，固定小样见[模型评估记录](test-results/2026-10-18-ai-observation-evaluation.md)，当轮原始结果与构建哈希见[测试报告第 25 节](TEST_REPORT.md#25-ai-观察导览与-ai-辅助手账2026-10-18)。各历史结果只适用于其原包，当前 C08 状态以下节为准。

## 2026-10-21 C08：双对象保存与同账号重访（定向验收完成）

当前目录为 22 条，在线 AI 白名单仍为杜岭二号方鼎与大河村彩陶双连壶两件；其余 20 条保留离线阅读、手动观察和手写手账。C08 沿用既有 note 格式、冻结依据、真实相机和删除墓碑，没有新增归档字段或迁移正式档案。

- **对象与事实校验**：请求、回答、定位、依据和草稿均按当前 `siteId` 的资料范围校验。`focus_hotspot` 可以不附事实；附带 `factIds` 时必须全部属于当前对象且不重复，合法的双连壶 `opening` 热点也不能夹带 `duling-*` 依据。客户端与服务端共用领域规则。
- **采纳与保存**：用户采纳草稿后，先由原生视口回传此刻真实相机与原画幅，再打开编辑器。编辑器的“参考依据”显示冻结事实的中文标题，不向用户展示内部事实 ID；确认保存才写入 `aiAssist`、正文与视角。
- **记忆重访**：全文页显示保存时冻结的问题、事实正文与来源编号对应的说明；“重温当时视角”走正式原生回放。新保存的双连壶使用 `relic_inspector / dahecun_pottery / sceneRevision 2`，热点与相机随同一条 note 经 HTTPS 到达另一端。
- **主动再问**：“带着这页手账问 AI”只预填本篇问题与观察，正文超过 300 字会提示仅带入前 300 字，原文保持完整；恢复该篇已保存的 revision 2 器物视角后，仍需用户点击“提问”才请求模型。再问不改写原 note；再次采纳草稿并保存会新建一页手账。

当前主包 M2 已完成双连壶真实单端主线、A 保存 / B 空库接收与回放、B 主动再问及方鼎定向回归。各阶段分别绑定 T5—T8，未写成一次同测试包全套通过。完整包表、初次失败与修正见[测试报告第 32 节](TEST_REPORT.md#32-双对象-ai-与同账号记忆重访2026-10-21)，实际原图见[双对象记忆图集](design/ai-dual-memory/README.md)，结构化索引见[本轮清单](test-results/2026-10-21-ai-dual-memory.json)。

| 检查 | 当前结果 |
|---|---|
| 客户端 / 服务端 AI 契约联合 | **26/26**，含双连壶事实隔离与草稿冻结；与下列本地 / 服务总数存在重叠，不累加 |
| `tools/test.ps1` | **122/122**；包含工具侧 AI 契约 |
| 设备报告解析 | **9/9** |
| 账号与 AI 服务契约 | **15/15**；包含服务侧 AI 契约，替身检查不作为真实供应商调用证据 |

| 设备路径 | 主包 / 测试包 | 结果 / 耗时 | 原始报告 |
|---|---|---|---|
| 双连壶真实提问、定位、依据、个人观察、草稿、确认保存、冻结事实与再问预填 | M2 / T5 | **1/1**，221626ms | [021508](test-results/2026-10-21-021508-363b57cb-device.log) |
| A 新账号经真实编辑器保存、磁盘回读与服务端版本确认 | M2 / T6 | **1/1**，170508ms | [022049-A](test-results/2026-10-21-022049-faba9975-device.log) |
| 方鼎真实问答、四个折角聚焦、草稿、保存与冻结依据重访 | M2 / T6 | **1/1**，191320ms | [022049-方鼎](test-results/2026-10-21-022049-c2ad4fa3-device.log) |
| B 从独立空库接收同一条 note、冻结依据与原生回放 | M2 / T7 | **1/1**，91583ms | [022456](test-results/2026-10-21-022456-cde2c928-device.log) |
| B 恢复原工作区、不自动发送、显式再问与原 note 不变 | M2 / T8 | **1/1**，68354ms | [022939](test-results/2026-10-21-022939-cf4f6a60-device.log) |

上述通过报告的 Failure / Error / Ignore 均为 0。T6—T8 保持同一主包 M2；B 接收和再问复跑沿用 A 成功保存时的同一测试工作区、账号与原 note，未注入或替换记录。最终独立测试库清理 A / B 各 **1/1**，原始报告为 [023138-A](test-results/2026-10-21-023138-a481aa5e-device.log) 与 [023137-B](test-results/2026-10-21-023137-8a73ac97-device.log)。初次失败保留在第 32 节，不改写为通过。

| 验收包 | 字节 | SHA-256 |
|---|---:|---|
| 主包 M2 | 6,526,994 | `2D1815955405B3CA354B83871B9E0A7598996FD892C47A6FE7C67EC2695BB7FE` |
| 当前测试包 T8 | 6,563,300 | `075BFB3D4CCC07804D9B164E5FE9E3C3CD55A23336B120CF5DD3BCE86BBB1198` |

真实记录由 HiLog 分片完整还原后，`tools/compare-ai-memory.mjs` 实际深比较 **13 个顶层字段及全部嵌套内容**：A 保存与 B 接收一致，B 显式再问后原 note 仍完全一致，结果为 [PASS](test-results/2026-10-21-ai-memory-compare.json)。比较覆盖冻结事实与来源、相机 / 原画幅、正文、标签、装饰、摘录、记录身份和更新时间。A 聚焦与 B 正式回放的原生 Canvas 为 **1032×1050，共 1,083,600 像素，4 像素不同、最大通道差 1**；比较按原始 layout 的真实 Canvas bounds 裁切，未缩放或屏蔽像素，见[画布比较](test-results/2026-10-21-ai-dual-canvas-compare.json)。这是画布核对，不称为零差异或整屏一致。

真实供应商事件数在 B 接收前为 **11**、接收及预填后仍为 **11**；用户显式提问后为 **12**，只新增一次 **1616ms** 请求。总计 12 次包含失败阶段，最终成功主线为 7 次真实调用，不把重跑累计为更多能力；也不以仅有预填页面证明“未自动发送”。

本轮使用两台 HarmonyOS 7 / API 26 手机模拟器：A=`YunhejiSyncB` / `127.0.0.1:5555`，B=`Pura 90 Pro` / `127.0.0.1:5557`。同账号交换走开发机自建 HTTPS 服务与 HDC 反向端口；已有可选受信任公网 HTTPS 服务配置，尚无云部署。鸿蒙分布式 KV 已接入本机不可变版本库与真实设备状态查询，但可信组网和平台跨端传输、华为账号均未完成，不能把本轮 HTTPS 结果称为原生分布式传输。实现边界见[账号离线恢复与原生通道基础](ACCOUNT_RESUME_AND_NATIVE_SYNC.md)，当前操作顺序见[演示说明](DEMO.md)。真人三分钟计时与录像未完成，自动化耗时不作为真人达标依据。

**历史补充（2026-10-18）：页面层级与单篇手账重访已接入。** 档案 / 记忆 / 我的均有对应入口；从手账可预填本篇问题与个人观察，点击提问后才请求模型，服务端明确将观察作为个人表达。支持 AI 手账筛选和保存时依据，修复聚焦后的模型可见性与延迟焦点异常。最终包单端真实 AI 专项 1/1（与页面层级同组 2/2），AI 服务 10/10；见[测试报告第 27 节](TEST_REPORT.md#27-页面功能层级与-ai-重访2026-10-18)和[新图集](design/page-hierarchy/README.md)。当轮 AI 双端仍为第 25 节手工历史结果，当时尚未完成 AI 双端 Hypium 验收；2026-10-21 当前包状态见顶部 C08 节。

## 2026-10-19 第二对象：大河村彩陶双连壶（历史阶段记录）

该阶段起始状态为“代码完成，待真实模型与设备复验”；下列结果按当轮后续进展保留，不替代顶部 2026-10-21 当前包的双连壶保存与跨端重访结果。

在线 AI 从单件方鼎扩展为显式白名单，当前为 `zz-duling-fangding` 与 `zz-dahecun`。庙底沟虽有已核事实与 revision 2 热点，但未加入白名单，入口与服务端都会拒绝，不冒充可问。

- **内容与热点**：双连壶使用 `dahecun-object / dahecun-opening / dahecun-lines` 三条事实，热点为 `mouth / opening / paint`，场景修订 `2`；热点定义拆到独立模块 `domain/DahecunObservation.ts`，与方鼎、庙底沟保持同一结构。
- **对象化文案**：`MaterialStudy` 增加 `objectName` 与 `starters`，面板的起始问题、输入提示和收起态说明改为按对象读取，不再复用方鼎的“八组”问法。
- **统一入口判断**：详情面板、档案“可 AI 观察”筛选、手账“带着这页问 AI”和我的统计入口统一使用 `isAiObservationSite`，避免界面能开、服务端拒绝。
- **服务端作用域**：按白名单预组装，缺少事实或 revision 2 场景的对象从清单缺席；提示词由对象名、引导问题、事实、来源和热点动态生成。
- **验证**：本地 **105/105**、账号与 AI 服务 **12/12**、主包与测试包构建成功；`PageHierarchyTest#library_filters_memory_tabs_and_profile_navigation` 复跑 **1/1**（108.9s，Failure / Error / Ignore 0），覆盖“可 AI 观察”筛选从 1 处变为 2 处与方鼎面板入口。首跑在“我的”页 `profile-scroll` 出现一次 UI 定位错误（Error=1），复跑通过，原始日志分别为 `2026-10-19-220339-device.log` 与 `2026-10-19-220541-device.log`。新增 `PageHierarchyTest#twin_vessel_ai_entry_uses_its_own_starters` **1/1**（58.7s），核对双连壶三个起始问题与热点归属；`PageHierarchyTest#real_ai_focus_save_and_resume_from_memory` **1/1**（165.3s）覆盖登录、真实模型、聚焦、草稿、保存与记忆重访。新用例首跑因直接等待 `ai-observation-panel` 可见失败（面板在详情首屏下方），改为先确认详情再由 click 滚动定位后通过，未删减断言。双连壶的保存与跨端重访仍未跑。
- **真实模型（余额恢复后）**：双连壶三条观察问法 + 一条手账草稿 **4/4**，方鼎回归 **1/1**，合计 **5/5** 通过应用契约与人工核对，耗时 1670—2024 ms；引用事实、热点动作与草稿边界均正确。原始记录见[双对象小样](test-results/2026-10-19-ai-dual-object-evaluation.md)。首次尝试曾因 `402 Insufficient Balance` 中断，充值后重采，不把中断写成通过。
- **错误码**：新增 `AI_PROVIDER_AUTH`（401，凭证无效或过期）与 `AI_PROVIDER_QUOTA`（402，账户余额不足）；页面显示对应中文原因，不再一律显示“服务暂时不可用”。服务端仍不读取或记录供应商错误正文。

## 2026-10-19 AI 界面统一改版（历史阶段记录）

该阶段起始状态为“代码完成，设备复验待模拟器恢复”；下列检查与设备结果按当轮包保留。

所有 AI 窗口按同一语义与尺寸重做：青色代表 AI / 资料 / 依据，玫瑰只用于用户确认的主操作；面板标题栏整行可点，回答后紧跟追问输入，草稿作为第二步；依据只保留一个开关，聚焦动作改为可换行的 chip；等待、错误、游客和草稿四态补齐骨架、退路与可读层级。首页与档案页改为双对象入口，记忆与我的页统一命名和标签色。

检查范围、19 条问题清单、设计令牌与实现落点见[AI 界面检查与统一改版](design/ai-ux-refresh/README.md)。设备复核已完成 `PageHierarchyTest` **4/4**（371.0 s，Failure / Error / Ignore 0），覆盖档案筛选、记忆全文、方鼎真实 AI 与双连壶入口；7 张截图见[设备复核截图](test-results/2026-10-20-ai-ui/README.md)。1.5 倍字体 / 深色专项仍受 `ArchiveAppearanceTest` 旧导航假设阻塞，未取得 AI 面板截图。

## 1. 当前交付范围

当前白名单为杜岭二号方鼎 `zz-duling-fangding`（首发样板）与大河村彩陶双连壶 `zz-dahecun`；两者场景修订均为 `2`，方鼎热点为 `centers / corners / frame`，双连壶为 `mouth / opening / paint`。资料事实继续读取 [MaterialStudyCatalog.ts](../entry/src/main/ets/data/MaterialStudyCatalog.ts)，没有另写一份可以漂移的正文。

已实现：

- 方鼎与双连壶详情内可收起的原生“AI 观察导览”面板，支持自由输入、三个对象化起始问题、等待、停止等待、重试、回答、聚焦操作和原地依据。
- 首页“本期观察 · AI”卡可切换方鼎与双连壶，再点“陪我观察”打开对应对象并把 AI 面板带入视野；原“泥火成器”下一节点、最近记忆、普通手账和路线点亮规则保留。
- 用户写一句自己的观察后请求 AI 草稿；草稿进入现有手账编辑器，用户确认或修改后保存。
- 保存时写入可选的 `aiAssist` 元信息，冻结采纳时的资料事实和资料修订号；B 端同账号通过 HTTPS 收到同一条 note 后，按实际记录显示 AI 参考信息、首页预览并支持正式回放。当前包 C08 的双端接收、冻结依据、回放及主动再问已定向验收，历史方鼎手工结果另见第 7 节。
- 服务端 `POST /ai/observe`，沿用现有账号服务认证；模型密钥只在本机被忽略的配置或服务端环境变量中。

未实现或未验收：

- 当前覆盖方鼎与双连壶两件；22 条目录中的其余 20 条（含庙底沟）仍只提供离线阅读、手动观察和手写手账。
- 不做流式文字、数字人、语音、拍照识物、AI 生图、通用百科问答、向量检索、多 Agent 编排或模型微调。
- 已有可选受信任公网 HTTPS 服务配置，当前演示仍使用本机自建服务，尚无云部署。华为账号与跨全设备矩阵验收未完成。
- 鸿蒙分布式 KV 已接入本机不可变版本库，可信设备列表与权限按平台实际结果显示；尚无可信组网和原生平台跨端传输验收，不宣称 HTTPS 数据交换由分布式 KV 完成。
- 没有真人三分钟计时，也没有录像；本轮仅完成上述单端与 AI 双端定向路径，未将历史全部 UI 或完整双端账号套件重跑并计为当前通过。

## 2. 模型与接口核验

| 项目 | 本机实际值 |
|---|---|
| 供应商 | DeepSeek 官方 API |
| Base URL | `https://api.deepseek.com` |
| 模型 ID | `deepseek-flash`（文档标注由 DeepSeek-V4.1-Flash-1017 提供服务） |
| 调用模式 | OpenAI 兼容 `POST /chat/completions`；强制函数调用 `submit_observation`；`thinking: {type: "disabled"}` |
| 结构化方式 | `tools` + `tool_choice`，模型返回 `tool_calls[0].function.arguments` |
| 超时 | 服务端模型调用 20 秒；客户端 AI 读超时 25 秒，账号同步仍为 10 秒 |
| 输出长度 | 回答约 80—180 汉字；`max_tokens` 1200 |
| 账号限制 | 只允许已认证账号；每账号每分钟最多 20 次 AI 请求 |

核验日期：2026-10-18。参考的官方页面：

- [Your First API Call](https://api-docs.deepseek.com/)：Base URL、模型名、OpenAI 兼容调用方式。
- [JSON Output](https://api-docs.deepseek.com/guides/json_mode)：`response_format`、JSON 关键字和空内容提示。
- [Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode)：`thinking` 开关和思考模式限制。
- [Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing)：`deepseek-flash` 的 JSON Output 支持与上下文/价格。
- [Error Codes](https://api-docs.deepseek.com/quick_start/error_codes)：400/401/402/422/429/500/503 的含义。

### 为什么用强制函数调用而不是 JSON 文本模式

最初按 JSON 文本模式实现：`response_format: {type: "json_object"}`。单轮问题通常可用，但在带多轮上下文的追问中，DeepSeek 多次只返回空白内容（实测同一问法连续 6 次均为空白；关闭 `thinking` 字段后仍有 2/4 空白）。这是供应商文档已提示的偶发空内容问题，不能靠客户端“重试一次”掩盖成稳定成功。

改为强制函数调用后，同一组多轮追问连续 4/4、固定小样 9/9 都返回了可校验的结构化参数，单次约 1.9—2.4 秒。应用仍对参数做完整领域校验，函数调用只解决“如何稳定拿到结构”，不把模型输出当成可信事实。

## 3. 请求与响应契约

应用自己的接口不是某家模型 API 的原样请求。核心类型和校验在 [AiObservation.ts](../entry/src/main/ets/domain/AiObservation.ts)，客户端资料入口在 [AiObservationKnowledge.ts](../entry/src/main/ets/domain/AiObservationKnowledge.ts)，服务端在 [ai-observation.mjs](../server/ai-observation.mjs)。

请求字段：

| 字段 | 约束 |
|---|---|
| `version` | 固定 `1` |
| `requestId` | 8—64 位字母、数字、下划线或连字符；用于区分并发和迟到回复 |
| `siteId` | 仅接受白名单 `zz-duling-fangding` 或 `zz-dahecun` |
| `sceneRevision` | 必须为 `2` |
| `hotspotId` | 空或当前对象热点；方鼎为 `centers / corners / frame`，双连壶为 `mouth / opening / paint` |
| `purpose` | `observe` 或 `draft_memory` |
| `question` | 1—200 字 |
| `turns` | 最多 6 条，每条角色为 `user / assistant`，内容 1—600 字 |
| `userObservation` | 最多 300 字；草稿请求为空时服务端先请用户留下观察，不调用模型 |

响应字段：

| 字段 | 约束 |
|---|---|
| `version / requestId / siteId` | 由服务端回填并校验，不接受模型猜测 |
| `contentRevision` | 当前资料修订 `1` |
| `status` | `grounded / needs_clarification / insufficient_evidence` |
| `answer` | 1—800 字；提示词要求 80—180 汉字 |
| `factIds` | 0—3 个合法事实 ID；`grounded` 至少一个 |
| `actions` | 最多 4 个；只允许 `focus_hotspot` 和 `show_evidence` |
| `draft` | 只在 `draft_memory` 返回；正文 1—600 字、标签 0—3 个、引用事实合法 |

动作执行规则：

- `focus_hotspot`：客户端再次核对当前对象、场景修订、热点白名单及动作所附事实；`factIds` 允许为空，非空时须属于当前对象且不重复。随后通过带请求序号的原生聚焦请求让视口执行；同一热点连续请求也会再次聚焦。模型不能生成相机、几何或脚本。
- `show_evidence`：只展示应用资料中的事实、来源名称与核验日期；不使用模型生成的 URL。证据卡由客户端从当前资料范围组装。

任何一个动作非法、事实 ID 不存在、请求身份或资料修订不一致，整条回复进入 `AI_INVALID_REPLY` 失败/重试状态，不能只执行看起来合法的片段。

## 4. 配置与启动

### 密钥位置

本机配置放在被 `.gitignore` 忽略的 `.local/ai-observation/config.json`，格式如下（示例值为占位，不是真实密钥）：

```json
{
  "provider": "deepseek",
  "baseUrl": "https://api.deepseek.com",
  "model": "deepseek-flash",
  "apiKey": "sk-REPLACE_WITH_LOCAL_KEY",
  "timeoutMs": 20000
}
```

也可以使用环境变量覆盖文件值：

- `YUNHEJI_AI_API_KEY` 或 `DEEPSEEK_API_KEY`
- `YUNHEJI_AI_BASE_URL`
- `YUNHEJI_AI_MODEL`
- `YUNHEJI_AI_TIMEOUT_MS`
- `YUNHEJI_AI_PROVIDER`

密钥不会进入 HAP、Git、测试报告、截图或日志。服务端启动日志只显示“已配置 deepseek/deepseek-flash”或“未配置”；不打印密钥和完整地址。

### 启动命令

```powershell
# 启动本机账号 + AI 服务（默认读取 .local/ai-observation/config.json）
.\tools\start-account-server.ps1 -TargetIds @('127.0.0.1:5555','127.0.0.1:5557')

# 单独检查配置并做一次真实模型调用（不经过 HTTPS）
node --experimental-strip-types server/ai-observation.mjs "只有四面，八组是怎么数出来的？"

# 服务端 AI 契约测试（不调用真实供应商，使用明确标注的替身）
node --experimental-strip-types --test server/ai-observation.test.mjs

# 客户端 AI 领域测试
node --experimental-strip-types --test tools/ai-observation.test.mjs

# 全部本地测试与报告解析（已包含客户端 AI 测试）
.\tools\test.ps1
```

`tools/test.ps1` 不会自动运行 `server/ai-observation.test.mjs`，也不会调用真实供应商；两类测试需要分别记录。

### 未配置/失败状态

| 场景 | 返回 | 页面行为 |
|---|---|---|
| 未登录 | `401 ACCOUNT_SESSION_EXPIRED` | 面板显示“登录后可用”；手动观察、原始资料和手写手账仍可用 |
| 服务端无密钥 | `503 AI_NOT_CONFIGURED` | 明确显示“服务端尚未配置模型凭证，本次没有调用 AI”，不显示示例回答 |
| 模型超时/取消 | `504 AI_TIMEOUT` | 显示“没有生成回答”，保留问题，可重试 |
| 供应商错误 | `502 AI_PROVIDER_ERROR` | 显示服务暂时不可用，不伪装成资料不足 |
| 返回不合契约 | `502 AI_INVALID_REPLY` | 整条回复不采用，提示重试 |
| 账号频率限制 | `429 AI_RATE_LIMITED` | 提示稍后重试，问题保留 |
| 用户停止等待 | 客户端本地 | 已停止等待，迟到回复不能覆盖新问题 |

## 5. AI 辅助手账数据

沿用 `ArchiveRecord` 的 `kind: 'note'`、`schemaVersion: 1` 和现有记录身份，新增可选 `aiAssist`：

```ts
interface AiMemoryAssist {
  version: 1;
  question: string;
  factIds: string[];
  contentRevision: number;
  facts: AiFactSnapshot[];
}
```

`facts` 冻结采纳时的资料事实 `{id, title, body, sourceIds}`。这样资料日后修订，旧手账仍能显示当时依据；解析失败时保留问题、引用 ID、正文和视角，明确显示依据版本暂不可读取，不套用新资料宣称原依据已恢复。

写入条件：只有用户采纳或修改 AI 草稿并确认保存时才写入。只问答后手写、放弃草稿、生成失败、编辑普通笔记都不补标。编辑已有 AI 手账时保留原 `aiAssist`；删除仍保留墓碑和元数据；复制、解析、版本比较和合并都包含新字段。旧普通笔记保持缺省，不批量改写时间戳或补造来源。

详细兼容边界见[MEMORY_MIGRATION.md](MEMORY_MIGRATION.md)。

## 6. 页面行为

- 面板位于对象详情内、原生视口和热点按钮附近，不另建全屏聊天首页。
- 回答到达不自动转动镜头、不自动保存、不标记路线完成；聚焦和保存都必须由用户点击。
- “AI 参考解读”和“原始资料”分开显示；资料不足与网络失败使用不同文案和状态。
- 草稿正文与资料摘录分开；编辑器显示“AI 辅助草稿 · 请确认或修改后保存”和冻结事实的中文标题，不显示内部事实 ID。
- 从首页“陪我观察”进入时自动把面板带入视野，上方模型和手动热点仍保留；用户可以上滑回到模型。
- 面板收起后只显示问题提示；再次展开保留本次问答和草稿状态。
- 从单篇手账再问时，仅预填该篇问题和最多 300 字个人观察，并恢复可重建的 revision 2 器物视角；用户主动点击“提问”后才发请求，原手账不自动改写。

## 7. 2026-10-18 首发验证结果（历史）

下表与当轮图集、日志及构建包绑定；2026-10-21 当前包的本地结果和设备验收状态见顶部 C08 节，不能将历史方鼎结果转记为当前双连壶通过。

| 项目 | 结果 | 证据 |
|---|---|---|
| 本地测试 | 103/103 | `tools/test.ps1` |
| 报告解析 | 9/9 | `tools/test.ps1` |
| 主包构建 | 成功 | `tools/build.ps1` |
| 测试包构建 | 成功 | `tools/build.ps1 -Target ohosTest` |
| 真实模型固定小样 | 9/9 HTTP 200 且通过契约校验 | [评估 JSON](test-results/2026-10-18-ai-observation-evaluation.json) |
| A 端手工主线 | 提问、聚焦、依据、草稿、保存、磁盘/服务端回读 | [图集](design/ai-observation/README.md) |
| B 端手工重访 | 同账号 HTTPS 收到新记录、AI 入口、预览、实际回放 | [图集](design/ai-observation/README.md) |
| 方鼎观察回归 | 1/1，Failure/Error/Ignore 0 | `docs/test-results/2026-10-18-013028-device.log` |

真实小样的语义人工核对、耗时和保留失败见[模型评估记录](test-results/2026-10-18-ai-observation-evaluation.md)。

## 8. 2026-10-18 首发已知限制（历史）

以下保留首发当时的验证边界；其中“未新增 AI 专用 Hypium”等描述属于当轮，当前 C08 已完成顶部列出的专用单端与双端定向验收。

- 真实模型调用只在这台开发机的本机配置下验证过；没有验证公网、代理、其他区域或其他供应商。
- 设备验证是手工 HDC / UiTest 操作 + 一次方鼎回归自动化；没有新增 AI 专用 Hypium 用例，也没有完整重跑双端账号八阶段。
- 三分钟真人演示计时未完成；现有耗时只覆盖模型单次响应和自动化回归，不等于现场操作总时长。
- 没有 A/B 整屏像素对比；AI 文字区不属于 Canvas，预览和回放只核对保存参数、页面文案和实际画面观感。
- 性能、并发、成本、配额和长期稳定性没有生产级验证；每次真实调用都计费。
- 资料边界仍为“初稿待校审”。AI 不能替代馆方原文、人工校审或实物测绘。
