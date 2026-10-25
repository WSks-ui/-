// 全应用沿用五城长卷的青绿河流与暖纸，旧档案和账号页也保持一致的阅读语义。
// 普通卡片和静态渐变只负责排版装饰；官方沉浸材质仍由 platform/HarmonyEffects
// 控制，仅用于原生导航区域，不能把这些背景装饰当成设备光感能力。
export class ArchiveTheme {
  static canvas: Resource = $r('app.color.canvas');
  static surface: Resource = $r('app.color.surface');
  static soft: Resource = $r('app.color.surface_soft');
  static sunken: Resource = $r('app.color.surface_sunken');
  static ink: Resource = $r('app.color.ink');
  static muted: Resource = $r('app.color.muted');
  static tertiary: Resource = $r('app.color.tertiary');
  static accent: Resource = $r('app.color.accent');
  static onAccent: Resource = $r('app.color.on_accent');
  static accentSoft: Resource = $r('app.color.accent_soft');
  static line: Resource = $r('app.color.line');
  static rose: Resource = $r('app.color.home_rose');
  static blue: Resource = $r('app.color.home_blue');
  static mint: Resource = $r('app.color.home_mint');
  static yellow: Resource = $r('app.color.home_yellow');
  static blueInk: Resource = $r('app.color.home_blue_ink');
  static mintInk: Resource = $r('app.color.home_mint_ink');
  static yellowInk: Resource = $r('app.color.home_yellow_ink');
  static pagePadding: number = 16;
  static cardRadius: number = 22;
  static inputRadius: number = 14;
  static buttonRadius: number = 14;
  static tileRadius: number = 18;
}

// 使用系统 fp 字号，让标题、正文、说明一起响应用户字体设置。
export class ArchiveType {
  static display: Resource = $r('sys.float.ohos_id_text_size_headline7');
  static title: Resource = $r('sys.float.ohos_id_text_size_headline8');
  static section: Resource = $r('sys.float.ohos_id_text_size_sub_title1');
  static card: Resource = $r('sys.float.ohos_id_text_size_sub_title2');
  static body: Resource = $r('sys.float.ohos_id_text_size_body1');
  static small: Resource = $r('sys.float.ohos_id_text_size_body2');
  static caption: Resource = $r('sys.float.ohos_id_text_size_body3');
}
