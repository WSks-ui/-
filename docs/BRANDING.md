# 品牌资源：包名、图标与启动页

## 1. 当前身份

| 项目 | 值 | 位置 |
|---|---|---|
| 应用名 | 云河纪 | `AppScope/resources/base/element/string.json` |
| 包名 | `com.yunheji.archive` | `AppScope/app.json5` |
| vendor | `yunheji` | `AppScope/app.json5` |
| 版本 | 0.1.0（10000） | `AppScope/app.json5` |
| 图标 | 分层图标 `$media:layered_image` | `AppScope/resources/base/media/`、`entry/src/main/resources/base/media/` |
| 启动标识 | `$media:startIcon` | `entry/src/main/resources/base/media/startIcon.png` |
| 启动背景 | `#FAF6F0` / 深色 `#171311` | `entry/src/main/resources/base/element/color.json` |

包名由模板 `com.chr.myapplication` 改为 `com.yunheji.archive`。**改包名会清空本机偏好与演示数据**：新旧包在系统中是两个应用，旧包需要卸载；演示账号需要在新包内重新登录，服务端账号数据不受影响。

## 2. 图标概念

![图标预览](icon-preview.png)

- 符号：**方鼎 + 河流**。鼎身、鼎耳与四足对应应用的观察对象；腹部青色曲线是黄河；右侧玫瑰圆点取“印记 / 观察点”的意象。
- 底色：纸色径向渐变，底部一条半透明青色河带；右上角淡玫瑰圆环是印章的抽象。
- 颜色：青铜 `#A06A48 → #784832`、青色 `#3F7F6B`、玫瑰 `#B45F63`、纸色 `#FBF6EE / #EFE1D0`。与应用内的纸色、青铜、玫瑰与 AI 青色语义一致。
- 形状：分层图标由 `background.png`（纸色渐变与河带）与 `foreground.png`（透明鼎与河线）组成；系统负责圆角裁切，图形保持在中心安全区。

实际桌面效果：

![桌面图标](launcher.jpg)

## 3. 启动页

`module.json5` 的 `startWindowIcon` 指向 `$media:startIcon`，启动背景使用 `start_window_background`。启动标识为 512×512 的纸色圆形徽章，内含鼎与河流，保证在浅色和深色启动背景上都能看清。

模拟器冷启动很快，系统启动窗口停留时间短；已确认启动背景与资源生效，桌面图标、应用名和新包名安装均通过。若后续需要更长的品牌停留，应在应用内做首帧加载层，而不是伪造系统启动页。

## 4. 资源规格

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `AppScope/resources/base/media/background.png` | 1024×1024 | 纸色渐变 + 河带 + 印章环 |
| `AppScope/resources/base/media/foreground.png` | 1024×1024，RGBA | 透明底鼎与河线 |
| `entry/src/main/resources/base/media/background.png` | 1024×1024 | 同上，供 Ability 图标使用 |
| `entry/src/main/resources/base/media/foreground.png` | 1024×1024，RGBA | 同上 |
| `entry/src/main/resources/base/media/startIcon.png` | 512×512，RGBA | 纸色徽章 + 鼎与河流 |

`layered_image.json` 不需要改，仍指向 `$media:background` 与 `$media:foreground`。背景图使用 128 色调色板压缩（约 32 KB），前景与启动标识保留 RGBA。

## 5. 包名影响面

已同步更新：

- `tools/device-test.ps1`：`aa test -b com.yunheji.archive`
- `tools/restart-test.ps1`：启动、停止与 `pidof` 均使用新包名
- `entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ets`：TestAbility 宿主包名
- `entry/src/ohosTest/ets/test/ArchiveUiSession.ets`：启动应用与失败布局导出包名

未更新会出现的现象：测试能安装，但 `TestAbility failed to start`，日志中会看到运行器仍去启动 `com.chr.myapplication/TestAbility`。

## 6. 验证与边界

- 新包名安装成功，桌面只保留一个“云河纪”图标；旧模板包已卸载。
- 品牌化后双连壶入口设备用例 **1/1**（62.6 s，Failure / Error / Ignore 0）。
- **未配置签名**：`build-profile.json5` 的 `signingConfigs` 仍为空，当前 HAP 为 unsigned，只用于模拟器。装到团队真机前必须在 DevEco 登录华为账号完成自动签名，相关边界见[交接文档](HANDOVER.md)与 `README.md` 的“答辩前必须切换”条目。
- 启动页只验证了资源与背景；系统启动窗口的图标展示时间受设备启动速度影响，未做逐帧截图。
