import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  await session.driver.delayMs(350);
  const result = await abilityDelegatorRegistry.getAbilityDelegator()
    .executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-profile-${name}.png`);
  if (result.exitCode !== 0) throw new Error('PROFILE_CAPTURE_FAILED');
}

async function checkSeparateEntry(session: ArchiveUiSession): Promise<void> {
  const profile = await (await session.waitId('profile-entry')).getBounds();
  const rightTab = await (await session.waitId('tab-2')).getBounds();
  const display = await session.driver.getDisplaySize();
  // 核对真实渲染坐标，独立入口必须在第三页签右侧留有间距，且没有第四个 TabContent。
  expect(profile.left > rightTab.right).assertTrue();
  expect(profile.right <= display.x && profile.bottom <= display.y).assertTrue();
  expect(profile.right > profile.left && profile.bottom > profile.top).assertTrue();
  const label = await (await session.waitId('profile-entry-label')).getBounds();
  expect(label.left >= profile.left && label.right <= profile.right && label.top >= profile.top && label.bottom <= profile.bottom).assertTrue();
  expect(!await session.driver.findComponent(ON.id('tab-3'))).assertTrue();
}

export default function profileLoginTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('ProfileLoginTest')) return;
  describe('ProfileLoginTest', () => {
    it('startup_login_optional_education_and_failed_auth_stays_at_gate', 0, async () => {
      const session = new ArchiveUiSession('login_gate', '', false);
      await session.run(async () => {
        expect(!await session.driver.findComponent(ON.id('native-dock'))).assertTrue();
        expect(!await session.driver.findComponent(ON.id('explore-scroll'))).assertTrue();
        expect(await (await session.waitId('account-username')).getText()).assertEqual('');
        expect(await (await session.waitId('account-password')).getText()).assertEqual('');
        await capture(session, 'login');
        await (await session.inScroll('login-scroll', ON.id('education-toggle'))).click();
        await session.inScroll('login-scroll', ON.id('education-student-number'));
        expect(await (await session.waitId('education-university')).getText()).assertEqual('');
        expect(await (await session.waitId('education-student-number')).getText()).assertEqual('');
        await capture(session, 'education');
        await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
        await session.inScroll('login-scroll', ON.id('account-message'));
        expect(!await session.driver.findComponent(ON.id('native-dock'))).assertTrue();
        await session.waitId('login-scroll');
      });
    });

    it('profile_outside_dock_archive_separation_and_settings_are_saved', 0, async () => {
      const session = new ArchiveUiSession('profile_layout');
      await session.run(async () => {
        await checkSeparateEntry(session);
        await capture(session, 'home');
        await (await session.waitId('tab-2')).click();
        await session.waitId('device-scroll');
        expect(!await session.driver.findComponent(ON.id('account-panel'))).assertTrue();
        expect(!await session.driver.findComponent(ON.id('light-enabled'))).assertTrue();
        await capture(session, 'archive');
        await (await session.waitId('profile-entry')).click();
        await session.waitId('profile-scroll');
        expect(await (await session.waitId('account-title')).getText()).assertEqual('本机探索者');
        expect(!await session.driver.findComponent(ON.id('account-username'))).assertTrue();
        await capture(session, 'mine');
        await session.inScroll('profile-scroll', ON.id('profile-education-hint'));
        expect(await (await session.waitId('profile-university')).getText()).assertEqual('暂未填写');
        const toggle = await session.inScroll('profile-scroll', ON.id('light-enabled'));
        expect(await toggle.isChecked()).assertTrue();
        const bounds = await toggle.getBounds();
        // 当前模拟器点按滑块偶尔不翻转；用原生 Switch 支持的真实拖动手势，
        // 再核对 checked 与磁盘，不能因手势调用返回成功就认为保存完成。
        const centerY = Math.round((bounds.top + bounds.bottom) / 2);
        await session.driver.swipe(Math.round(bounds.right - (bounds.bottom - bounds.top) / 2), centerY,
          Math.round(bounds.left + (bounds.bottom - bounds.top) / 2), centerY, 600);
        await session.wait(ON.id('light-enabled').checked(false), '个人页沉浸光感关闭');
        expect((await session.read()).lightEnabled).assertFalse();
        await capture(session, 'settings');
        await session.driver.pressBack();
        await session.waitId('device-scroll');
        await (await session.waitId('profile-entry')).click();
        await (await session.inScroll('profile-scroll', ON.id('profile-login'))).click();
        await session.waitId('login-scroll');
        expect(!await session.driver.findComponent(ON.id('native-dock'))).assertTrue();
      });
    });

    it('login_and_independent_entry_dark_and_large_text', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const originalScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('profile_appearance', '', false);
      try {
        app.setFontSizeScale(1);
        await session.run(async () => {
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await session.driver.delayMs(500);
          expect(session.context.resourceManager.getColorByNameSync('canvas') & 0xFFFFFF).assertEqual(0x211D20);
          await capture(session, 'login-dark');
          await session.enterOffline();
          await checkSeparateEntry(session);
          await capture(session, 'home-dark');
          await (await session.waitId('profile-entry')).click();
          await session.waitId('profile-scroll');
          await capture(session, 'mine-dark');
          app.setFontSizeScale(1.5);
          await session.stop(); await session.start();
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          await session.inScroll('login-scroll', ON.id('account-submit'));
          const button = await (await session.waitId('account-submit')).getBounds();
          const display = await session.driver.getDisplaySize();
          expect(button.left >= 0 && button.right <= display.x).assertTrue();
          await capture(session, 'login-large');
          await session.enterOffline();
          await checkSeparateEntry(session);
          await capture(session, 'home-large');
          await (await session.waitId('profile-entry')).click();
          await session.inScroll('profile-scroll', ON.id('profile-education-hint'));
          await capture(session, 'mine-large');
        });
      } finally {
        app.setFontSizeScale(originalScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });

    it('register_with_optional_education_logout_and_real_login', 0, async () => {
      const session = new ArchiveUiSession('profile_auth', '', false);
      const username = `profile_${Date.now()}`;
      const password = util.generateRandomUUID(true);
      let identity = '';
      try {
        await session.run(async () => {
          const guest = await session.read();
          await (await session.waitId('account-mode-register')).click();
          await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(username);
          await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(password);
          // 真实输入会展开键盘。先按返回收起，再滚到下方选填区，
          // 否则 UiTest 的默认手势起点落在密码框内，无法驱动外层 Scroll。
          await session.driver.pressBack();
          console.info('PROFILE_AUTH: 注册身份已输入，准备填写选填资料');
          await (await session.inScroll('login-scroll', ON.id('education-toggle'))).click();
          await (await session.inScroll('login-scroll', ON.id('education-university'))).inputText('示例大学');
          await (await session.inScroll('login-scroll', ON.id('education-student-number'))).inputText('EDU-DEMO-001');
          await session.driver.pressBack();
          console.info('PROFILE_AUTH: 选填资料已输入，准备真实注册');
          await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
          await session.waitId('explore-scroll');
          console.info('PROFILE_AUTH: 已注册并进入主页面');
          expect(!await session.driver.findComponent(ON.id('login-scroll'))).assertTrue();
          await (await session.waitId('featured-site')).click();
          await (await session.waitId('favorite-toggle')).click();
          await session.waitText('已收藏');
          await session.driver.pressBack();
          await (await session.waitId('profile-entry')).click();
          expect(await (await session.waitId('account-title')).getText()).assertEqual(username);
          await session.inScroll('profile-scroll', ON.id('profile-university'));
          expect(await (await session.waitId('profile-university')).getText()).assertEqual('示例大学');
          expect(await (await session.waitId('profile-student-number')).getText()).assertEqual('已填写 · 仅本次展示');
          const client = new AccountSyncClient(session.context);
          expect(await client.configure()).assertTrue();
          identity = (await client.authenticate(username, password, false)).accountId;
          await client.logout();
          const storeName = accountStoreName(identity, session.name);
          await preferences.removePreferencesFromCache(session.context, storeName);
          const saved = await new LocalArchiveRepository(session.context, storeName).load();
          expect(activeRecords(saved.records, 'favorite').length).assertEqual(1);
          expect(JSON.stringify(saved).includes('示例大学') || JSON.stringify(saved).includes('EDU-DEMO-001')).assertFalse();
          await (await session.inScroll('profile-scroll', ON.id('account-logout'))).click();
          await session.waitId('login-scroll');
          console.info('PROFILE_AUTH: 退出后已回到登录页');
          expect(!await session.driver.findComponent(ON.id('native-dock'))).assertTrue();
          expect(JSON.stringify((await session.read()).records)).assertEqual(JSON.stringify(guest.records));
          await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(username);
          await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText('wrong_password_for_test');
          await session.driver.pressBack();
          await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
          await session.inScroll('login-scroll', ON.id('account-message'));
          await session.waitText('账号或密码不正确。');
          console.info('PROFILE_AUTH: 服务已拒绝错误密码，仍在登录页');
          expect(!await session.driver.findComponent(ON.id('native-dock'))).assertTrue();
          await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(password);
          await session.driver.pressBack();
          await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
          await session.waitId('explore-scroll');
          await (await session.waitId('tab-1')).click();
          expect(await (await session.waitId('collection-count')).getText()).assertEqual('1');
          await (await session.waitId('profile-entry')).click();
          await session.inScroll('profile-scroll', ON.id('profile-university'));
          expect(await (await session.waitId('profile-university')).getText()).assertEqual('暂未填写');
          expect(await (await session.waitId('profile-student-number')).getText()).assertEqual('暂未填写');
        });
      } finally {
        // 只删本例的测试账号 Preferences，不枚举正式游客库或正式账号库。
        if (identity) await preferences.deletePreferences(session.context, accountStoreName(identity, session.name));
      }
    });
  });
}
