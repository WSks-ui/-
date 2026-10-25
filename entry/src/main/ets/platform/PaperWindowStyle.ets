import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

// 本机API26的HDS根导航与NavDestination会先后设置系统栏文字；仅声明
// systemBarStyle在浅纸记忆页仍实测继承夜色首页。页面真正显示/隐藏时再设置
// 本窗口文字颜色，不改背景、不换安全区，也不让外观失败阻断正文阅读。
export function setPaperWindowText(ui: UIContext, color: string): void {
  try {
    const context = ui.getHostContext() as common.UIAbilityContext;
    window.getLastWindow(context).then((mainWindow: window.Window) => {
      return mainWindow.setWindowSystemBarProperties({ statusBarContentColor: color,
        navigationBarContentColor: color });
    }).catch(() => {});
  } catch (_error) {}
}
