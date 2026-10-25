import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { DEBUG } from 'BuildProfile';
import { validatePublicServiceEndpoint, validateServiceEndpoint } from '../domain/AccountSync';

export interface ServiceConfiguration { endpoint: string; caData?: string; }

// 账号、AI、水情使用同一来源。正式配置只允许系统受信任的公网 HTTPS；
// 本机模拟器保留既有 debug + 自签 CA 路径，不能把自签配置带入 release。
export async function loadServiceConfiguration(context: common.Context): Promise<ServiceConfiguration | undefined> {
  let publicRaw: Uint8Array | undefined = undefined;
  try {
    publicRaw = await context.resourceManager.getRawFileContent('account-service.json');
  } catch { /* 未提供公网配置时，debug 包继续读取已有模拟器配置。 */ }
  if (publicRaw) {
    try {
      const config = JSON.parse(new util.TextDecoder().decodeToString(publicRaw).replace(/^\uFEFF/, '')) as ServiceConfiguration;
      if (!validatePublicServiceEndpoint(config.endpoint) || config.caData) return undefined;
      return { endpoint: config.endpoint };
    } catch { return undefined; }
  }
  if (!DEBUG) return undefined;
  try {
    const raw = await context.resourceManager.getRawFileContent('account-sync-dev.json');
    const config = JSON.parse(new util.TextDecoder().decodeToString(raw).replace(/^\uFEFF/, '')) as ServiceConfiguration;
    if (!validateServiceEndpoint(config.endpoint, DEBUG) || !config.caData?.startsWith('-----BEGIN CERTIFICATE-----')) return undefined;
    return { endpoint: config.endpoint, caData: config.caData };
  } catch { return undefined; }
}
