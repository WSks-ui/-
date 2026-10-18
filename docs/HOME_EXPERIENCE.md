# 首页主题与最近记忆

日期：2026-10-17。对应核心体验成型阶段 **T09 首页优先级 / T10 主题直达入口**；同日晚上按用户要求改版：恢复此前更满意的沙盘、纸页入口与城市索引结构，并整体优化视觉与布局，同时保留主题直达与最近真实记忆。实现位于 `entry/src/main/ets/pages/Index.ets`，继续使用 HarmonyOS 7 / API 26、ArkUI 原生页面与既有 HDS 导航。改版后本地95/95、报告解析9/9，两包构建成功；首页核心设备路径1/1，Failure / Error / Ignore均为0，耗时203638ms，实际页面见[首页改版图集](design/home-redesign/README.md)与[测试报告第24节](TEST_REPORT.md#24-首页-ui-与布局改版2026-10-17)。

## 首页内容顺序（2026-10-17 晚改版）

1. 河迹眉题与“沿河，遇见文明”大标题、副题。
2. 单张“泥火成器”主题卡：四节点真实进度圆点、进度文字、下一处内容与直达入口；“全部路线”打开个人页。
3. 最近一条真实活跃笔记：遗址、印章、时令、原画幅预览、正文、标签与“重返观察 / 阅读全文”；无记录时为紧凑引导。
4. 恢复“循河探索”五城河洛沙盘、文明连线与黄河寻迹漫游。
5. 恢复“拾页入口”纸质卡片：从彩陶读起、河流记忆、随身档案，含贴纸与真实跳转。
6. 恢复五城索引，并把搜索、筛选、结果数与重置收进“检索档案”卡片；其下为文化目录与关联档案。

此前一轮曾用主题卡与最近记忆替代三张高纸片卡；本轮按用户偏好恢复这些入口，但主题和真实记忆仍保留在首屏前列。五城沙盘、图谱、城市筛选和搜索目录继续可用。顶部 HDS 标题栏、原生浮动 Dock 与右下独立“我的”入口沿用既有实现。

## 主题直达与路线边界

首页从 `JOURNEY_ROUTES` 选择 `earth-and-fire`，每次使用当前 `snapshot.records` 调用 `journeyProgress`。入口通过 `siteFor(progress.nextSiteId || progress.route.siteIds[0])` 找到目录对象，再调用 `openSite` 进入详情，不先经过个人页。

- 空档案显示“已探索 0 / 4 处”，从庙底沟遗址开始。
- 有已完成节点时，入口指向领域规则计算的下一处；全线完成后从路线首项重访。
- 点击只执行既有打开详情行为，不额外写入路线完成状态，也不把 `opened` 访问记录算作完成。
- 保存、删除或同步更新快照后，首页重新派生进度，没有独立的首页完成缓存。
- 路线对应目录缺失时给出明确提示，不代入无关档案。

完整“泥火成器”仍有四个节点，顺序不变：

1. 庙底沟遗址 `smx-miaodigou`。
2. 大河村遗址 `zz-dahecun`，本阶段重点对象为彩陶双连壶。
3. 杜岭二号方鼎 `zz-duling-fangding`。
4. 开封铁塔 `kf-iron-pagoda`。

“全部路线”进入既有 `ProfilePage / JourneyPanel`，保留三条路线的完整节点、进度与主题图谱入口。点亮规则仍为单处达到 **75% 显式探索进度或存在有效拾遗手账**；全部节点完成后才点亮路线纪念章。旧普通笔记、收藏及仅打开过的记录不升级为完成。本轮没有新建路线或增加徽章，主题顺序仍是阅读编排，不表示历史先后、交通线路或考古层序。

## 最近真实记忆

首页使用 `activeRecords(snapshot.records, 'note').slice(0, 1)` 选取最近记录。该函数排除删除墓碑，并按真实 `updatedAt` 倒序、相同时间按既有 ID 顺序排列；最近指最近更新的活跃笔记，不限于新建手账。标题使用 `memorySite(note)`，正文保留两行摘要，“全部手账”可进入完整记忆页。

卡片复用 `MemoryPosePreview`，预览高度为 **124vp**。组件使用已保存的原虚拟画幅、字体密度、明暗及视角参数重建，按 `contain` 完整等比适配，保留必要留白，不用首页尺寸重新取景。只有实际绘制成功后才显示“已重建保存画面”。列表 key 包含记录 ID 与更新时间；真实保存落盘并发布新快照后，首页预览随记录版本更新。

点击保存画面或“重返观察”调用 `openMemory(note, true)`，交给既有详情正式回放流程；“打开档案”调用 `openMemory(note, false)`。无视角的旧笔记显示“打开观察”，进入当前档案观察，不声称恢复了旧画面。

没有活跃笔记时，首页显示“还没有留下记忆”和“开始第一次观察”。该按钮与主题入口共用 `openHomeTheme()`，不会为演示创建示例记录、伪造保存或自动点亮节点。

## 旧记录与数据兼容

- 旧普通 note 仍可阅读，缺少观察参数时显示文字记忆状态，不补写印章、画面、视角或完成信息。
- 带旧视角但未记录完整原取景的手账沿用现有回放兼容提示，不把当前画幅和外观写回旧记录。
- 未知档案使用“原档案暂不可用”的明确身份，保存的文字仍保留；预览说明对应档案不可恢复，回放按钮显示“暂不可回放”，档案与回放按钮禁用。不会用目录首条替代原档案。
- 本轮只改变首页呈现与入口，**没有新增记录字段、提升 schema 或修改保存格式**，不需要新增迁移步骤。删除墓碑、损坏读取保护及既有手账兼容行为保持原规则，详见[手账数据兼容说明](MEMORY_MIGRATION.md)。

主题插画继续使用项目原创主题示意，不是文物照片或考古复原；文化条目保持“初稿待校审”。

## 专项验收入口

专项用例为 `HomeExperienceTest#native_home_theme_recent_memory_route_replay`。先按工程约定运行本地验证并构建两包；在 HDC 实际列表确认目标设备后，精确执行该方法。以下命令使用当前工程常用目标示例，执行前应替换为当时实际在线的 target：

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'HomeExperienceTest#native_home_theme_recent_memory_route_replay' -ExpectedTests 1
```

验收围绕空档案主题直达、真实保存后首页最近画面、路线实际进度、正式回放与个人页完整节点。结果须结合原始报告中的 `Pass / Failure / Error / Ignore`、同版本包及实际截图记录；`aa test` 退出码不能替代用例结论。本轮设备结果为 **1/1**，Failure / Error / Ignore均为0，原始结果为[2026-10-17-200742-device.log](test-results/2026-10-17-200742-device.log)；[五组原图及布局](design/home-experience/README.md)、[实际包与源码绑定](test-results/2026-10-17-home-experience-phases.json)及[像素核对](design/home-experience/pixel-checks.json)可复核。一次启动中断、三次测试定位错误及一次实际首页刷新缺陷保留于[中间清单](test-results/2026-10-17-home-experience-intermediate.json)，均不累计到最终1/1。

| 稳定 ID | 对应入口或状态 |
|---|---|
| `home-theme-entry` | 精选主题卡，直接进入下一处详情 |
| `home-theme-progress` | `已探索 X / 4 处` |
| `home-theme-next-site` | 首项 / 下一处 / 重访目标 |
| `home-all-journeys` | 进入个人页查看完整路线 |
| `home-empty-memory` | 无活跃笔记时的明确空态 |
| `home-empty-memory-explore` | 开始第一次观察 |
| `home-recent-memory` | 最近真实活跃笔记卡片 |
| `home-recent-memory-site` / `home-recent-memory-body` | 档案名与正文摘要 |
| `home-recent-memory-preview-canvas` | 保存画面的原生 Canvas |
| `home-recent-memory-preview-status` | 真实重建状态 |
| `home-recent-memory-replay` / `home-recent-memory-open` | 回放 / 打开档案 |
| `memory-entry` | 查看全部手账 |

同账号另一端的新手账接收、预览与正式回放属于 T11；三分钟脚本和真实备用录像属于 T13。T11 已在后续轮次完成：B 端同账号收到同一 note，首页显示 1/4 与原画幅预览，点击后正式回放，两端整幅 Canvas 零差异，见[测试报告第23节](TEST_REPORT.md#23-双端新手账同账号闭环与主线排练2026-10-17)与[双端图集](design/memory-sync/README.md)。T13.2 录像尚未完成。

## 本轮实际验证

本地 **95/95**、设备报告解析 **9/9**，主包与测试包均 `BUILD SUCCESSFUL`。唯一首页核心设备路径 **1/1**，Failure / Error / Ignore 均为 0，耗时 **161021ms**，原始报告为 [2026-10-17-200742-device.log](test-results/2026-10-17-200742-device.log)。通过真实离线入口进入独立随机档案库，确认首页主题直接打开庙底沟、仅打开仍为0/4；选择西部陶窑并主动右转后，通过编辑器真实保存正文、标签、事实摘录和视角，清 Preferences 缓存后从磁盘回读。回首页后显示真实最新手账、预览及1/4，下一处变为大河村；点击首页画面正式回放，选中热点与实际绘制相机一致，并核对个人页完整四节点仅庙底沟点亮。

实际五组原图及配套 dumpLayout 已归档，保存前 / 正式回放的 **1032×1050整幅Canvas**，变化像素为 **0**，最大通道差为 **0**，模型区域 **361127像素**无差异。首页124vp预览依据磁盘原虚拟画幅去除contain留白后，与保存画面等比核对的RGB相关系数为 **0.997163169**，平均绝对通道差为 **1.023252**。完整值见[像素核对](design/home-experience/pixel-checks.json)，包、源码与原图绑定见[阶段清单](test-results/2026-10-17-home-experience-phases.json)，实际页面见[本轮图集](design/home-experience/README.md)。

主包 SHA-256：`00B1774C2D4F858C7F5F52738C16AC02FE5B39660A3C33B4672FE44263791D94`。

测试包 SHA-256：`485CE18969CF307465C15E7F7263E72C65A33F382A06709197C45C3A36F1BD18`。

本轮先将三处观察扩展以中文提交并推送到 `origin/main`，提交为 `99328acc41457a280d5b2a4233920e1fdf9578f7`；本节T09/T10首页开发、必要测试和验证材料尚未二次提交或推送。

## 2026-10-17 晚改版验证与边界

- 本地 **95/95**、报告解析 **9/9**，主包与测试包 `BUILD SUCCESSFUL`；首页核心路径 `HomeExperienceTest#native_home_theme_recent_memory_route_replay` **1/1**，Failure / Error / Ignore 均为 0，**203638ms**，原始报告为 [2026-10-17-234825-device.log](test-results/2026-10-17-234825-device.log)。
- 纸页入口的贴纸使用白色厚描边、彩色贴纸、轻微旋转并半凸出卡片边缘，纸卡下垫 `surface_sunken` 底纸；全部为实色叠放，不使用阴影或渐变。主玫瑰色与小字灰棕分别收紧到 `#B24C5E`、`#7D6A60`，深色 `tertiary` 提亮到 `#A08E83`，以改善按钮白字与小字说明的对比度。
- 改版后主包 `935E945F1A438ECD4454328B95D7A8683FC048647E4CD24EF94643AC1E735BAE`，测试包 `13222779FBE8945F6473A198736A238B7934B7C2C947E90087A159EF30798BA4`；包、源码、报告与截图绑定见[阶段清单](test-results/2026-10-17-home-redesign-phases.json)。
- 所有自动化 id 保留；`memory-entry`、`featured-site` 随卡片下移到纸页入口区，相关旧用例改为在真实 Scroll 中定位后再点击，业务断言未删改。
- 深色模式已实际查看；大字模式与旧外观套件在本轮未通过（外观套件超时，登录套件仍期待仅会话内保留的大学资料），保留在[中间清单](test-results/2026-10-17-home-redesign-intermediate.json)，不计通过，也不作为首页验收。
- T11 双端结果对应改版前首页布局；账号同步与 B 端接收逻辑未改，本轮没有重跑双端，首页回归以本次 1/1 为准。T13.2 录像仍未完成。
