import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { emptyRoamingCardBinding, refreshRoamingForm, registerRoamingForm, unregisterRoamingForm } from './RoamingCardData';

// 普通 ArkTS 2×4 卡片；不依赖仅实机支持的互动卡片、可信接续或远端设备数量。
export default class RoamingFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    try {
      return registerRoamingForm(this.context, want);
    } catch {
      // 首次添加时缓存暂不可读仍能安装卡片，显示无个人内容的诚实空态。
      hilog.warn(0x0000, 'RoamingForm', 'Form cache is unavailable during add.');
      return emptyRoamingCardBinding(want);
    }
  }

  onUpdateForm(formId: string): void {
    refreshRoamingForm(this.context, formId).catch(() => {
      hilog.warn(0x0000, 'RoamingForm', 'Form refresh is pending.');
    });
  }

  onRemoveForm(formId: string): void {
    try { unregisterRoamingForm(this.context, formId); }
    catch { hilog.warn(0x0000, 'RoamingForm', 'Form registry removal is pending.'); }
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
