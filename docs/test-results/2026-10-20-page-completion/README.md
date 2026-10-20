# 「记忆」「档案」「我的」功能补齐：设备复核

日期：2026-10-20
设备：`Pura 90 Pro` 模拟器，HarmonyOS 7.0.0.107 / API 26，1256×2760
主包：6,380,589 字节，SHA-256 `7B3B12D488322948B4857DE1873138BC5398216C2F191AF2EEA31570E04CF88A`
测试日志：`docs/test-results/2026-10-20-141605-device.log`

## 结果

| 用例 | 覆盖 | 结果 |
|---|---|---|
| `library_filters_memory_tabs_and_profile_navigation` | 档案筛选、收藏分区、个人页导航、AI 游客态 | 通过 |
| `memory_fulltext_edit_replay_search_and_tombstone` | 手账全文、编辑、视角回放、搜索、删除墓碑 | 通过 |
| `real_ai_focus_save_and_resume_from_memory` | 方鼎真实 AI、聚焦、保存、记忆回访 | 通过 |
| `twin_vessel_ai_entry_uses_its_own_starters` | 双连壶入口与对象化起始问题 | 通过 |
| `memory_sort_tag_batch_and_profile_data` | 排序、标签、批量选择、复制、批量删除、档案已浏览、我的四格统计与数据页 | 通过 |

整类 **5/5**，499.2 秒，Failure / Error / Ignore 均为 0。

最终包重建后，单独复跑 `memory_sort_tag_batch_and_profile_data` 再次 **1/1**（93.1 秒），日志 `docs/test-results/2026-10-20-143211-device.log`。

本地：`.\tools\test.ps1` **113/113**，报告解析 9/9；主包与测试包均 `BUILD SUCCESSFUL`。

## 截图

| 文件 | 内容 |
|---|---|
| `01-memory-manage.png` | 记忆页管理模式入口、排序胶囊、动态标签、月份分组 |
| `02-memory-selected.png` | 多选状态、已选计数、复制/删除操作条 |
| `03-memory-tag-filter.png` | 标签筛选生效，#测试标签 高亮，记录未被改写 |
| `04-archive-visited.png` | 档案页“已浏览”筛选、结果 1 处、卡片“已读”角标 |
| `05-profile-stats.png` | 我的页四格统计：手账 / 收藏 / AI 辅助 / 已浏览 |
| `06-profile-data.png` | 数据与存储：记录数、已浏览进度、本机占用、复制备份 |

## 本轮跑通时修复的两个问题

1. **批量删除确认文案歧义**：工具栏已有“删除”，确认框再用“删除”会被自动化与用户误点回工具栏；改为“确认删除”。
2. **筛选胶囊高亮不更新**：结果已变化，但 `ForEach` 复用了旧胶囊节点；把选中态并入 key，强制重建。截图 03/04 为修复后效果。

## 未覆盖

- 复制备份、复制手账的剪贴板内容未做逐字断言，仅验证按钮可点击、无异常。
- 未新增导入、清空本机、隐私与帮助页面；这些仍属于后续项。
- 按用户要求，不做 1.5 倍字体专项。
