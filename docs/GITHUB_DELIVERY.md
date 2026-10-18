# GitHub 交付记录

日期：2026-10-18。分支：`main`，目标：`origin/main`。本次记录用户最新更新后的提交范围与验证结果；具体提交编号以 Git 历史为准。

## 交付范围

- 首页主题、最近真实记忆、五城河洛交互及原生页面布局更新。
- 记忆的手账 / 收藏分区、独立全文、编辑刷新、搜索、视角重温和删除墓碑；档案完整筛选；我的概况及二级页面。
- 杜岭二号方鼎真实 AI 观察、部位聚焦、依据、草稿采纳、冻结事实与单篇手账重访，以及对应服务代码。
- 同账号记忆同步的既有实现和历史双端验证材料。
- 20 条文化档案、五城简介、16 张授权实景图片及[来源与署名](IMAGE_CREDITS.md)。
- [校赛选拔设计文档](deliverables/云河纪-校赛选拔设计文档.docx)、图集、交接任务书、测试报告和原始设备结果。

本机配置、密钥、签名、数据库、HAP、构建缓存和 Office 临时解包目录按忽略规则保留在本机。公开构建日志只替换本机工程 / 工具路径，原始输出保留在本机忽略目录。

## 提交前验证

| 检查 | 结果 | 记录 |
|---|---|---|
| `tools/test.ps1` | 103/103；报告解析 9/9 | [本地测试](test-results/2026-10-18-github-final-local-test.log) |
| AI 服务与账号服务 | 11/11，fail 0 | [服务测试](test-results/2026-10-18-github-final-service-test.log) |
| 主包构建 | BUILD SUCCESSFUL | [构建输出](test-results/2026-10-18-github-final-main-build.log) |
| ohosTest 构建 | BUILD SUCCESSFUL | [构建输出](test-results/2026-10-18-github-final-test-build.log) |
| 档案、记忆与我的页面核心路径 | 1/1，94704ms；Failure / Error / Ignore 0 | [原始设备报告](test-results/2026-10-18-132037-device.log) |

设备专项：`PageHierarchyTest#library_filters_memory_tabs_and_profile_navigation`，HarmonyOS 7.0.0.107 / API 26 手机模拟器，独立 Preferences。覆盖档案筛选、空状态与重置、游客 AI 状态、返回保留筛选、记忆分区、我的二级导航及偏好落盘；未重跑完整历史 UI、真实供应商 AI 或双端套件。

当前主包为 6,112,301 字节，SHA-256 `EF9FCADB10275DE2438486D6766B8E88FB68B17523EA17C60165649D53488F84`；测试包为 6,252,339 字节，SHA-256 `3E52F597A80CFCA6DA81F3E739FEE49724C1C470AC1E08B30F247F8EB1802C5F`。包、源码、素材和报告绑定见[本次快照](test-results/2026-10-18-github-final-snapshot.json)。

## 保留的范围

AI 仍只支持杜岭二号方鼎；其余档案保留手动阅读与观察。文化内容仍为初稿待校审，模型仍为学习示意。同账号同步使用现有 HTTPS 服务，尚未接入鸿蒙分布式 KV。真人三分钟计时与录像、当前包完整双端 AI 验收等状态保持原记录，没有因提交或构建成功而自动完成。

已有 ArkTS 能力 / 异常提示与未配置签名警告仍保留。此次推送用于交付当前比赛演示工程，不变更版本号、签名配置或既有验证结论。
