import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { common, application } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveSnapshot, copySnapshot, emptySnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { AccountWorkspaceStore } from '../../../main/ets/data/AccountWorkspaceStore';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { DistributedArchiveChannel } from '../../../main/ets/sync/DistributedArchiveChannel';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

interface ResumeFixture { run: string; username: string; password: string; }
const SITE_ID: string = 'zz-duling-fangding';
const FIRST_BODY: string = '冷启动前保存：我在方鼎折角找到新的文化线索。';
const OFFLINE_BODY: string = '离线冷启动后补充：四面正中与四个折角共同组成观察线索。';

async function fixture(): Promise<ResumeFixture> {
  const moduleContext = await application.createModuleContext(TestContext.context, 'entry_test');
  return JSON.parse(new util.TextDecoder().decodeToString(await moduleContext.resourceManager
    .getRawFileContent('account-sync-test.json'))) as ResumeFixture;
}

async function readAccount(session: ArchiveUiSession): Promise<ArchiveSnapshot> {
  const restored = await new AccountWorkspaceStore(session.context, session.name).load();
  if (!restored) throw new Error('RESUME_WORKSPACE_MISSING');
  const name = accountStoreName(restored.workspace.accountId, session.name);
  await preferences.removePreferencesFromCache(session.context, name);
  return new LocalArchiveRepository(session.context, name).load();
}

async function signIn(session: ArchiveUiSession, value: ResumeFixture, register: boolean): Promise<void> {
  await (await session.waitId(register ? 'account-mode-register' : 'account-mode-login')).click();
  await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(value.username);
  await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(value.password);
  await session.driver.pressBack();
  await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
  await session.waitId('explore-scroll');
}

async function capture(name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/stage-foundation-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/stage-foundation-${name}.json`)).exitCode).assertEqual(0);
}

async function cleanup(session: ArchiveUiSession): Promise<void> {
  // 先结束真实窗口和在途写入，再由会话统一清理独立账号库、原生库和身份指针。
  await session.dispose();
}

export default function stageFoundationTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (requested.includes('NativeArchiveTest')) {
    describe('NativeArchiveTest', () => {
      it('trusted_device_inventory_after_real_permission', 0, async () => {
        const session = new ArchiveUiSession('native_trust');
        await session.run(async () => {
          const channel = new DistributedArchiveChannel(session.context as common.UIAbilityContext);
          expect(await channel.open('e'.repeat(32), session.name)).assertTrue();
          try {
            let decided = false;
            let allowed = false;
            // 使用真实系统授权弹窗，不通过 shell 注入权限或伪造可信列表。
            const request = channel.requestPermission().then((granted: boolean) => { allowed = granted; decided = true; });
            for (let attempt = 0; attempt < 60 && !decided; attempt++) {
              // API 26 权限弹窗的“允许”是 Text 节点，点击该节点才走系统真实授权。
              const allow = await session.driver.findComponent(ON.text('允许').type('Text'));
              if (allow && !decided) {
                try { await allow.click(); }
                catch (error) {
                  // 首次点击后弹窗会先销毁、授权 Promise 才返回；只忽略这段转换中
                  // 已失效的 Widget，其他 UI 错误仍失败，最终仍须确认系统实际授权。
                  if (!(error as Error).message.includes('NoCandidates')) throw new Error((error as Error).message);
                }
              }
              await session.driver.delayMs(200);
            }
            await request;
            expect(allowed).assertTrue();
            await channel.exchange(emptySnapshot('test_inventory'));
            const state = channel.status();
            expect(state.deviceCount >= 0).assertTrue();
            if (state.deviceCount === 0) {
              expect(state.phase).assertEqual('waiting');
              expect(state.lastSuccessfulSync).assertEqual(0);
            }
            console.info(`NATIVE_TRUST_RESULT:${JSON.stringify(state)}`);
          } finally { await channel.cleanupTestStore(); }
        });
      });
      it('real_kv_versions_reopen_merge_and_tombstone', 0, async () => {
        const session = new ArchiveUiSession('native_kv');
        await session.run(async () => {
          const channel = new DistributedArchiveChannel(session.context as common.UIAbilityContext);
          expect(await channel.open('d'.repeat(32), session.name)).assertTrue();
          try {
            const snapshot = emptySnapshot('device_a');
            snapshot.records = [{ id: 'note:kv-demo', kind: 'note', siteId: SITE_ID,
              body: FIRST_BODY, tags: ['分布式版本'], updatedAt: 100, deviceId: 'device_a', deleted: false }];
            expect((await channel.exchange(snapshot))[0].body).assertEqual(FIRST_BODY);
            await channel.close();
            expect(await channel.open('d'.repeat(32), session.name)).assertTrue();
            const loaded = await channel.exchange(emptySnapshot('device_a'));
            expect(loaded.length).assertEqual(1);
            expect(loaded[0].body).assertEqual(FIRST_BODY);
            const newer = copySnapshot(snapshot);
            newer.records[0].body = OFFLINE_BODY; newer.records[0].deviceId = 'device_b'; newer.records[0].updatedAt = 200;
            expect((await channel.exchange(newer))[0].body).assertEqual(OFFLINE_BODY);
            const deleted = copySnapshot(newer);
            deleted.records[0].deleted = true; deleted.records[0].updatedAt = 300;
            await channel.exchange(deleted);
            const merged = await channel.exchange(snapshot);
            expect(merged[0].deleted).assertTrue();
            // 未发现真实对端时不能生成平台成功时间；只记录状态和数量，不输出内容或设备标识。
            expect(channel.status().lastSuccessfulSync).assertEqual(0);
            console.info(`NATIVE_KV_RESULT:${JSON.stringify(channel.status())}`);
          } finally { await channel.cleanupTestStore(); }
        });
      });
    });
  }
  if (!requested.includes('AccountResumeTest')) return;
  describe('AccountResumeTest', () => {
    it('prepare_authenticated_memory', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('resume_a', `yunheji_test_ui_${value.run}_resume_a`, false);
      await session.run(async () => {
        await signIn(session, value, true);
        const restored = await new AccountWorkspaceStore(session.context, session.name).load();
        expect(restored?.session !== undefined).assertTrue();
        await (await session.waitId('tab-2')).click();
        await (await session.inScroll('device-scroll', ON.id('library-ai-open'))).click();
        await (await session.inScroll('detail-scroll', ON.id('write-note'))).click();
        await session.pasteInto('note-body', FIRST_BODY);
        await session.pasteInto('note-tags', '冷启动验证');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        expect(activeRecords((await readAccount(session)).records, 'note')[0].body).assertEqual(FIRST_BODY);
        await session.driver.pressBack();
        await session.waitId('native-dock');
        console.info('RESUME_PREPARED:ASSET_SESSION_AND_ACCOUNT_MEMORY_CONFIRMED');
      }, true);
    });

    it('cold_start_while_service_unavailable_edit_same_memory', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('resume_a', `yunheji_test_ui_${value.run}_resume_a`, false);
      try {
        await session.start(true);
        expect(!await session.driver.findComponent(ON.id('login-scroll'))).assertTrue();
        const original = activeRecords((await readAccount(session)).records, 'note')[0];
        expect(original.body).assertEqual(FIRST_BODY);
        const client = new AccountSyncClient(session.context);
        expect(await client.configure()).assertTrue();
        let unreachable = false;
        try { await client.authenticate(value.username, value.password, false); } catch { unreachable = true; }
        expect(unreachable).assertTrue();
        await (await session.waitId('tab-1')).click();
        await (await session.inScroll('archive-scroll', ON.id(`memory-open-${original.id}`))).click();
        await (await session.inScroll('memory-detail-scroll', ON.id('memory-detail-edit'))).click();
        const field = await session.inScroll('note-editor-scroll', ON.id('note-body'));
        await field.clearText(); await field.inputText(OFFLINE_BODY);
        await session.driver.pressBack();
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const edited = activeRecords((await readAccount(session)).records, 'note')[0];
        expect(edited.id).assertEqual(original.id);
        expect(edited.body).assertEqual(OFFLINE_BODY);
        expect(JSON.stringify(edited.snapshot3DPose)).assertEqual(JSON.stringify(original.snapshot3DPose));
        await session.driver.pressBack();
        await session.waitId('memory-detail-body');
        await capture('offline-memory');
        console.info('RESUME_OFFLINE_EDIT:DISK_CONFIRMED_SAME_RECORD');
      } finally { await session.stop(); }
    });

    it('cold_start_reconnect_without_login', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('resume_a', `yunheji_test_ui_${value.run}_resume_a`, false);
      try {
        await session.start(true);
        expect(!await session.driver.findComponent(ON.id('login-scroll'))).assertTrue();
        await (await session.waitId('profile-entry')).click();
        await (await session.inScroll('profile-scroll', ON.id('profile-account'))).click();
        await session.wait(ON.id('account-sync-state').text('已同步'), '恢复原会话后真实网络同步');
        // 把整张原生状态卡滚入画面，归档截图时只保留卡片，不包含账号资料。
        await (await session.waitId('profile-scroll')).scrollToBottom(40000);
        await session.waitId('native-sync-time');
        await capture('native-panel');
        console.info('RESUME_RECONNECTED:NO_LOGIN_FORM');
      } finally { await session.stop(); }
    });

    it('other_device_receives_offline_edit', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('resume_b', `yunheji_test_ui_${value.run}_resume_b`, false);
      try {
        await session.start();
        await signIn(session, value, false);
        // 首页出现只代表本机账号库已打开；等真实首轮拉取完成后再核对远端手账，
        // 避免把较慢网络下尚未到达的记录误判为数据丢失。
        await (await session.waitId('profile-entry')).click();
        await (await session.inScroll('profile-scroll', ON.id('profile-account'))).click();
        await session.wait(ON.id('account-sync-state').text('已同步'), 'B 端首轮交换落盘');
        await session.driver.pressBack(); await session.waitId('profile-page');
        await session.driver.pressBack(); await session.waitId('native-dock');
        const note = activeRecords((await readAccount(session)).records, 'note')[0];
        expect(note.body).assertEqual(OFFLINE_BODY);
        await (await session.waitId('tab-1')).click();
        await (await session.inScroll('archive-scroll', ON.id(`memory-open-${note.id}`))).click();
        expect(await (await session.waitId('memory-detail-body')).getText()).assertEqual(OFFLINE_BODY);
        await capture('other-device');
      } finally { await cleanup(session); }
    });

    it('cleanup_a_and_forget_session', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('resume_a', `yunheji_test_ui_${value.run}_resume_a`, false);
      await session.start(true);
      await cleanup(session);
      expect(await new AccountWorkspaceStore(session.context, session.name).load() === undefined).assertTrue();
    });
  });
}
