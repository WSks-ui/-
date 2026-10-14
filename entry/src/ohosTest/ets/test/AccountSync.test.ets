import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { application, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

interface AccountFixture { run: string; username: string; password: string; otherUsername: string; otherPassword: string; }

const INITIAL_BODY = '沿着城垣与道路，把今天的观察留给下一次旅途。';
const EDITED_BODY = '另一台设备上的新观察：城市空间与黄河记忆。';
const OFFLINE_BODY = '离线记录：恢复连接后，仍能在另一台设备读到。';

async function fixture(): Promise<AccountFixture> {
  // 同包的主模块与测试 feature 具有不同 rawfile 范围，显式从 entry_test 读取，
  // 凭证不能为了方便移进正式主包，也不能根据运行上下文默认资源碰巧可见。
  const testModule = await application.createModuleContext(TestContext.context, 'entry_test');
  return JSON.parse(new util.TextDecoder().decodeToString(await testModule.resourceManager
    .getRawFileContent('account-sync-test.json'))) as AccountFixture;
}

async function signIn(session: ArchiveUiSession, value: AccountFixture, register: boolean = false, other: boolean = false): Promise<string> {
  console.info('ACCOUNT_UI: 准备切换账号页');
  await (await session.waitId('tab-2')).click();
  // HDS 的页签 bounds 不反映 TabContent 的横向入场动画；先等切页，再定位输入区。
  await session.driver.delayMs(500);
  await session.waitId('device-scroll');
  console.info('ACCOUNT_UI: 账号页容器就绪');
  await (await session.inScroll('device-scroll', ON.id(register ? 'account-mode-register' : 'account-mode-login'))).click();
  console.info('ACCOUNT_UI: 登录方式已选择');
  await (await session.inScroll('device-scroll', ON.id('account-username'))).inputText(other ? value.otherUsername : value.username);
  await (await session.inScroll('device-scroll', ON.id('account-password'))).inputText(other ? value.otherPassword : value.password);
  await (await session.inScroll('device-scroll', ON.id('account-submit'))).click();
  console.info('ACCOUNT_UI: 已提交账号请求');
  await session.inScroll('device-scroll', ON.id('account-title'));
  await session.waitText(other ? value.otherUsername : value.username);
  await session.waitId('account-refresh');
  console.info('ACCOUNT_UI: 真实登录与同步完成');
  // 身份由真实账号 API 回读，不从测试注入。只为读取当前账号实际磁盘库取得 ID，
  // 页面注册 / 登录与记录写入仍完全经正式 UI 完成，测试令牌不输出到日志或截图。
  const client = new AccountSyncClient(session.context);
  expect(await client.configure()).assertTrue();
  const identity = await client.authenticate(other ? value.otherUsername : value.username,
    other ? value.otherPassword : value.password, false);
  await client.logout();
  return identity.accountId;
}

async function readAccount(session: ArchiveUiSession, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, session.name);
  await preferences.removePreferencesFromCache(session.context, name);
  return new LocalArchiveRepository(session.context, name).load();
}

async function waitBody(session: ArchiveUiSession, accountId: string, expected: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 45; attempt++) {
    const snapshot = await readAccount(session, accountId);
    if (activeRecords(snapshot.records, 'note').some(record => record.body === expected)) return snapshot;
    await session.driver.delayMs(500);
  }
  throw new Error('ACCOUNT_NOTE_NOT_RECEIVED');
}

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  await session.driver.delayMs(300);
  const result = await abilityDelegatorRegistry.getAbilityDelegator()
    .executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-account-${name}.png`);
  if (result.exitCode !== 0) throw new Error('ACCOUNT_CAPTURE_FAILED');
}

async function leaveAccount(session: ArchiveUiSession): Promise<void> {
  await session.driver.pressBack();
  await session.waitId('native-dock');
  await (await session.waitId('tab-2')).click();
  await (await session.inScroll('device-scroll', ON.id('account-logout'))).click();
  await session.waitId('account-submit');
}

export default function accountSyncTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (!requested.includes('AccountSyncTest')) return;
  describe('AccountSyncTest', () => {
    it('account_entry_dark_and_large_text_without_private_fields', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const originalScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('account_appearance');
      try {
        app.setFontSizeScale(1);
        await session.run(async () => {
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          await (await session.waitId('tab-2')).click();
          await session.driver.delayMs(500);
          await session.inScroll('device-scroll', ON.id('account-submit'));
          expect(await (await session.waitId('account-username')).getText()).assertEqual('');
          expect(await (await session.waitId('account-password')).getText()).assertEqual('');
          await capture(session, 'login');
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await session.driver.delayMs(500);
          expect(session.context.resourceManager.getColorByNameSync('canvas') & 0xFFFFFF).assertEqual(0x211D20);
          await capture(session, 'login-dark');
          app.setFontSizeScale(1.5);
          await session.stop();
          await session.start();
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          await (await session.waitId('tab-2')).click();
          await session.driver.delayMs(500);
          await session.inScroll('device-scroll', ON.id('account-submit'));
          const bounds = await (await session.waitId('account-submit')).getBounds();
          const display = await session.driver.getDisplaySize();
          expect(bounds.left >= 0 && bounds.right <= display.x).assertTrue();
          await capture(session, 'login-large');
        });
      } finally {
        app.setFontSizeScale(originalScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });

    it('device_a_register_publish_and_guest_isolation', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_a', `yunheji_test_ui_${value.run}_a`);
      await session.run(async () => {
        // 先通过原生详情写入游客浏览记录，账号登录后不能自动上传 / 混入它。
        await session.openYangshao();
        await session.driver.pressBack();
        const guest = await session.read();
        expect(activeRecords(guest.records, 'progress').length).assertEqual(1);
        const id = await signIn(session, value, true);
        expect((await readAccount(session, id)).records.length).assertEqual(0);
        await (await session.waitId('tab-0')).click();
        await session.openYangshao();
        await (await session.inScroll('detail-scroll', ON.id('favorite-toggle'))).click();
        await (await session.inScroll('detail-scroll', ON.id('write-note'))).click();
        await session.pasteInto('note-body', INITIAL_BODY);
        await session.pasteInto('note-tags', '黄河记忆，旅途观察');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const saved = await waitBody(session, id, INITIAL_BODY);
        expect(activeRecords(saved.records, 'favorite').length).assertEqual(1);
        expect(activeRecords(saved.records, 'note')[0].tags.length).assertEqual(2);
        await (await session.inScroll('detail-scroll', ON.text(INITIAL_BODY))).getText();
        await capture(session, 'device-a');
        await leaveAccount(session);
        expect(JSON.stringify((await session.read()).records)).assertEqual(JSON.stringify(guest.records));
      }, true);
    });

    it('device_b_receive_and_edit_from_real_ui', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_b', `yunheji_test_ui_${value.run}_b`);
      await session.run(async () => {
        const id = await signIn(session, value);
        const received = await waitBody(session, id, INITIAL_BODY);
        expect(activeRecords(received.records, 'favorite').length).assertEqual(1);
        expect(activeRecords(received.records, 'progress').length).assertEqual(1);
        await (await session.waitId('tab-1')).click();
        expect(await (await session.waitId('collection-count')).getText()).assertEqual('1');
        expect(await (await session.waitId('note-count')).getText()).assertEqual('1');
        await capture(session, 'device-b-memory');
        await (await session.inScroll('archive-scroll', ON.id('site-row-smx-yangshao'))).click();
        await session.inScroll('detail-scroll', ON.text(INITIAL_BODY));
        await capture(session, 'device-b');
        const note = activeRecords(received.records, 'note')[0];
        await (await session.inScroll('detail-scroll', ON.id(`edit-${note.id}`))).click();
        await session.pasteInto('note-body', EDITED_BODY);
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const saved = await waitBody(session, id, EDITED_BODY);
        expect(activeRecords(saved.records, 'note')[0].tags.join('，')).assertEqual('黄河记忆，旅途观察');
      }, true);
    });

    it('device_a_receive_edit_and_logout_preserves_guest', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_a_return', `yunheji_test_ui_${value.run}_a`);
      await session.run(async () => {
        const id = await signIn(session, value);
        const received = await waitBody(session, id, EDITED_BODY);
        await (await session.waitId('tab-1')).click();
        await (await session.inScroll('archive-scroll', ON.id('site-row-smx-yangshao'))).click();
        await session.inScroll('detail-scroll', ON.text(EDITED_BODY));
        await capture(session, 'device-a-updated');
        expect(activeRecords(received.records, 'note').length).assertEqual(1);
        await leaveAccount(session);
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        // 第二账号经真实 UI 注册，服务器和磁盘均为独立档案。
        const otherId = await signIn(session, value, true, true);
        expect(otherId === id).assertFalse();
        expect((await readAccount(session, otherId)).records.length).assertEqual(0);
      }, true);
    });

    it('device_b_offline_note_is_saved_locally', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_b_offline', `yunheji_test_ui_${value.run}_b`);
      await session.run(async () => {
        const id = await signIn(session, value);
        await (await session.waitId('tab-1')).click();
        await (await session.inScroll('archive-scroll', ON.id('site-row-smx-yangshao'))).click();
        // 主机脚本收到此标记后停止本任务账号服务，使已登录窗口无法交换记录；
        // 测试结束后恢复同一数据库和证书，不操作电脑桌面或用户的其他服务。
        console.info(`ACCOUNT_OFFLINE_READY:${value.run}`);
        await session.driver.delayMs(7000);
        const received = await readAccount(session, id);
        const note = activeRecords(received.records, 'note')[0];
        await (await session.inScroll('detail-scroll', ON.id(`edit-${note.id}`))).click();
        await session.pasteInto('note-body', OFFLINE_BODY);
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        await waitBody(session, id, OFFLINE_BODY);
        await capture(session, 'offline-note');
      }, true);
    });

    it('device_a_receive_reconnected_note_and_delete', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_a_delete', `yunheji_test_ui_${value.run}_a`);
      await session.run(async () => {
        const id = await signIn(session, value);
        const received = await waitBody(session, id, OFFLINE_BODY);
        await (await session.waitId('tab-1')).click();
        await (await session.inScroll('archive-scroll', ON.id('site-row-smx-yangshao'))).click();
        await session.inScroll('detail-scroll', ON.text(OFFLINE_BODY));
        await capture(session, 'reconnected');
        const note = activeRecords(received.records, 'note')[0];
        await (await session.inScroll('detail-scroll', ON.id(`delete-${note.id}`))).click();
        await (await session.waitText('删除')).click();
        for (let attempt = 0; attempt < 20; attempt++) {
          if (activeRecords((await readAccount(session, id)).records, 'note').length === 0) break;
          await session.driver.delayMs(300);
        }
        expect((await readAccount(session, id)).records.some(record => record.id === note.id && record.deleted)).assertTrue();
      }, true);
    });

    it('device_b_upload_pending_offline_note', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_b_reconnect', `yunheji_test_ui_${value.run}_b`);
      await session.run(async () => {
        const id = await signIn(session, value);
        const snapshot = await waitBody(session, id, OFFLINE_BODY);
        expect(activeRecords(snapshot.records, 'note')[0].body).assertEqual(OFFLINE_BODY);
        await session.waitText('上次同步已完成');
      }, true);
    });

    it('device_b_receive_tombstone_without_resurrection', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_b_tombstone', `yunheji_test_ui_${value.run}_b`);
      await session.run(async () => {
        const id = await signIn(session, value);
        for (let attempt = 0; attempt < 45; attempt++) {
          if (activeRecords((await readAccount(session, id)).records, 'note').length === 0) break;
          await session.driver.delayMs(500);
        }
        const snapshot = await readAccount(session, id);
        expect(activeRecords(snapshot.records, 'note').length).assertEqual(0);
        expect(snapshot.records.some(record => record.kind === 'note' && record.deleted)).assertTrue();
        await (await session.waitId('tab-1')).click();
        expect(await (await session.waitId('note-count')).getText()).assertEqual('0');
        await capture(session, 'deleted');
      }, true);
    });

    it('cleanup_only_this_run_test_preferences', 0, async () => {
      const value = await fixture();
      const session = new ArchiveUiSession('account_cleanup', `yunheji_test_ui_${value.run}_cleanup`);
      await session.run(async () => {
        const client = new AccountSyncClient(session.context);
        expect(await client.configure()).assertTrue();
        const main = await client.authenticate(value.username, value.password, false);
        await client.logout();
        const other = await client.authenticate(value.otherUsername, value.otherPassword, false);
        await client.logout();
        // 只删除本轮已知的独立 Preferences；不枚举或清理正式本机 / 账号库。
        for (const suffix of ['a', 'b']) {
          const testName = `yunheji_test_ui_${value.run}_${suffix}`;
          await preferences.deletePreferences(session.context, accountStoreName(main.accountId, testName));
          await preferences.deletePreferences(session.context, accountStoreName(other.accountId, testName));
          await preferences.deletePreferences(session.context, testName);
        }
      });
    });
  });
}
