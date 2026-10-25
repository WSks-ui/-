# 全面审查原生画面

日期：2026-10-20。HarmonyOS 7.0.0.107 / API 26 手机模拟器，1256×2760，正常字号浅色外观。

全部图片来自实际设备 `uitest screenCap`，没有用网页、设计稿或渲染概念图替换。记录是本轮独立测试档案，不含用户个人账号。主包 SHA-256：`D7BAEF8FC882E15C21405CC14C577187ABB0D5257222CC393AD237EC5A66CA6C`。

| 文件 | 画面 | 来源与核对重点 |
|---|---|---|
| [01-ai-focus.png](01-ai-focus.png) | AI 聚焦方鼎折角 | PageHierarchy 本轮首跑第 3 项通过；真实模型动作与原生画面一致 |
| [02-memory-first-screen.png](02-memory-first-screen.png) | AI 手账保存后的记忆首屏 | 同上；筛选、排序与标签挤占首屏，首卡顶部 y=1972px |
| [03-library.png](03-library.png) | 档案首屏 | PageHierarchy 首跑第 1 项的中间截图；该次整项后来因测试控件失效报错，最终单项复跑另记 |
| [04-memory-manage.png](04-memory-manage.png) | 记忆多选管理 | PageHierarchy 首跑第 5 项通过；多选数量与操作条 |
| [05-profile.png](05-profile.png) | 我的概览 | 同上；四格统计与二级菜单 |
| [06-data.png](06-data.png) | 数据与存储 | 同上；当前是复制 JSON，没有恢复入口 |
| [07-water.png](07-water.png) | 水情三站与观测值 | WaterSituation 本轮 1/1；“实时·08:00”的时间语义需明确 |
| [08-native-graph.png](08-native-graph.png) | 原生文明图谱 | EngineExperience 原生图谱专项 1/1；完整画布可继续滚动查看 |
| [09-native-comparison.png](09-native-comparison.png) | 二里头与郑州商城对照 | 同上；两档案与共同线索 |
| [10-A-home-memory.png](10-A-home-memory.png) | A 保存后的首页真实记忆 | MemorySync A 1/1；路线 1/4、实际预览与下一站 |
| [11-A-saved-view.png](11-A-saved-view.png) | A 保存前西部陶窑视角 | 同上；非默认转角，用于和 B 回放核对 |
| [12-home-first-screen.png](12-home-first-screen.png) | 空白档案的首页首屏 | 旧图谱用例本轮中间截图，整项因旧控件 ID 失败；只作首页布局说明 |
| [13-B-home-memory.png](13-B-home-memory.png) | B 同账号收到的首页记忆 | MemorySync B 1/1；本次新增记录与真实预览 |
| [14-B-replay.png](14-B-replay.png) | B 正式原生回放 | 同上；恢复本次保存的部位和角度 |

原始设备报告、测试包阶段与后续追加截图见[全面审查](../2026-10-20-competition-audit.md)文末。截图不能单独替代整项功能验收。

附：[目录清点](catalog-inventory.json)、[20 条来源链接访问结果](source-links.json)、[A/B 像素核对](memory-pixel-check.json)。原生视口全区域 1,083,600 像素中 4 像素不同，最大单通道差 1，位于工具胶囊边缘；不宣称整幅零差异。
