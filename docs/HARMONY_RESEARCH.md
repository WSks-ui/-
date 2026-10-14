# 鸿蒙 7 技术核验记录

核验日期：2026-10-13（Asia/Shanghai）。本文件记录实际看到的资料与本地 SDK，不推断未来能力。

2026-10-14 用户已明确赛事使用团队自有鸿蒙设备，模拟器与实机均可，举办方不提供或指定运行平台。项目继续使用 HarmonyOS 7 / API 26；后文的平台版本事实用于技术能力核验，不再构成等待赛事认可的前置条件。

## 1. 已核验的官方信息

### HarmonyOS 7 与 API 26

华为开发者官网的“新能力一览”明确写明 HarmonyOS 7 (API 26)。

来源：https://developer.huawei.com/consumer/cn/features/

读取方式：普通网页检索工具本轮未返回可用正文，因此改用浏览器直接读取官方页面。没有将搜索摘要当作技术依据。

### 沉浸光感最佳实践

来源：https://developer.huawei.com/consumer/cn/doc/doccenter-advanced-features/bpta-spatiality-immersive

页面显示更新于 **2026-09-15 10:12**，本轮完整阅读相关配置段落。

要点：

- 官方称“沉浸光感”，包含材质、按压形变、触点光源等效果，不是普通背景模糊的同义词。
- ArkUI 可通过 `systemMaterial(new uiMaterial.ImmersiveMaterial(...))` 进行组件级配置。
- `uiMaterial.Material.empty` 用于明确关闭。
- 对应配置参数包括 `style`、`interactive`、`lightEffect`。
- 文档要求目标 API 不低于 26.0.0；较低版本适配需要 API 兼容性保护。
- 除弹窗、Slider、Toggle 等文档列明组件外，其他组件通常要求位于 Navigation/NavDestination 标题栏或底部 TabBar 支持区域。
- HDS 系列 `HdsNavigation`、`HdsTabs` 可通过 `systemMaterialEffect` 等接口接入；与普通 ArkUI 的参数体系不能混写。
- 光感有 GPU 成本，应查询能力并根据设备降级；不在列表每一项强制堆叠高强度材质。

## 2. 本机 SDK 证据

实际使用的 SDK 根目录：

```text
<DEVECO_HOME>\sdk\default
```

- `sdk-pkg.json`：API 26，version `26.0.0.105`，releaseType `Release`。
- DevEco `product-info.json`：版本 `26.0.0.821`。
- `openharmony/ets/api/@ohos.arkui.uiMaterial.d.ts` 包含：
  - `isImmersiveMaterialSupported(): boolean`
  - `getGlobalMaterialLevel(): MaterialLevel`
  - `Material.empty`
  - `ImmersiveMaterial`
  - `ImmersiveOptions.interactive`
  - `ImmersiveOptions.lightEffect`
- 本轮实际通过编译的接口包括 Navigation/NavDestination 标题栏 `systemMaterial` 和底部页签子节点的通用 `systemMaterial`。

**注意：SDK 目录中名为 `openharmony` 的公共能力目录，不意味着整个项目的 `runtimeOS` 已切换为 OpenHarmony。工程当前仍是 HarmonyOS。**

## 3. 本轮实现方式

`HarmonyEffects.ets` 集中负责：

1. `deviceInfo.apiAvailable('26.0.0')` 检查。
2. `uiMaterial.isImmersiveMaterialSupported()` 能力检查。
3. 关闭或不支持时返回空材质。
4. 支持时创建常规厚度材质；关闭“动态效果”后不请求形变和触点光源。
5. 标题栏、底部 TabBar 使用适配函数；正文和档案行采用普通材质。

设备页显示是否支持光感，并提供独立的光感与减少动态效果开关。

**没有实测证明所有光效都在模拟器上完整呈现。编译成功只能证明接口接入合法，不能证明真机 GPU 效果、帧率和功耗。**

## 4. 平台版本事实与本项目演示目标

| 层次 | 当前事实 | 后续动作 |
|---|---|---|
| 编译 SDK | 使用 HarmonyOS SDK API 26 | 继续现有配置，针对实际演示实例核验接口能力 |
| 最低运行版本 | compatibleSdkVersion=26.0.0 | 演示使用满足此版本的设备；当前计划不增加 API 12 兼容包 |
| 比赛设备 | 用户确认使用自有鸿蒙设备，模拟器与实机均可，举办方不指定平台 | 设备资格已确认，直接开展两端组网与传输测试 |

运行时 if 检查不能解决较低编译 SDK 根本没有新 API 类型的问题。若未来另有低版本移植需求，需要相应 SDK、编译条件或替换适配实现；这不是当前比赛演示的前置任务。

## 5. 第二轮同步调研入口

以下是后续需逐项核验的官方仓库入口，本轮没有完成双设备实现，也没有认定对应目标设备支持全部 API：

- OpenHarmony 文档：https://gitee.com/openharmony/docs
- 分布式数据服务：https://gitee.com/openharmony/distributeddatamgr_kv_store
- 设备管理：https://gitee.com/openharmony/distributedhardware_device_manager

需在目标版本确认：

1. 使用哪个分布式 KV/RDB API、系统能力和权限。
2. 应用可使用的可信设备发现、认证与组网流程。
3. 账号、签名、bundleName、storeId、数据加密等约束。
4. 模拟器是否支持目标分布式能力；手机和平板的测试拓扑。
5. 订阅/退订、离线队列、失败重试、删除传播、冲突版本保留。

赛题中的“同一华为账号自动同步”是需求描述，不是已经验证的工程前提。不能将云服务轮询或局域网演示简单改名为“鸿蒙分布式数据库”。

## 6. 最新资料维护要求

后续每次接入新特性记录：官方 URL、页面更新时间、访问日期、本地 SDK 版本、最小 API、调用区域、支持设备、降级策略、构建结果和真机验证结果。未验证项明确标记，不根据“HarmonyOS 7”名称猜测接口。

## 7. 第二轮 T02 的本机 SDK 核查

核查日期仍为 2026-10-13；目标为当前 HarmonyOS API 26，类型声明版本 26.0.0.105。

- `component/common.d.ts`：`EntryOptions.useSharedStorage` 最小 API 12，用于读取 `WindowStage.loadContent` 传入的窗口级 `LocalStorage`。测试库名不通过全局 AppStorage 共享。
- `component/common.d.ts`：`SheetKeyboardAvoidMode.RESIZE_ONLY` 最小 API 13；仅用于原生 `bindSheet` 的键盘避让，配合可滚动输入区和固定关闭/保存操作区。
- `component/search.d.ts`：`SearchController.stopEditing()` 最小 API 10；原生搜索提交后结束编辑，恢复结果区高度。
- `component/text_area.d.ts`、`component/text_input.d.ts`：输入控制器提供 `stopEditing()`，用于保存/关闭笔记时结束输入。主包编译对这两个控制器构造函数仍有系统能力覆盖提示，不能据此声称所有设备支持。
- `api/@ohos.UiTest.d.ts`：`waitForComponent` 等查询默认要求节点可见；复合 Search 的实际编辑节点在当前模拟器上为 `SearchField`，Select 菜单项为 `Option`。这些节点名称是此 SDK/设备的实测结果，后续换系统须重新检查。
- `api/@ohos.UiTest.d.ts`：`InputTextMode.paste/addition` 最小 API 20，仅用于设备测试的分段追加输入，不进入主应用。长文本旧路径曾在本机 `libuitest.z.so` 中 SIGABRT，崩溃摘要保留在 `test-results/t02-uitest-crash-summary.txt`；不得把“App died”的运行记为通过。边界用例以实际 UI 输入后清除缓存并读取 Preferences 为证据。

本轮编译与设备结果见 `TEST_REPORT.md`；这些接口的类型存在和编译成功不等于 OpenHarmony API 12 兼容性已经完成。

## 8. Yi_Da 参考改版的 SDK 核查

日期：2026-10-13；目标仍为 HarmonyOS API 26，SDK 类型声明 26.0.0.105。

- `component/select.d.ts`：Select 用 `font({ size })` 设置字号，不能沿用 Text 的 `fontSize`。本轮首个编译失败保留为 `test-results/2026-10-13-design-build-attempt1.log`，修正后构建成功。
- `component/search.d.ts`：`SearchButtonOptions.fontColor` 最小 API 10；用于统一原生“检索”按钮的主色，搜索仍操作真实 SearchField。
- `api/@ohos.arkui.UIContext.d.ts`：`vp2px`、`fp2px` 最小 API 12；按当前 UI 的字体与密度换算底部页签尺寸。首页卡片使用真实内容测量，不依赖可能未及时更新的 Context 字体配置。
- `api/application/ApplicationContext.d.ts`：`setColorMode` 最小 API 11，`setFontSizeScale` 最小 API 13；只在 ohosTest 中进行浅/深色和 1.5 倍字体审查，并在 finally 恢复应用外观与原字体倍率，不修改系统全局设置。

普通粉彩渐变、静态 Canvas 波纹和 SVG 插画属于应用装饰，不宣称鸿蒙沉浸光感效果。光感适配区域与未验证的性能边界保持原约定。

## 9. 原生沉浸光感导航核查

日期：2026-10-14；目标为本机 HarmonyOS SDK 26.0.0.105 / API 26。参考 Yi_Da 的 `HdsTabs.barFloatingStyle` 与 `HdsNavigation.titleBar` 用法，并直接核对华为 SDK 的 `@kit.UIDesignKit` 导出及类型声明。

| 官方类型 / 接口 | 本机声明的最小版本 | 本轮用途 |
|---|---|---|
| `HdsNavigation`、`titleBar` / `bindToScrollable` | HarmonyOS 5.1 / API 18；滚动绑定为 HarmonyOS 6 / API 20 | 承接原 NavPathStack；管理覆盖式标题栏，并绑定三个真实滚动容器 |
| `HdsTabs`、`HdsTabsController` | HarmonyOS 6 / API 20 | 管理三个底部页签；快捷入口与 Dock 共用当前页签状态 |
| `HdsTabsFloatingStyle`、`barFloatingStyle` | HarmonyOS 6.1 / API 23 | 官方浮动 Dock 的侧边距、底部距离、光感颜色和材质 |
| `TitleBarStyleOptions.systemMaterialEffect`、`ScrollEffectType.IMMERSIVE_GRADIENT_BLUR` | HarmonyOS 6.1 / API 23 | 标题栏原生材质、滚动渐变模糊，透明底色避免盖住效果 |
| `hdsMaterial.getSystemMaterialTypes()`、`MaterialType.IMMERSIVE`、`MaterialLevel.ADAPTIVE` | HarmonyOS 6.1 / API 23 | 查询 HDS 能力，支持时接入沉浸材质，强度随系统策略 |
| `uiMaterial.ImmersiveMaterial`、`materialColor`、`interactive`、`lightEffect` | API 26 | 仅用于官方标题栏中品牌 / 收藏胶囊，参考 Yi_Da；自定义绘制保持透明底 |
| `BottomTabBarStyle.id` / `TabBarSymbol` | API 11 / 12 | 官方页签保留稳定测试 ID 和品牌色图标，不再自绘三张材质卡片 |
| `ResourceManager.getColorByNameSync` | API 10 | HDS 状态栏只接受字符串，用语义颜色资源取实际 ARGB，避免浅色背景白字 |
| `Component.scrollSearch(on, vertical, offset)` | API 18，测试专用 | 原生浮动栏覆盖内容后，按实际节点范围调整滚动手势起止点 |
| `Driver.click`、`Component.isChecked`、`On.checked` | API 9，测试专用 | 触摸当前真实滑块，核对开关原生状态后再确认落盘；不以组件点击返回成功代替状态变化 |

HDS 类型源为本机华为 SDK `hms/ets/api/@hms.hds.hdsBaseComponent.d.ets`、`@hms.hds.hdsMaterial.d.ets`。底层材质、原生页签与测试接口分别核对 `openharmony/ets/api/@ohos.arkui.uiMaterial.d.ts`、`component/tab_content.d.ts` 和 `api/@ohos.UiTest.d.ts`。这些本机目录名称不改变工程的 HarmonyOS 运行目标。

HDS 没有公开单独停止触点形变的属性。本轮应用关闭光感或开启减少动态时，将 HDS 材质设为 `NONE`、关闭标题栏滚动材质和切页动画；标题胶囊使用基础语义底色。关闭设置只影响应用，不修改系统全局材质强度。

本轮手机模拟器实际返回 `getSystemMaterialTypes()=[101]`（`IMMERSIVE`），`isImmersiveMaterialSupported()=true`，原始输出见 [能力证据](test-results/2026-10-14-immersive-capability.log)。静态截图可检查原生悬浮形态和滚动模糊，不能据此宣布真机触点动态帧率或功耗通过。最终报告与对应包哈希见测试报告第 10 节。

## 10. 独立账号与原生 HTTPS 核查

核验日期：2026-10-14；目标仍为 HarmonyOS SDK 26.0.0.105 / API 26。用户允许先使用独立登录方案并新增第二台模拟器，本轮采用自建账号服务，未把网络轮询改名为鸿蒙分布式 KV / RDB。

| 接口 | 本机声明最小版本 | 本轮用途与实际范围 |
|---|---|---|
| `NetworkKit.http.createHttp/request/destroy` | API 6 | 注册、登录、注销与个人记录的真实网络交换 |
| `HttpRequestOptions.caData` | API 20 | debug 客户端信任本任务公开 TLS 证书，保持主机名 / 证书校验 |
| `HttpRequestOptions.body` | 26.0.0 | 当前 API 26 的 JSON 请求体字段；不使用已弃用字段替代 |
| `util.TextDecoder.decodeToString` | API 12 | 解码忽略目录生成的本机服务配置与测试 rawfile |
| `application.createModuleContext` | API 12 | ohosTest 显式读取 `entry_test` 资源，避免将随机测试凭证放入主包 |
| UIAbility `onForeground/onBackground`、窗口 LocalStorage | 既有 Stage 能力 | 控制定时交换仅在前台启动；在途请求由原生网络层结束，不宣称后台任务同步 |

声明核对本机 `openharmony/ets/api/@ohos.net.http.d.ts`、`@ohos.util.d.ts`、`@ohos.app.ability.application.d.ts` 及 Ability 生命周期声明；官方 HTTP 入口为 [华为 HTTP API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http)。`ohos.permission.INTERNET` 在模块配置中声明。客户端以 `caData` 验证短期开发证书，没有 `NODE_TLS_REJECT_UNAUTHORIZED=0` 或关闭验证的网络开关。

服务端在本机使用 Node.js 24 / SQLite，密码采用随机 salt + scrypt，令牌只保存哈希，事务合并保留墓碑 / 冲突落败版本。两台 HarmonyOS 7.0.0.107 模拟器通过各自 HDC reverse port 连接同一服务。8 个真实账号 / 双端场景、两端测试库清理与当前主包的存储 / 浏览、未登录状态和文明连线复验见 [测试报告第 12 节](TEST_REPORT.md)；本地 HTTPS / SQLite 综合测试另列 1/1。

其他在线设备统计是同账号最近 45 秒真实交换的安装实例，不是鸿蒙可信设备发现。当前会话仅在内存；正式服务 / release 配置、离线冷启动会话恢复、华为账号和分布式数据库仍未接入。此处的类型声明与模拟器证据不新增 API 12 兼容或实机签名结论。运行方式、身份 / 数据边界见 [ACCOUNT_SYNC.md](ACCOUNT_SYNC.md)。
