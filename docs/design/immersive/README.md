# 顶部与 Dock：原生沉浸光感

日期：2026-10-14。用户要求参照 Yi_Da 的顶部与底部导航案例，接入鸿蒙原生沉浸光感。

当前 9 张原图来自最终 `134918-device.log` 的 2/2 专项，已逐张查看。比较图见 [overview.png](overview.png)，原图、当前主包 / 专项测试包与原始报告的 SHA-256 清单见 [captures.json](captures.json)。功能回归使用同一主包，功能测试包版本关系见测试报告第 10 节。

底部使用 `HdsTabs`、`BottomTabBarStyle` 和 `barFloatingStyle`，顶部使用 `HdsNavigation.titleBar`、`systemMaterialEffect` 与 `IMMERSIVE_GRADIENT_BLUR`。品牌和收藏胶囊的底层 `uiMaterial` 只放在官方标题栏内。悬浮形状、高光、材质和滚动模糊由原生系统组件提供，没有自行绘制模拟光效。

SDK：HarmonyOS API 26。当前手机模拟器返回 HDS `IMMERSIVE` 能力和底层材质支持。强度通过 `MaterialLevel.ADAPTIVE` 跟随系统；关闭光感或开启减少动态时使用 `NONE`，继续保留原生导航形态和基础可读性。

| 截图 | 场景 |
|---|---|
| [home.png](home.png) | 浅色首页，原生标题胶囊与浮动 Dock |
| [scrolled.png](scrolled.png) | 实际滚动到目录，内容经过系统标题栏与浮动 Dock |
| [scroll-bottom.png](scroll-bottom.png) | 定位并核对河迹页尾说明，检查最后内容与 Dock 的净空 |
| [disabled.png](disabled.png) | 真实 UI 关闭光感并落盘后的首页 |
| [reduced.png](reduced.png) | 真实 UI 开启减少动态并落盘后的首页 |
| [dark.png](dark.png) | 深色首页 |
| [scrolled-dark.png](scrolled-dark.png) | 深色滚动目录 |
| [large.png](large.png) | 1.5 倍字体首页 |
| [detail-large.png](detail-large.png) | 大字详情与原生导航返回 |

截图均来自真实 ArkUI 窗口。测试使用独立 Preferences，HDC / Hypium 直接连接模拟器，没有控制电脑桌面。原图保持设备截图像素，比较图只进行等比缩放、排列和页名标注。

构建、功能回归、专项测试与失败修复记录见 [测试报告第 10 节](../../TEST_REPORT.md)。静态截图不证明真机触点动画的帧率与功耗，当前覆盖范围为这台手机模拟器。

阶段性自动化通过后，人工曾发现默认 `scrollToBottom` 手势误切页；相关旧图保留在被忽略的排查目录，不混入此清单。最终专项同时核对页面内容、真实开关 checked 状态与 Preferences 落盘，采图全过程使用正确页面的无遮挡手势。
