# AI 观察导览与 AI 辅助手账

记录日期：2026-10-18。目标工程：HarmonyOS 7 / API 26，ArkTS / ArkUI 原生应用。

本文记录当前代码中已经接入的 AI 观察路径、真实模型配置、请求契约、数据格式和验证边界。实际设备截图见[AI 观察图集](design/ai-observation/README.md)，固定小样见[模型评估记录](test-results/2026-10-18-ai-observation-evaluation.md)，原始结果与构建哈希见[测试报告第 25 节](TEST_REPORT.md)。

**同日后续：页面层级与单篇手账重访已接入。** 档案 / 记忆 / 我的均有对应入口；从手账可预填本篇问题与个人观察，点击提问后才请求模型，服务端明确将观察作为个人表达。支持 AI 手账筛选和保存时依据，修复聚焦后的模型可见性与延迟焦点异常。最终包单端真实 AI 专项 1/1（与页面层级同组 2/2），AI 服务 10/10；见[测试报告第 27 节](TEST_REPORT.md#27-页面功能层级与-ai-重访2026-10-18)和[新图集](design/page-hierarchy/README.md)。下文 AI 双端仍为第 25 节手工历史结果，尚未完成当前包的 AI 双端 Hypium 验收。

## 2026-10-19 第二对象：大河村彩陶双连壶（代码完成，待真实模型与设备复验）

在线 AI 从单件方鼎扩展为显式白名单，当前为 `zz-duling-fangding` 与 `zz-dahecun`。庙底沟虽有已核事实与 revision 2 热点，但未加入白名单，入口与服务端都会拒绝，不冒充可问。

- **内容与热点**：双连壶使用 `dahecun-object / dahecun-opening / dahecun-lines` 三条事实，热点为 `mouth / opening / paint`，场景修订 `2`；热点定义拆到独立模块 `domain/DahecunObservation.ts`，与方鼎、庙底沟保持同一结构。
- **对象化文案**：`MaterialStudy` 增加 `objectName` 与 `starters`，面板的起始问题、输入提示和收起态说明改为按对象读取，不再复用方鼎的“八组”问法。
- **统一入口判断**：详情面板、档案“可 AI 观察”筛选、手账“带着这页问 AI”和我的统计入口统一使用 `isAiObservationSite`，避免界面能开、服务端拒绝。
- **服务端作用域**：按白名单预组装，缺少事实或 revision 2 场景的对象从清单缺席；提示词由对象名、引导问题、事实、来源和热点动态生成。
- **验证**：本地 **105/105**、账号与 AI 服务 **12/12**、主包与测试包构建成功；`PageHierarchyTest#library_filters_memory_tabs_and_profile_navigation` 复跑 **1/1**（108.9s，Failure / Error / Ignore 0），覆盖“可 AI 观察”筛选从 1 处变为 2 处与方鼎面板入口。首跑在“我的”页 `profile-scroll` 出现一次 UI 定位错误（Error=1），复跑通过，原始日志分别为 `2026-10-19-220339-device.log` 与 `2026-10-19-220541-device.log`。新增 `PageHierarchyTest#twin_vessel_ai_entry_uses_its_own_starters` **1/1**（58.7s），核对双连壶三个起始问题与热点归属；`PageHierarchyTest#real_ai_focus_save_and_resume_from_memory` **1/1**（165.3s）覆盖登录、真实模型、聚焦、草稿、保存与记忆重访。新用例首跑因直接等待 `ai-observation-panel` 可见失败（面板在详情首屏下方），改为先确认详情再由 click 滚动定位后通过，未删减断言。双连壶的保存与跨端重访仍未跑。
- **真实模型（余额恢复后）**：双连壶三条观察问法 + 一条手账草稿 **4/4**，方鼎回归 **1/1**，合计 **5/5** 通过应用契约与人工核对，耗时 1670—2024 ms；引用事实、热点动作与草稿边界均正确。原始记录见[双对象小样](test-results/2026-10-19-ai-dual-object-evaluation.md)。首次尝试曾因 `402 Insufficient Balance` 中断，充值后重采，不把中断写成通过。
- **错误码**：新增 `AI_PROVIDER_AUTH`（401，凭证无效或过期）与 `AI_PROVIDER_QUOTA`（402，账户余额不足）；页面显示对应中文原因，不再一律显示“服务暂时不可用”。服务端仍不读取或记录供应商错误正文。

## 2026-10-19 AI 界面统一改版（代码完成，设备复验待模拟器恢复）

所有 AI 窗口按同一语义与尺寸重做：青色代表 AI / 资料 / 依据，玫瑰只用于用户确认的主操作；面板标题栏整行可点，回答后紧跟追问输入，草稿作为第二步；依据只保留一个开关，聚焦动作改为可换行的 chip；等待、错误、游客和草稿四态补齐骨架、退路与可读层级。首页与档案页改为双对象入口，记忆与我的页统一命名和标签色。

检查范围、19 条问题清单、设计令牌与实现落点见[AI 界面检查与统一改版](design/ai-ux-refresh/README.md)。设备复核已完成 `PageHierarchyTest` **4/4**（371.0 s，Failure / Error / Ignore 0），覆盖档案筛选、记忆全文、方鼎真实 AI 与双连壶入口；7 张截图见[设备复核截图](test-results/2026-10-20-ai-ui/README.md)。1.5 倍字体 / 深色专项仍受 `ArchiveAppearanceTest` 旧导航假设阻塞，未取得 AI 面板截图。

## 1. 当前交付范围

当前白名单为杜岭二号方鼎 `zz-duling-fangding`（首发样板）与大河村彩陶双连壶 `zz-dahecun`；方鼎场景修订 `2`、热点 `centers / corners / frame`，双连壶见上一节。资料事实继续读取 [MaterialStudyCatalog.ts](../entry/src/main/ets/data/MaterialStudyCatalog.ts)，没有另写一份可以漂移的正文。

已实现：

- 方鼎与双连壶详情内可收起的原生“AI 观察导览”面板，支持自由输入、三个对象化起始问题、等待、停止等待、重试、回答、聚焦操作和原地依据。
- 首页“本期观察 · AI 导览”入口，直接打开方鼎并把 AI 面板带入视野；原“泥火成器”下一节点、最近记忆、普通手账和路线点亮规则保留。
- 用户写一句自己的观察后请求 AI 草稿；草稿进入现有手账编辑器，用户确认或修改后保存。
- 保存时写入可选的 `aiAssist` 元信息，冻结采纳时的资料事实和资料修订号；B 端同账号通过 HTTPS 收到后显示 AI 参考入口、首页预览和实际回放。
- 服务端 `POST /ai/observe`，沿用现有账号服务认证；模型密钥只在本机被忽略的配置或服务端环境变量中。

未实现或未验收：

- 当前覆盖方鼎与双连壶两件；庙底沟及其余 17 条仍只提供离线阅读、手动观察和手写手账。
- 不做流式文字、数字人、语音、拍照识物、AI 生图、通用百科问答、向量检索、多 Agent 编排或模型微调。
- 没有公网部署、华为账号、分布式 KV/RDB、正式 release 服务配置或跨全设备矩阵验收。
- 没有真人三分钟计时，也没有录像；AI 面板现有单端真实模型 Hypium 路径与此前手工双端记录，尚不是当前包的双端 AI 自动化套件。

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
| `siteId` | 当前只接受 `zz-duling-fangding` |
| `sceneRevision` | 必须为 `2` |
| `hotspotId` | 空或 `centers / corners / frame` |
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

- `focus_hotspot`：客户端再次核对当前对象、场景修订和热点白名单，然后通过带请求序号的原生聚焦请求让视口执行；同一热点连续请求也会再次聚焦。模型不能生成相机、几何或脚本。
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
- 草稿正文与资料摘录分开；编辑器显示“AI 辅助草稿 · 请确认或修改后保存”和参考事实 ID。
- 从首页“陪我观察”进入时自动把面板带入视野，上方模型和手动热点仍保留；用户可以上滑回到模型。
- 面板收起后只显示问题提示；再次展开保留本次问答和草稿状态。

## 7. 验证结果

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

## 8. 已知限制

- 真实模型调用只在这台开发机的本机配置下验证过；没有验证公网、代理、其他区域或其他供应商。
- 设备验证是手工 HDC / UiTest 操作 + 一次方鼎回归自动化；没有新增 AI 专用 Hypium 用例，也没有完整重跑双端账号八阶段。
- 三分钟真人演示计时未完成；现有耗时只覆盖模型单次响应和自动化回归，不等于现场操作总时长。
- 没有 A/B 整屏像素对比；AI 文字区不属于 Canvas，预览和回放只核对保存参数、页面文案和实际画面观感。
- 性能、并发、成本、配额和长期稳定性没有生产级验证；每次真实调用都计费。
- 资料边界仍为“初稿待校审”。AI 不能替代馆方原文、人工校审或实物测绘。
