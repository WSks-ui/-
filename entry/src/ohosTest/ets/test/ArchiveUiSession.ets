import { abilityDelegatorRegistry, Component, Driver, ON, On } from '@kit.TestKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { KeyCode } from '@kit.InputKit';
import { preferences } from '@kit.ArkData';
import { expect } from '@ohos/hypium';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { TestContext } from './TestContext';

// 与正式应用共用页面和真实存储，只通过 debug 专用启动参数选择独立库。
// 每次打开都确认页面完成初始化；只清理测试前缀，不能删除或覆盖正式档案。
export class ArchiveUiSession {
  readonly name: string;
  readonly driver: Driver = Driver.create();
  context: common.Context = TestContext.context;
  private ability: UIAbility | undefined = undefined;

  constructor(scenario: string, storeName: string = '') {
    this.name = storeName || `yunheji_test_ui_${Date.now()}_${scenario}`;
    if (!/^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(this.name)) throw new Error('INVALID_UI_TEST_STORE');
  }

  async start(): Promise<void> {
    try {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: 'com.chr.myapplication', abilityName: 'EntryAbility',
        parameters: { yunhejiTestStore: this.name }
      });
      // 首屏布局会随字体与窗口变化；用滚动容器确认加载完成，不假定搜索框一定在首屏内。
      await this.wait(ON.id('explore-scroll'));
      // 启动命令返回时窗口可能尚未就绪，必须等节点出现后才能查询顶层 Ability。
      this.ability = await delegator.getCurrentTopAbility();
      expect(this.ability.context.abilityInfo.name === 'EntryAbility').assertTrue();
      // 测试 feature 与 EntryAbility 的数据目录并不等价；回读和清理必须使用
      // 实际窗口所属的 Context，不能拿测试宿主或模块级 Context 另开一个同名库。
      this.context = this.ability.context;
      const store = await preferences.getPreferences(this.context, { name: this.name });
      expect(await store.has('snapshot')).assertTrue();
    } catch (error) { throw new Error(`UI_START_FAILED: ${(error as Error).message}`); }
  }

  async stop(): Promise<void> {
    try {
      if (this.ability) {
        await this.ability.context.terminateSelf();
        this.ability = undefined;
        await this.wait(ON.text('设备回归准备中'));
      }
    } catch (error) { throw new Error(`UI_STOP_FAILED: ${(error as Error).message}`); }
  }

  async read(): Promise<ArchiveSnapshot> {
    try {
      // 断言磁盘已确认的数据，不能只检查页面文字或仍在内存里的快照。
      await preferences.removePreferencesFromCache(this.context, this.name);
      return await new LocalArchiveRepository(this.context, this.name).load();
    } catch (error) { throw new Error(`UI_READ_FAILED: ${(error as Error).message}`); }
  }

  async dispose(): Promise<void> {
    try {
      await this.stop();
      await preferences.deletePreferences(this.context, this.name);
    } catch (error) { throw new Error(`UI_CLEANUP_FAILED: ${(error as Error).message}`); }
  }

  async wait(target: On, hint: string = ''): Promise<Component> {
    try {
      let component = await this.driver.waitForComponent(target, 10000);
      if (!component) throw new Error(`UI_COMPONENT_NOT_FOUND ${hint}`);
      // Navigation/Sheet 动画期间节点已进入可访问树，但坐标仍在移动。只有范围连续
      // 稳定且控件可用才交给点击/输入步骤，避免点击动画中的旧坐标而漏掉真实操作。
      let previousBounds = '';
      let stableSamples = 0;
      for (let attempt = 0; attempt < 30; attempt++) {
        const bounds = JSON.stringify(await component.getBounds());
        stableSamples = bounds === previousBounds && await component.isEnabled() ? stableSamples + 1 : 0;
        if (stableSamples >= 3) return component;
        previousBounds = bounds;
        await this.driver.delayMs(150);
        const current = await this.driver.findComponent(target);
        if (current) component = current;
        else stableSamples = 0;
      }
      throw new Error(`UI_COMPONENT_NOT_STABLE ${hint}`);
    } catch (error) { throw new Error(`UI_WAIT_FAILED: ${(error as Error).message}`); }
  }

  async waitId(id: string): Promise<Component> { return this.wait(ON.id(id), id); }
  async waitText(text: string): Promise<Component> { return this.wait(ON.text(text), text); }

  async inScroll(scrollId: string, target: On): Promise<Component> {
    try {
      const scroll = await this.waitId(scrollId);
      let offset = 80;
      let safeTop = 0;
      let safeBottom = 0;
      let swipeX = 0;
      if (scrollId === 'explore-scroll' || scrollId === 'archive-scroll' || scrollId === 'device-scroll') {
        const bounds = await scroll.getBounds();
        const top = await this.driver.findComponent(ON.id('top-navigation-content'));
        const dock = await this.driver.findComponent(ON.id('tab-0'));
        if (top && dock) {
          const titleBounds = await top.getBounds();
          const dockBounds = await dock.getBounds();
          // HDS 浮动栏覆盖内容，UiTest 的默认 80px 起点会落进标题胶囊或 Dock。
          // 按真实节点范围让滚动手势离开覆盖区；仍操作真实 Scroll，不改应用滚动状态。
          offset = Math.ceil(Math.max(80, titleBounds.bottom - bounds.top, bounds.bottom - dockBounds.top) + 24);
          safeTop = Math.max(bounds.top, titleBounds.bottom) + 24;
          safeBottom = Math.min(bounds.bottom, dockBounds.top) - 24;
          swipeX = Math.round((bounds.left + bounds.right) / 2);
        }
      }
      let component = await this.driver.findComponent(target);
      if (!component) component = await scroll.scrollSearch(target, true, offset);
      if (!component) throw new Error('UI_SCROLL_TARGET_NOT_FOUND');
      if (safeBottom > safeTop) {
        // UiTest 判定“可见”的节点仍可能只有一小截露在浮动栏下。Component.click 会点其
        // 可见 bounds 中心，实际却点到 Dock；必须先把点击中心滚进无遮挡的内容区。
        let exposed = false;
        for (let attempt = 0; attempt <= 8; attempt++) {
          // scrollSearch / swipe 返回时惯性滚动未必结束。每次都取稳定后的新节点，
          // 否则旧坐标会让上下整屏手势往返，最后一次已露出仍可能被误判为遮挡。
          const current = await this.driver.findComponent(target);
          if (!current) {
            const found = await scroll.scrollSearch(target, true, offset);
            if (!found) throw new Error('UI_SCROLL_TARGET_NOT_FOUND_AFTER_EXPOSURE');
          }
          component = await this.wait(target);
          const bounds = await component.getBounds();
          const centerY = (bounds.top + bounds.bottom) / 2;
          if (centerY >= safeTop && centerY <= safeBottom) { exposed = true; break; }
          if (attempt === 8) break;
          // 只移动到无遮挡区内侧 80px；每次最多移动可用高度的 45%，避免
          // 把刚露出的输入框/计数滚过另一侧。最后一次手势后仍须重新稳定并测量。
          const below = centerY > safeBottom;
          const distance = Math.min((safeBottom - safeTop) * 0.45,
            Math.max(120, below ? centerY - safeBottom + 80 : safeTop - centerY + 80));
          const startY = below ? safeBottom - 48 : safeTop + 48;
          const endY = below ? startY - distance : startY + distance;
          await this.driver.swipe(swipeX, Math.round(startY), swipeX, Math.round(endY), 1800);
        }
        if (!exposed) throw new Error('UI_SCROLL_TARGET_COVERED_BY_NATIVE_BAR');
      }
      return this.wait(target);
    } catch (error) { throw new Error(`UI_SCROLL_FAILED: ${(error as Error).message}`); }
  }

  async search(keyword: string, expectedCount: number): Promise<void> {
    try {
      await (await this.wait(ON.id('explore-scroll'))).scrollToTop(40000);
      // Search 外层不是输入字段；SDK 26 的实际可编辑节点为 SearchField。
      // 每次重新获取节点，输入后核对文字并提交，不假定软键盘何时出现。
      await (await this.inScroll('explore-scroll', ON.type('SearchField'))).inputText(keyword);
      expect(await (await this.wait(ON.type('SearchField'))).getText()).assertEqual(keyword);
      // 直接操作页面的原生检索按钮；软键盘 Enter 可能只提交输入法候选，
      // 不能据此假定已经结束 Search 编辑，也不能无条件 Back 退出应用。
      await (await this.wait(ON.text('检索').type('Button'), '原生检索按钮')).click();
      const count = await this.inScroll('explore-scroll', ON.id('search-result-count'));
      expect(await count.getText()).assertEqual(`${expectedCount} 处文化遗产`);
    } catch (error) { throw new Error(`UI_SEARCH_FAILED: ${(error as Error).message}`); }
  }

  async pasteInto(id: string, text: string): Promise<void> {
    try {
      await (await this.inScroll('note-editor-scroll', ON.id(id))).clearText();
      // 长文本场景曾在本机 libuitest 中 SIGABRT；使用 API 20 的追加粘贴接口分段
      // 操作真实输入框，避免一次传递大参数。移动端 Ctrl+V 不会可靠地执行粘贴，
      // 不能把快捷键返回成功当作输入成功；完整内容由最终落盘回读核对。
      for (let offset = 0; offset < text.length; offset += 150) {
        const input = await this.driver.findComponent(ON.id(id));
        if (!input) throw new Error(`UI_INPUT_NOT_FOUND ${id}`);
        await input.inputText(text.slice(offset, offset + 150), { paste: true, addition: true });
      }
    } catch (error) { throw new Error(`UI_PASTE_FAILED: ${(error as Error).message}`); }
  }

  async replaceLongBody(text: string): Promise<void> {
    try {
      const input = await this.waitId('note-body');
      await input.click();
      // 旧 inputText 会按字符逐个退格清空既有正文，4000 字会耗时数分钟。
      // 用真实键盘全选/删除，再明确核对计数归零；不能用延长超时掩盖低效清空。
      await this.driver.triggerCombineKeys(KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_A);
      await this.driver.triggerKey(KeyCode.KEYCODE_DEL);
      await this.waitText('0 / 4000');
      await (await this.waitId('note-body')).inputText(text, { paste: true, addition: true });
    } catch (error) { throw new Error(`UI_REPLACE_FAILED: ${(error as Error).message}`); }
  }

  async openYangshao(): Promise<void> {
    try {
      await this.search('仰韶', 1);
      await (await this.inScroll('explore-scroll', ON.id('site-row-smx-yangshao'))).click();
      await this.wait(ON.id('write-note'));
    } catch (error) { throw new Error(`UI_OPEN_FAILED: ${(error as Error).message}`); }
  }

  async select(id: string, value: string): Promise<void> {
    try {
      await (await this.wait(ON.id(id))).click();
      // SDK 26 的原生 Select 菜单节点是 Option；同一选项还包含同名 Text，
      // 只按文字或 Menu 范围查询会产生多个匹配，不能把城市索引行误当菜单项。
      await this.wait(ON.type('Menu'));
      let option = await this.driver.findComponent(ON.text(value).type('Option'));
      if (!option) {
        const menuScroll = await this.wait(ON.type('Scroll').within(ON.type('Menu')));
        option = await menuScroll.scrollSearch(ON.text(value).type('Option'));
      }
      if (!option) throw new Error(`UI_OPTION_NOT_FOUND ${id} -> ${value}`);
      await (await this.wait(ON.text(value).type('Option'), `${id} -> ${value}`)).click();
    } catch (error) { throw new Error(`UI_SELECT_FAILED: ${(error as Error).message}`); }
  }

  async editorClosed(): Promise<void> {
    try {
      for (let attempt = 0; attempt < 50; attempt++) {
        if (!await this.driver.findComponent(ON.id('save-note'))) return;
        await this.driver.delayMs(200);
      }
      throw new Error('UI_EDITOR_DID_NOT_CLOSE');
    } catch (error) { throw new Error(`UI_EDITOR_FAILED: ${(error as Error).message}`); }
  }

  async run(action: () => Promise<void>, preserveStore: boolean = false): Promise<void> {
    let actionFailed = false;
    try {
      await this.start();
      await action();
    } catch (error) {
      actionFailed = true;
      console.error(`UI_CASE_FAILED: ${(error as Error).message}`);
      try {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator();
        await delegator.executeShellCommand('uitest dumpLayout -p /data/local/tmp/yunheji-ui-failure.json -b com.chr.myapplication');
        await delegator.executeShellCommand('uitest screenCap -p /data/local/tmp/yunheji-ui-failure.png');
      } catch { console.error('UI failure diagnostics unavailable'); }
      throw new Error((error as Error).message);
    } finally {
      try {
        if (preserveStore) await this.stop();
        else await this.dispose();
      } catch (cleanupError) {
        // 设备窗口异常时退出清理可能再次失败，主断言必须保留原始定位信息。
        // 清理单独出错仍让场景失败，不能把残留测试库或缺失宿主窗口隐藏成通过。
        if (!actionFailed) throw new Error((cleanupError as Error).message);
        console.error(`UI_CLEANUP_AFTER_FAILURE: ${(cleanupError as Error).message}`);
      }
    }
  }
}
