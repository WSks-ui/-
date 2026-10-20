import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';

async function click(session: ArchiveUiSession, scroll: string, id: string): Promise<void> {
  await (await session.inScroll(scroll, ON.id(id))).click();
}

async function capture(name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/page-hierarchy-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/page-hierarchy-${name}.json`)).exitCode).assertEqual(0);
}

export default function pageHierarchyTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('PageHierarchyTest')) return;
  describe('PageHierarchyTest', () => {
    it('library_filters_memory_tabs_and_profile_navigation', 0, async () => {
      const session = new ArchiveUiSession('page_hierarchy');
      await session.run(async () => {
        await (await session.waitId('tab-1')).click();
        await session.waitId('memory-section-0');
        await capture('memory-empty');
        await click(session, 'archive-scroll', 'memory-section-1');
        await session.waitId('collection-filter');
        await click(session, 'archive-scroll', 'memory-browse-archives');
        expect(await (await session.inScroll('device-scroll', ON.id('library-result-count'))).getText()).assertEqual('20 处');
        await (await session.waitId('device-scroll')).scrollToTop(40000);
        await capture('library');
        await click(session, 'device-scroll', 'library-ai-filter');
        // 2026-10-19 起白名单含杜岭二号方鼎与大河村双连壶两处，筛选结果不再是单一对象。
        expect(await (await session.waitId('library-result-count')).getText()).assertEqual('2 处');
        await click(session, 'device-scroll', 'library-city');
        await (await session.wait(ON.text('洛阳').type('Option'))).click();
        expect(await (await session.waitId('library-result-count')).getText()).assertEqual('0 处');
        await capture('library-empty');
        await click(session, 'device-scroll', 'library-reset');
        expect(await (await session.waitId('library-result-count')).getText()).assertEqual('20 处');
        const search = ON.type('SearchField').within(ON.id('library-search'));
        await (await session.inScroll('device-scroll', search)).inputText('杜岭');
        await (await session.wait(ON.text('检索').type('Button'))).click();
        expect(await (await session.inScroll('device-scroll', ON.id('library-result-count'))).getText()).assertEqual('1 处');
        await click(session, 'device-scroll', 'library-ai-open');
        await click(session, 'detail-scroll', 'ai-panel-toggle');
        await session.inScroll('detail-scroll', ON.id('ai-locked'));
        await capture('ai-guest');
        await session.driver.pressBack();
        await session.waitId('device-scroll');
        expect(await (await session.inScroll('device-scroll', ON.id('library-result-count'))).getText()).assertEqual('1 处');
        await (await session.waitId('profile-entry')).click();
        await session.waitId('profile-scroll');
        expect(!await session.driver.findComponent(ON.id('journey-panel'))).assertTrue();
        await capture('profile');
        await click(session, 'profile-scroll', 'profile-journeys');
        await session.waitId('journey-panel');
        await capture('journeys');
        await session.driver.pressBack();
        await click(session, 'profile-scroll', 'profile-preferences');
        const toggle = await session.waitId('light-enabled');
        const area = await toggle.getBounds();
        await session.driver.swipe(Math.round(area.right - (area.bottom - area.top) / 2),
          Math.round((area.top + area.bottom) / 2), Math.round(area.left + (area.bottom - area.top) / 2),
          Math.round((area.top + area.bottom) / 2), 600);
        await session.wait(ON.id('light-enabled').checked(false));
        expect((await session.read()).lightEnabled).assertFalse();
        await capture('preferences');
        await session.driver.pressBack();
        await click(session, 'profile-scroll', 'profile-account');
        await session.waitId('account-panel');
        expect(await (await session.waitId('connected-devices-value')).getText()).assertEqual('暂无同步记录');
        await session.driver.pressBack();
        await click(session, 'profile-scroll', 'profile-info-top');
        await session.inScroll('profile-scroll', ON.id('archive-info-sheet'));
        await capture('about');
        await session.driver.pressBack();
        await click(session, 'profile-scroll', 'profile-ai-memories');
        await session.waitId('archive-scroll');
        expect(await (await session.waitId('memory-ai-filter')).isChecked()).assertTrue();
        await session.waitText('还没有 AI 辅助手账');
      });
    });

    it('memory_fulltext_edit_replay_search_and_tombstone', 0, async () => {
      const session = new ArchiveUiSession('memory_detail');
      await session.run(async () => {
        await (await session.waitId('tab-2')).click();
        await click(session, 'device-scroll', 'library-ai-open');
        await (await session.waitId('detail-scroll')).scrollToTop(40000);
        await click(session, 'detail-scroll', 'engine-remember-view');
        const body = '我沿着方鼎的四面正中与四个折角观察，记下八组纹饰的位置。'.repeat(5);
        await (await session.inScroll('note-editor-scroll', ON.id('note-body'))).inputText(body);
        // 编辑器的保存按钮固定在底部；直接保存同时覆盖键盘仍显示的真实操作路径。
        // 此处按系统返回键可能先触发 Sheet 的放弃修改弹窗，令随后按钮点击被弹窗截获。
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const saved = activeRecords((await session.read()).records, 'note')[0];
        expect(saved.body).assertEqual(body);
        expect(saved.snapshot3DPose !== undefined).assertTrue();
        await session.driver.pressBack();
        await (await session.waitId('tab-1')).click();
        await click(session, 'archive-scroll', `memory-open-${saved.id}`);
        expect(await (await session.inScroll('memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(body);
        await capture('memory-read');
        await click(session, 'memory-detail-scroll', 'memory-detail-edit');
        const revisedBody = '我注意到了转角处的纹饰，准备继续追问。';
        await session.replaceLongBody(revisedBody);
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        await session.driver.pressBack();
        await session.waitId('memory-detail-page');
        const edited = activeRecords((await session.read()).records, 'note')[0];
        expect(edited.id).assertEqual(saved.id);
        expect(edited.body).assertEqual(revisedBody);
        expect(JSON.stringify(edited.snapshot3DPose)).assertEqual(JSON.stringify(saved.snapshot3DPose));
        expect(await (await session.inScroll('memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(edited.body);
        await click(session, 'memory-detail-scroll', 'memory-detail-replay');
        await session.waitText('已回到手账视角');
        await capture('memory-replay');
        await session.driver.pressBack();
        await session.driver.pressBack();
        await (await session.waitId('archive-scroll')).scrollToTop(40000);
        const search = ON.type('SearchField').within(ON.id('memory-search'));
        await (await session.inScroll('archive-scroll', search)).inputText('不存在的记忆');
        await (await session.wait(ON.text('查找').type('Button'))).click();
        await session.waitText('没有找到这段记忆');
        await click(session, 'archive-scroll', 'memory-empty-action');
        await capture('memory-list');
        await click(session, 'archive-scroll', `memory-open-${saved.id}`);
        await click(session, 'memory-detail-scroll', 'memory-detail-delete');
        await (await session.waitText('删除')).click();
        await session.waitId('archive-scroll');
        const tombstone = (await session.read()).records.find(item => item.id === saved.id);
        expect(tombstone?.deleted).assertTrue();
        expect(JSON.stringify(tombstone?.snapshot3DPose)).assertEqual(JSON.stringify(saved.snapshot3DPose));
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
      });
    });

    it('real_ai_focus_save_and_resume_from_memory', 0, async () => {
      const session = new ArchiveUiSession('page_ai', '', false);
      const username = `page_${Date.now()}`;
      const password = util.generateRandomUUID(true);
      let identity = '';
      try {
        await session.run(async () => {
          await (await session.waitId('account-mode-register')).click();
          await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(username);
          await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(password);
          await session.driver.pressBack();
          await click(session, 'login-scroll', 'account-submit');
          await session.waitId('explore-scroll');
          const client = new AccountSyncClient(session.context);
          expect(await client.configure()).assertTrue();
          identity = (await client.authenticate(username, password, false)).accountId;
          await client.logout();
          await (await session.waitId('tab-2')).click();
          await click(session, 'device-scroll', 'library-ai-open');
          await click(session, 'detail-scroll', 'ai-starter-1');
          const answer = await session.driver.waitForComponent(ON.id('ai-answer'), 35000);
          expect(answer !== undefined).assertTrue();
          await (await session.inScroll('detail-scroll', ON.text('看四个折角'))).click();
          await session.waitId('ai-focus-visible');
          const canvas = await (await session.waitId('engine-native-relic_inspector')).getBounds();
          const scroll = await (await session.waitId('detail-scroll')).getBounds();
          expect(canvas.top >= scroll.top && canvas.bottom <= scroll.bottom).assertTrue();
          await capture('ai-focus');
          await click(session, 'detail-scroll', 'ai-continue');
          await session.inScroll('detail-scroll', ON.id('ai-question-input'));
          // 等待面板滚动与延迟聚焦结束，再转去输入个人观察，避免焦点竞争。
          await session.driver.delayMs(650);
          await (await session.inScroll('detail-scroll', ON.id('ai-observation-input')))
            .inputText('我先看正面，再转到折角，才理解八组的位置。');
          await click(session, 'detail-scroll', 'ai-draft-request');
          expect(await session.driver.waitForComponent(ON.id('ai-draft-adopt'), 35000) !== undefined).assertTrue();
          await click(session, 'detail-scroll', 'ai-draft-adopt');
          await session.waitId('note-editor-scroll');
          await (await session.waitId('save-note')).click();
          await session.editorClosed();
          const store = accountStoreName(identity, session.name);
          await preferences.removePreferencesFromCache(session.context, store);
          const note = activeRecords((await new LocalArchiveRepository(session.context, store).load()).records, 'note')[0];
          expect(note.aiAssist !== undefined).assertTrue();
          expect(note.snapshot3DPose?.hotspotId).assertEqual('corners');
          await session.driver.pressBack();
          await (await session.waitId('tab-1')).click();
          await click(session, 'archive-scroll', 'memory-ai-filter');
          await capture('ai-memory');
          await click(session, 'archive-scroll', `memory-open-${note.id}`);
          await click(session, 'memory-detail-scroll', 'memory-detail-evidence');
          await session.waitId('memory-detail-question');
          await capture('ai-saved-evidence');
          await click(session, 'memory-detail-scroll', 'memory-detail-ai');
          expect(await (await session.inScroll('detail-scroll', ON.id('ai-question-input'))).getText()).assertEqual(note.aiAssist!.question);
          expect(await (await session.inScroll('detail-scroll', ON.id('ai-observation-input'))).getText()).assertEqual(note.body.slice(0, 300));
          expect(!await session.driver.findComponent(ON.id('ai-answer'))).assertTrue();
          await capture('ai-resume');
        });
      } finally {
        if (identity) await preferences.deletePreferences(session.context, accountStoreName(identity, session.name));
      }
    });

    it('twin_vessel_ai_entry_uses_its_own_starters', 0, async () => {
      // 只验证入口、对象化起始问题与热点归属，不请求真实模型：
      // 双连壶必须用“壶口 / 通口 / 黑彩”，不能沿用方鼎的“八组”问法。
      const session = new ArchiveUiSession('twin_ai_entry', '', false);
      const username = `twin_${Date.now()}`;
      const password = util.generateRandomUUID(true);
      let identity = '';
      try {
        await session.run(async () => {
          await (await session.waitId('account-mode-register')).click();
          await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(username);
          await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(password);
          await session.driver.pressBack();
          await click(session, 'login-scroll', 'account-submit');
          await session.waitId('explore-scroll');
          const client = new AccountSyncClient(session.context);
          expect(await client.configure()).assertTrue();
          identity = (await client.authenticate(username, password, false)).accountId;
          await client.logout();
          await (await session.waitId('tab-2')).click();
          const search = ON.type('SearchField').within(ON.id('library-search'));
          await (await session.inScroll('device-scroll', search)).inputText('双连壶');
          await (await session.wait(ON.text('检索').type('Button'))).click();
          expect(await (await session.inScroll('device-scroll', ON.id('library-result-count'))).getText()).assertEqual('1 处');
          await click(session, 'device-scroll', 'site-row-zz-dahecun');
          // 面板位于详情首屏下方，先确认详情已打开，再由 click 帮助器滚动到面板开关。
          await session.waitId('detail-scroll');
          await click(session, 'detail-scroll', 'ai-panel-toggle');
          // 起始问题是“序号 + 文本 + 箭头”的复合按钮，Button.text 不承载问题文本；
          // 读取按钮内的文本节点，仍然逐字核对对象化问法。
          expect(await (await session.inScroll('detail-scroll', ON.id('ai-starter-text-0'))).getText())
            .assertEqual('两只壶各有自己的口，为什么还算一件器物？');
          expect(await (await session.inScroll('detail-scroll', ON.id('ai-starter-text-2'))).getText())
            .assertEqual('红衣上的黑彩有哪几种线条？');
          expect(!await session.driver.findComponent(ON.id('ai-starter-3'))).assertTrue();
          await capture('twin-ai-entry');
        });
      } finally {
        if (identity) await preferences.deletePreferences(session.context, accountStoreName(identity, session.name));
      }
    });
  });
}
