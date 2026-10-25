import { HarmonyEffects } from '../platform/HarmonyEffects';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 筛选是回顾视图的临时状态，不写入手账信封。独立导航页承载全部标签，
// 避免与详情编辑器争用 bindSheet，也不在记忆首屏堆叠管理控件。
@Component
export struct MemoryFilterPage {
  @Prop sort: string = '最近';
  @Prop aiOnly: boolean = false;
  @Prop gallery: boolean = false;
  @Prop tag: string = '全部标签';
  @Prop tags: string[] = [];
  @Prop keyword: string = '';
  @Prop resultCount: number = 0;
  @Prop lightEnabled: boolean = true;
  @Prop reducedMotion: boolean = false;
  onSort: (value: string) => void = () => {};
  onAiOnly: (value: boolean) => void = () => {};
  onGallery: (value: boolean) => void = () => {};
  onTag: (value: string) => void = () => {};
  onReset: () => void = () => {};
  onDone: () => void = () => {};

  @Builder
  section(title: string) {
    Text(title).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
      .width('100%').margin({ top: 12, bottom: 4 })
  }

  @Builder
  chip(label: string, selected: boolean, controlId: string, action: () => void) {
    Button(label, { type: ButtonType.Normal }).height(40).fontSize(F.small)
      .padding({ left: 15, right: 15 }).margin({ right: 8, bottom: 8 }).borderRadius(12)
      .backgroundColor(selected ? T.accentSoft : T.soft).fontColor(selected ? T.accent : T.muted)
      .accessibilityText(`${label}${selected ? '，已选择' : ''}`).id(controlId).onClick(action)
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            Text('找到想再读的一页').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text(this.keyword ? `搜索“${this.keyword}”的结果` : '按自己的节奏，回看留下的观察。')
              .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
            this.section('内容')
            Row({ space: 12 }) {
              Checkbox({ name: 'ai-memory' }).select(this.aiOnly).selectedColor(T.mintInk)
                .width(22).height(22).id('memory-ai-filter').onChange(this.onAiOnly)
              Column({ space: 5 }) {
                Text('AI 辅助手账').fontSize(F.small).fontColor(T.ink).width('100%')
                Text('只看保存过 AI 问题与资料依据的记录').fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').padding(14).backgroundColor(this.aiOnly ? T.mint : T.surface).borderRadius(15)
            this.section('排列顺序')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(['最近', '最早', '按档案'], (label: string, index: number) => {
                this.chip(label, this.sort === label, `memory-sort-${index}`, () => this.onSort(label))
              }, (label: string) => `${label}-${this.sort === label}`)
            }.width('100%')
            this.section('标签')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(['全部'].concat(this.tags), (tag: string, index: number) => {
                this.chip(tag === '全部' ? tag : `#${tag}`,
                  tag === '全部' ? this.tag === '全部标签' : this.tag === tag,
                  tag === '全部' ? 'memory-tag-all' : `memory-tag-${index - 1}`,
                  () => this.onTag(tag === '全部' || this.tag === tag ? '全部标签' : tag))
              }, (tag: string) => `${tag}-${tag === '全部' ? this.tag === '全部标签' : this.tag === tag}`)
            }.width('100%')
            if (this.tags.length === 0) {
              Text('给手账加上标签后，就能在这里按线索回看。').fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
            }
            this.section('浏览方式')
            Row() {
              // chip 的 selected 是 Builder 值参数。和排序 / 标签一样，把选中态放入 key，
              // 切换或重置时重建两项，确保颜色与无障碍说明跟随实际视图一起更新。
              ForEach(['列表', '画廊'], (label: string, index: number) => {
                this.chip(label, this.gallery === (index === 1), index === 0 ? 'memory-view-list' : 'memory-view-gallery',
                  () => this.onGallery(index === 1))
              }, (label: string) => `${label}-${this.gallery === (label === '画廊')}`)
            }.width('100%')
          }.width('100%').constraintSize({ maxWidth: 720 }).alignItems(HorizontalAlign.Start)
            .padding({ left: 20, right: 20, top: 20, bottom: 24 })
        }.width('100%').layoutWeight(1).align(Alignment.Top).id('memory-filter-scroll')
        Row({ space: 12 }) {
          Button('重置', { type: ButtonType.Normal }).height(46).width(88).fontSize(F.small)
            .backgroundColor(T.soft).fontColor(T.muted).borderRadius(12).id('memory-filter-reset').onClick(this.onReset)
          Button(`查看 ${this.resultCount} 篇手账`, { type: ButtonType.Normal }).height(46).layoutWeight(1).fontSize(F.small)
            .backgroundColor(T.accent).fontColor(T.onAccent).borderRadius(12).id('memory-filter-done').onClick(this.onDone)
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 20, right: 20, top: 12, bottom: 24 })
      }.width('100%').height('100%')
    }.title('筛选与视图', { systemMaterial: HarmonyEffects.material(this.lightEnabled, this.reducedMotion) })
      .backgroundColor(T.canvas).id('memory-filter-page')
  }
}
