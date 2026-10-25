# 同账号 HTTPS：原手机 → 平板 → 原手机

2026-10-23，HarmonyOS 7 / API 26 原生运行。A 为手机模拟器，B 为真正的 tablet 类型模拟器（2880×1920），传输是自建账号 HTTPS，经本机服务与 HDC 反向端口；没有云部署，也不是鸿蒙原生可信跨端。

| 阶段 | 实际包 | 原始结果 | 用时 |
|---|---|---|---:|
| A新账号真实保存一篇记忆、一条进度和第二条阅读位置，取得服务器确认 | M11 / T11 | [Pass1 / Failure0 / Error0 / Ignore0](../../../test-results/2026-10-23-033345-efb6a745-device.log) | 146497ms |
| B独立空库登录，收到A并继续第二、三条，编辑同一篇记忆后服务器确认 | M12 / T13 | [Pass1 / Failure0 / Error0 / Ignore0](../../../test-results/2026-10-23-035302-a6ad74dc-device.log) | 151558ms |
| 原A库重新登录，收到B的新正文、三条进度和第三条阅读位置，阅读不改写记录 | M12 / T14 | [Pass1 / Failure0 / Error0 / Ignore0](../../../test-results/2026-10-23-040257-eac09c66-device.log) | 81620ms |

测试生成新的独立账号与档案，没有预填 note/progress，没有清空正式用户数据。服务确认和对端实际落盘分别断言。各轮包指纹见[最终机器清单](../../../test-results/2026-10-23-roaming.json)，不把M11的运行记录改标成M12。

[完整比较结果](comparison.json)包含十项实际相等性检查，全部为true。原始JSAPP业务分片按进程与阶段过滤，按编号完整拼接，分别还原 [A保存](a-publish.json)、[B初次接收](b-received-initial.json)、[B重试接收](b-received-retry.json)、[B编辑](b-edited.json)与[原A接收](a-return-received.json)。[分片原文](business-markers.log)只含这些专用记录，无凭据或身份指针。

初次B完整收到的note、上下文、进度及位置与A完全相同；随后首次打开第二条线索会按正式规则更新阅读位置的时间与设备。重试B收到的note/上下文/进度仍与A相同，位置正文相同而版本更新，不能宣称整个重试快照逐字相同。B编辑后的完整新记录、冻结上下文、三条进度与位置，与原A接收版本完全相同；原先摘录、来源、图景修订和内容修订没有被编辑正文覆盖。

在恢复A之前，另通过只读HDC复制精确的原A Preferences，证明仍是旧正文、一条进度、第二条位置，再启动原A。[安全基线](original-a-before-return.json)保存解析结果与原件6530字节 / SHA256 `24C4AEF1EA98481F77FC6FEE675516C1BCF3CBDADE3D8BEFDC091D4D64ECD3ED`。原始XML与身份指针只留在本机，未公开。

原生图像均保留原始字节，没有重绘、拼接或裁切。八张测试图及一张测试后只读复阅图均实际查看，无账号或凭据；布局文件也排查了身份页节点。完整18文件大小、SHA256与包归属见[evidence.json](evidence.json)。

- [A本机保存与冻结依据](phone-a/a-saved.png)、[A当前第二条目标](phone-a/a-confirmed.png)。保存图的正文上部已滚出，不将它当全文对比图。
- [B接回第二条目标](tablet-b/b-resume-second-clue.png)、[B收到原正文和冻结出处](tablet-b/b-original-fulltext.png)、[B编辑后的同一篇全文](tablet-b/b-edited-fulltext.png)、[B服务器确认状态](tablet-b/b-confirmed.png)。
- [原A接收后的冻结出处](phone-a-return/a-return-fulltext.png)、[原A显示三条完成](phone-a-return/a-return-completed-chapter.png)。文件名沿用测试原名，后一张实际是返回后的首页。
- [原A完整新正文复阅](phone-a-return/a-return-full-body-review.png)：同一M12、原A测试档案，Hypium完成后再次经原生UI打开；这是补充画面，不新增设备用例计数。此时账号还收到后续登录复制专项新增的洛阳记忆，开封仍为同一条版本。

保留失败：[B首轮](../../../test-results/2026-10-23-034753-5376528e-device.log) M12/T12，Error1、50812ms，实际已接收，测试助手在转场中误找手机Scroll；T13等待目的页稳定后重试，未重新注册A。[A返程首轮](../../../test-results/2026-10-23-035906-f35194c2-device.log) M12/T13，Error1、599ms，模块Context未切换数据目录而误报身份缺失；原库存在，补上启动前原件基线、使用实际EntryAbility Context后由T14通过。失败原件保留，不用退出码0替代Pass/Failure/Error。

华为账号、鸿蒙原生可信设备传输、物理设备和正式云环境仍未验收。本轮也没有以同步结果证明在线AI可用于新增文化材料。
