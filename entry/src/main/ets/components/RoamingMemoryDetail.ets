import { ArchiveRecord, ArchiveSnapshot, activeRecords, copySnapshot, nextTimestamp } from '../domain/ArchiveDomain';
import { ROAM_CHAPTERS } from '../data/RoamingCatalog';
import { RoamSource } from '../domain/Roaming';
import { RoamingScene } from './RoamingScene';
import { RoamingTheme as R } from './RoamingTheme';

// 漫游片段和旧器物 pose 分别恢复。这里只读取冻结上下文，不拿当前篇章的正文
// 覆盖用户当时的摘录；编辑、删除仍经过主页面的同一个落盘事务。
//
// 2026-10-23 设计样板：全文页与写作页共用“笺纸”语言——暖纸底、朱砂细线、
// 正文大字距宽行距、摘录作为引用块单独标识出处。只改呈现，不改读取与提交路径。
@Component
export struct RoamingMemoryDetail {
  @Link @Watch('refreshNote') snapshot: ArchiveSnapshot;
  @Prop @Watch('selectedNoteChanged') noteId: string = '';
  @Prop saving: boolean = false;
  @Prop startEditing: boolean = false;
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onResolve: (noteId: string) => ArchiveRecord | undefined = () => undefined;
  onSnapshot: () => ArchiveSnapshot = () => this.snapshot;
  onOpenChapter: (chapterId: string, clueId: string) => void = () => {};
  onShare: (note: ArchiveRecord) => void = () => {};
  onBack: () => void = () => {};
  @State private editing: boolean = false;
  @State private body: string = '';
  @State private tags: string = '';
  @State private message: string = '';
  @State private visibleNote: ArchiveRecord | undefined = undefined;
  private noteResolved: boolean = false;

  aboutToAppear(): void {
    this.refreshNote();
    this.editing = this.startEditing;
    this.beginDraft();
  }

  private selectedNoteChanged(): void {
    // 平板详情容器可能复用组件；切换记录必须同时更新正文草稿和编辑状态。
    // 同一记录的远端更新不触发此方法，不覆盖正在输入的个人文字。
    this.editing = this.startEditing;
    this.refreshNote();
    this.beginDraft();
  }

  private refreshNote(): void {
    // Navigation 可能保留详情子树；每次按稳定ID向主页面取已落盘的新版本，
    // 只刷新阅读记录，不重置正在输入的正文和标签。
    this.visibleNote = this.onResolve(this.noteId);
    this.noteResolved = true;
  }

  private note(): ArchiveRecord | undefined {
    return this.noteResolved ? this.visibleNote :
      activeRecords(this.snapshot.records, 'note').find(item => item.id === this.noteId);
  }

  private items(): ArchiveRecord[] {
    const item = this.note();
    return item ? [item] : [];
  }

  private beginDraft(): void {
    const note = this.note();
    this.body = note?.body || '';
    this.tags = note?.tags.join('，') || '';
    this.message = '';
  }

  private scene(note: ArchiveRecord): string {
    const context = note.roamingContext;
    if (!context || context.sceneRevision !== 1) return '';
    const chapter = ROAM_CHAPTERS.find(item => item.id === context.chapterId);
    const clue = chapter?.clues.find(item => item.id === context.clueId);
    if (!clue || !clue.options.some(item => item.id === context.choiceId)) return '';
    return chapter?.scene || '';
  }

  private stage(note: ArchiveRecord): number {
    const chapter = ROAM_CHAPTERS.find(item => item.id === note.roamingContext?.chapterId);
    return Math.max(0, chapter?.clues.findIndex(item => item.id === note.roamingContext?.clueId) || 0);
  }

  private choice(note: ArchiveRecord): number {
    const chapter = ROAM_CHAPTERS.find(item => item.id === note.roamingContext?.chapterId);
    return chapter?.clues.find(item => item.id === note.roamingContext?.clueId)?.options
      .findIndex(item => item.id === note.roamingContext?.choiceId) ?? -1;
  }

  private dateText(note: ArchiveRecord): string {
    const date = new Date(note.updatedAt);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${date.getFullYear()}.${pad(date.getMonth() + 1)}.${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private async save(): Promise<void> {
    if (this.saving || !this.body.trim()) { this.message = '先写一句自己想留下的话。'; return; }
    // 草稿只替换本页正文和标签；其他端收到的新进度/其他手账从主页面当前快照继承。
    const next = copySnapshot(this.onSnapshot());
    const record = next.records.find(item => item.id === this.noteId && !item.deleted);
    if (!record) { this.message = '这页记忆已被删除，草稿仍在这里。'; return; }
    record.body = this.body.trim().slice(0, 4000);
    record.tags = this.tags.split(/[，,、\n]/).map(tag => tag.trim()).filter(tag => tag.length > 0)
      .filter((tag, index, array) => array.indexOf(tag) === index).slice(0, 20).map(tag => tag.slice(0, 40));
    record.updatedAt = nextTimestamp(next.records, Date.now());
    record.deviceId = next.deviceId;
    if (await this.onCommit(next)) { this.refreshNote(); this.editing = false; this.message = '这一页已保存。'; }
  }

  private remove(): void {
    this.getUIContext().showAlertDialog({ title: '删除这页记忆？', message: '删除会随账号同步，其他记忆继续保留。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteConfirmed(); } } });
  }

  private async deleteConfirmed(): Promise<void> {
    const next = copySnapshot(this.onSnapshot());
    const record = next.records.find(item => item.id === this.noteId && !item.deleted);
    if (!record) return;
    record.deleted = true;
    record.updatedAt = nextTimestamp(next.records, Date.now());
    record.deviceId = next.deviceId;
    if (await this.onCommit(next)) this.onBack();
  }

  @Builder
  sealMark(text: string) {
    // 三字竖排：字宽与行高都要给够，否则会折行或被裁掉
    Text(text).fontSize(12).fontColor(R.cinnabar).letterSpacing(0).lineHeight(12)
      .width(26).height(42).textAlign(TextAlign.Center)
      .border({ width: 1, color: 'rgba(166,76,55,0.55)', radius: 2 }).borderRadius(2)
      .rotate({ angle: -6 }).opacity(0.85)
  }

  @Builder
  notePage(note: ArchiveRecord) {
    Column({ space: 0 }) {
      // 笺头：城市与落笔时间分列两侧，标题独占一行
      Row({ space: 8 }) {
        Text(note.roamingContext?.city || '黄河记忆').fontSize(12).fontColor(R.cinnabar).letterSpacing(2)
        Blank()
        Text(this.dateText(note)).fontSize(12).fontColor(R.faint).letterSpacing(0.5)
      }.width('100%').padding({ left: 20, right: 20, top: 6 })
      Text(note.roamingContext?.title || '我的漫游记忆').fontSize(26).fontWeight(FontWeight.Medium)
        .fontColor(R.ink).letterSpacing(1).lineHeight(34).width('100%')
        .padding({ left: 20, right: 20, top: 8 }).id('roam-memory-title')
      Row().width('100%').height(1).backgroundColor(R.lineSoft).margin({ top: 14 })

      if (this.scene(note)) {
        RoamingScene({ scene: this.scene(note), stage: this.stage(note), amount: 100,
          choice: this.choice(note), found: ['kiln', 'home', 'dragon', 'tiger'],
          illuminated: this.stage(note) === 2, sceneHeight: 250, interactive: false })
        Row({ space: 7 }) {
          Row().width(3).height(3).backgroundColor(R.gold)
          Text('这次选中的文化片段 · 原创图景').fontSize(12).fontColor(R.muted).letterSpacing(0.5)
        }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 4 })
      } else {
        Text('这一版图景暂不能恢复，保存时的摘录、感想与出处仍然保留。')
          .fontSize(12).lineHeight(19).fontColor(R.muted).width('100%').padding({ left: 20, right: 20, top: 12 })
      }

      if (this.editing) {
        Column({ space: 10 }) {
          Text('我的这一页').fontSize(12).fontColor(R.cinnabar).letterSpacing(1.5).width('100%')
          TextArea({ text: this.body, placeholder: '为什么想留下这一段？' }).height(170).maxLength(4000)
            .fontSize(14).fontColor(R.ink).placeholderColor('#9AA089').backgroundColor('#FDF9EC')
            .border({ width: { left: 2, top: 1, right: 1, bottom: 1 }, color: { left: '#E0BEA6', top: '#E7DFC8',
              right: '#E7DFC8', bottom: '#E7DFC8' } })
            .borderRadius(2).padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .onChange(value => { this.body = value; }).id('roam-edit-body')
          TextInput({ text: this.tags, placeholder: '标签，用逗号分开' }).height(42)
            .fontSize(12).fontColor(R.ink).backgroundColor('#FDF9EC')
            .border({ width: 1, color: '#E7DFC8' }).borderRadius(2)
            .onChange(value => { this.tags = value; }).id('roam-edit-tags')
          Button(this.saving ? '正在保存' : '确认保存').width('100%').height(46)
            .fontColor('#FDF6E6').backgroundColor(R.cinnabar).borderRadius(3)
            .enabled(!this.saving).onClick(() => { this.save(); }).id('roam-edit-save')
          Button('取消编辑').height(36).backgroundColor(Color.Transparent).fontColor(R.muted)
            .fontSize(12).onClick(() => { this.editing = false; this.beginDraft(); })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 16 })
      } else {
        // 正文：用户自己的话是这一页的主体，行距与字距都比资料段更松
        Text(note.body).fontSize(17).lineHeight(32).letterSpacing(0.6).fontColor(R.ink)
          .width('100%').copyOption(CopyOptions.LocalDevice)
          .padding({ left: 20, right: 20, top: 16 }).id('roam-memory-body')
        if (note.tags.length > 0) {
          Row({ space: 8 }) {
            ForEach(note.tags, (tag: string) => {
              Text(`#${tag}`).fontSize(12).fontColor(R.river).letterSpacing(0.5)
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .backgroundColor('#E8EBD9').borderRadius(2)
            }, (tag: string) => tag)
          }.width('100%').padding({ left: 20, right: 20, top: 12 })
        }
        Row({ space: 0 }) {
          Blank()
          this.sealMark('云河纪')
        }.width('100%').padding({ left: 20, right: 20, top: 14 })
        Row({ space: 10 }) {
          Button('编辑这一页', { type: ButtonType.Normal }).layoutWeight(1).height(42).fontSize(12)
            .fontColor(R.river).backgroundColor('#E8EBD9').borderRadius(3)
            .onClick(() => { this.beginDraft(); this.editing = true; }).id('roam-memory-edit')
          Button('分享纪行', { type: ButtonType.Normal }).layoutWeight(1).height(42).fontSize(12)
            .fontColor(R.cinnabar).backgroundColor('#F3E4D3').borderRadius(3)
            .onClick(() => this.onShare(note)).id('roam-memory-share')
        }.width('100%').padding({ left: 20, right: 20, top: 14 })
      }

      // 摘录：与正文分开，标明这是当时留下的文化依据。
      // 左右留白由外层 Row 提供；在 100% 宽度上再叠左右 margin 会向右溢出。
      Column() {
      Column({ space: 8 }) {
        Row({ space: 7 }) {
          Row().width(3).height(3).backgroundColor(R.cinnabar)
          Text('当时留下的文化摘录').fontSize(12).fontColor(R.cinnabar).letterSpacing(1).layoutWeight(1)
        }.width('100%')
        Text(note.roamingContext?.excerpt || note.quotedPoemOrFact || '').fontSize(14).lineHeight(25)
          .fontColor(R.inkSoft).width('100%').copyOption(CopyOptions.LocalDevice).id('roam-memory-excerpt')
        ForEach(note.roamingContext?.sources || [], (source: RoamSource) => {
          Column({ space: 2 }) {
            Text(source.title).fontSize(12).fontColor(R.muted).lineHeight(16).width('100%')
            Text(source.url).fontSize(12).fontColor(R.faint).lineHeight(15).width('100%')
              .copyOption(CopyOptions.LocalDevice).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').alignItems(HorizontalAlign.Start)
        }, (source: RoamSource) => source.id)
        Text('文化内容：初稿待校审').fontSize(12).fontColor(R.faint).width('100%').letterSpacing(0.5)
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#F2ECD9').border({ width: { left: 2 }, color: '#D9C49F' })
      }.width('100%').padding({ left: 20, right: 20, top: 18 })

      Column() {
      Button('回到这一段漫游', { type: ButtonType.Normal }).width('100%').height(46).fontSize(12)
        .fontColor('#FDF6E6').backgroundColor(R.river).borderRadius(3)
        .onClick(() => this.onOpenChapter(note.roamingContext?.chapterId || '', note.roamingContext?.clueId || ''))
        .id('roam-memory-revisit')
      Button('删除这一页', { type: ButtonType.Normal }).fontSize(12).fontColor(R.faint)
        .backgroundColor(Color.Transparent).enabled(!this.saving).height(34)
        .onClick(() => this.remove()).id('roam-memory-delete')
      }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 8 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 0 }) {
          ForEach(this.items(), (note: ArchiveRecord) => {
            this.notePage(note)
          }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
          if (this.items().length === 0) {
            Text('这页记忆暂不在当前档案中，其他记录仍然保留。').fontSize(14).fontColor(R.muted).padding(30)
          }
          if (this.message) { Text(this.message).fontSize(12).fontColor(R.cinnabar).width('100%').padding({ left: 20, right: 20, top: 10 }) }
        }.width('100%').constraintSize({ maxWidth: 900 }).padding({ bottom: 40 })
      }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off).id('roam-memory-scroll')
    }.title('我的黄河记忆').backgroundColor(R.paper).onShown(() => this.refreshNote())
      .onBackPressed(() => { if (!this.saving) this.onBack(); return true; })
  }
}
