import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AccountSession, AccountWorkspace, parseAccountWorkspace, validateAccountSession } from '../domain/AccountSync';

export interface RestoredAccount {
  workspace: AccountWorkspace;
  session?: AccountSession;
}

// 身份指针单独保存，不改 v1 收藏/手账格式。访问令牌只进入系统 ASSET，
// 不写 Preferences、快照、备份或日志。系统不支持 ASSET 时仍保留离线身份，
// 冷启动后要求重新登录再同步；不回退到明文保存令牌。
export class AccountWorkspaceStore {
  private context: common.Context;
  private name: string;
  constructor(context: common.Context, archiveStore: string) {
    this.context = context;
    this.name = `${archiveStore}_identity_v1`;
  }

  private alias(): Uint8Array { return new util.TextEncoder().encodeInto(this.name); }

  async load(): Promise<RestoredAccount | undefined> {
    const store = await preferences.getPreferences(this.context, { name: this.name });
    if (!await store.has('workspace')) return undefined;
    const workspace = parseAccountWorkspace(await store.get('workspace', '') as string);
    let session: AccountSession | undefined = undefined;
    try {
      const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, this.alias());
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      const values = await asset.query(query);
      const secret: asset.Value | undefined = values[0]?.get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        const restored = validateAccountSession(JSON.parse(new util.TextDecoder().decodeToString(secret)) as AccountSession);
        if (restored.accountId === workspace.accountId && restored.username === workspace.username) session = restored;
      }
    } catch {
      // 身份指针已校验并保持可读。令牌过期、屏幕锁定或 ASSET 暂不可用都不清空账号档案。
    }
    return { workspace, session };
  }

  async save(session: AccountSession): Promise<boolean> {
    validateAccountSession(session);
    const workspace: AccountWorkspace = { version: 1, accountId: session.accountId, username: session.username };
    let persisted = false;
    try {
      const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      attributes.set(asset.Tag.ALIAS, this.alias());
      attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(session)));
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
      attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(attributes);
      persisted = true;
    } catch { persisted = false; }
    const store = await preferences.getPreferences(this.context, { name: this.name });
    await store.put('workspace', JSON.stringify(workspace));
    await store.flush();
    return persisted;
  }

  async forget(): Promise<void> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, this.alias());
    try { await asset.remove(query); }
    catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) throw new Error('ACCOUNT_SESSION_CLEAR_FAILED');
    }
    const store = await preferences.getPreferences(this.context, { name: this.name });
    await store.delete('workspace');
    await store.flush();
  }
}
