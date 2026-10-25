import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { loadServiceConfiguration, ServiceConfiguration } from './ServiceConfiguration';
import { validateWaterLiveReply, WaterLiveReply } from '../domain/WaterSituation';


// 水情只读接口与账号服务共用同一个 Debug HTTPS 端点与自签证书。
// 不在 HAP 内直连 IP + HTTP 的日报源：抓取与解析留在服务端，App 只读自有接口。
export class WaterSituationClient {
  private configuration: ServiceConfiguration | undefined = undefined;
  private context: common.Context;

  constructor(context: common.Context) { this.context = context; }

  async configure(): Promise<boolean> {
    this.configuration = await loadServiceConfiguration(this.context);
    return this.configuration !== undefined;
  }

  async fetch(): Promise<WaterLiveReply> {
    const config = this.configuration;
    if (!config) throw new Error('WATER_SERVICE_NOT_CONFIGURED');
    const request = http.createHttp();
    try {
      const result = await request.request(config.endpoint + '/water/situation', {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        caData: config.caData,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        usingProxy: false,
        connectTimeout: 5000,
        readTimeout: 12000
      });
      if (typeof result.result !== 'string' || result.responseCode !== 200) {
        throw new Error('WATER_UNAVAILABLE');
      }
      return validateWaterLiveReply(JSON.parse(result.result) as WaterLiveReply);
    } finally { request.destroy(); }
  }
}
