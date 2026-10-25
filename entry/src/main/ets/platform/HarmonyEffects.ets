import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { BlurStrategy, hdsMaterial, HdsBarStyle, HdsBarLayoutMode, HdsTabsFloatingStyle, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';

// API 26 材质仅在官方支持的区域使用：标题栏、底部 TabBar、弹窗和部分控件。
// 该文件是新 SDK 的隔离边界；当前工程最低 SDK 仍为 26，不能把此检测宣传成 API 12 兼容。
export class HarmonyEffects {
  private static hdsTypes: hdsMaterial.MaterialType[] | undefined = undefined;

  static hdsSupported(): boolean {
    // HDS 的能力策略与 uiMaterial 不是同一个接口。只在 API 26 工程中使用，
    // 由官方组件托管顶部/底部的沉浸材质，不能靠给普通 Column 加滤镜冒充原生 Dock。
    if (HarmonyEffects.hdsTypes === undefined) {
      try { HarmonyEffects.hdsTypes = hdsMaterial.getSystemMaterialTypes(); }
      catch { HarmonyEffects.hdsTypes = []; }
    }
    return HarmonyEffects.hdsTypes.includes(hdsMaterial.MaterialType.IMMERSIVE);
  }

  static supported(): boolean {
    try {
      return deviceInfo.apiAvailable('26.0.0') && uiMaterial.isImmersiveMaterialSupported();
    } catch {
      return false;
    }
  }

  static material(enabled: boolean, reducedMotion: boolean): uiMaterial.Material {
    if (!enabled || !HarmonyEffects.supported()) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: !reducedMotion,
      lightEffect: reducedMotion ? null : { color: $r('app.color.accent') }
    });
  }

  static nativeMaterialType(enabled: boolean, reducedMotion: boolean): hdsMaterial.MaterialType {
    // HDS 没有单独关闭触点形变的参数。减少动态时关闭这一层材质和切页动画，
    // 保留官方导航形态；不以“柔和档”代替真正停止光感反馈。
    if (!enabled || reducedMotion) return hdsMaterial.MaterialType.NONE;
    return HarmonyEffects.hdsSupported() ? hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE;
  }

  static titleCapsule(enabled: boolean, reducedMotion: boolean): uiMaterial.Material {
    if (!enabled || reducedMotion || !HarmonyEffects.supported()) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      materialColor: $r('app.color.navigation_tint'),
      applyShadow: true, interactive: true,
      lightEffect: { color: $r('app.color.accent') }
    });
  }

  static titleBarStyle(enabled: boolean, reducedMotion: boolean): TitleBarStyleOptions {
    const active = enabled && !reducedMotion;
    return {
      scrollEffectOpts: {
        enableScrollEffect: active,
        scrollEffectType: HarmonyEffects.hdsSupported() ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR
      },
      blurStrategy: active ? BlurStrategy.ADAPTIVE : BlurStrategy.DISABLE,
      // 让内容在系统标题栏下逐渐淡出。顶栏没有自绘白色整块底板，
      // 材质关闭或不可用时胶囊各自回退到语义底色，文字仍有对比度。
      originalStyle: { backgroundStyle: { backgroundColor: active ? Color.Transparent : $r('app.color.canvas'), maskExtraHeight: 24 } },
      scrollEffectStyle: { backgroundStyle: { backgroundColor: active ? Color.Transparent : $r('app.color.canvas'), maskExtraHeight: 24 } },
      systemMaterialEffect: {
        materialType: HarmonyEffects.nativeMaterialType(enabled, reducedMotion),
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
  }

  static dockStyle(enabled: boolean, reducedMotion: boolean, profileBuilder?: CustomBuilder): HdsTabsFloatingStyle {
    return {
      // HDS 原生浮动栏按三个入口自适应宽度；不以百分比强制拉满，
      // 当前 SDK 的百分比配置会让材质底板偏移，窄屏也容易越过边缘。
      barSideMargin: 12, barBottomMargin: 8,
      // 官方 miniBar 在 TabBar 外并排显示；尺寸 / 材质由 HDS 协调，不增加第四个页签。
      miniBar: profileBuilder ? {
        miniBarBuilder: profileBuilder, miniBarStyle: HdsBarStyle.COLLAPSE,
        miniBarWidth: { smallWidth: 60, mediumWidth: 60, largeWidth: 60 },
        barLayoutMode: HdsBarLayoutMode.HORIZONTAL, enableMiniBarBackground: true
      } : undefined,
      lightColor: enabled && !reducedMotion ? $r('app.color.accent') : Color.Transparent,
      systemMaterialEffect: {
        materialType: HarmonyEffects.nativeMaterialType(enabled, reducedMotion),
        // 强度由系统设置托管，不固定最高档，也不另画高光或阴影。
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
  }
}
