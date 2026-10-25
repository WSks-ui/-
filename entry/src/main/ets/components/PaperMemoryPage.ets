import { activeRecords, ArchiveRecord, ArchiveSnapshot, copySnapshot, emptySnapshot, nextTimestamp } from '../domain/ArchiveDomain';
import { PaperJourneyScene } from './PaperJourneyScene';
import { PaperMemorySource } from '../domain/PaperMemory';
import { setPaperWindowText } from '../platform/PaperWindowStyle';

@Component
export struct PaperMemoryPage {
  @Prop noteId: string = '';
  @Prop @Watch('refreshNote') records: ArchiveRecord[] = [];
  @Prop saving: boolean = false;
  @Prop reducedMotion: boolean = false;
  onCurrentSnapshot: () => ArchiveSnapshot = () => emptySnapshot('');
  onCommit: (snapshot: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onContinue: (cityId: string) => void = () => {};
  onArchive: (siteId: string) => void = () => {};
  onShare: (note: ArchiveRecord) => void = () => {};
  onBack: () => void = () => {};
  @State private editing: boolean = false;
  @State private draft: string = '';
  @State private message: string = '';
  @State private containerWidth: number = 360;

  private note(): ArchiveRecord | undefined { return activeRecords(this.records, 'note').find(note => note.id === this.noteId); }
  private refreshNote(): void { if (!this.editing) this.draft = this.note()?.body || ''; }
  aboutToAppear(): void { this.refreshNote(); }

  private async save(): Promise<void> {
    const next = copySnapshot(this.onCurrentSnapshot());
    const note = next.records.find(item => item.id === this.noteId && !item.deleted);
    if (!note) return;
    note.body = this.draft.trim().slice(0, 4000);
    note.updatedAt = nextTimestamp(next.records, Date.now()); note.deviceId = next.deviceId;
    if (await this.onCommit(next)) { this.editing = false; this.message = '文字已保存，原剪口和出处保持在这一页。'; }
    else this.message = '还没有保存成功，文字仍留在这里。';
  }

  private remove(): void {
    this.getUIContext().showAlertDialog({ title: '删除这页纸景？', message: '删除会随同一账号同步。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteConfirmed(); } } });
  }

  private async deleteConfirmed(): Promise<void> {
    const next = copySnapshot(this.onCurrentSnapshot());
    const note = next.records.find(item => item.id === this.noteId && !item.deleted);
    if (!note) return;
    // 沿用墓碑，不删掉冻结作品，旧设备回传也不能让已删的一页复活。
    note.deleted = true; note.updatedAt = nextTimestamp(next.records, Date.now()); note.deviceId = next.deviceId;
    if (await this.onCommit(next)) this.onBack();
  }

  @Builder
  textContent(note: ArchiveRecord) {
    Column({ space: 16 }) {
      Text(note.paperContext?.title || '我的纸景').fontSize(27).fontWeight(FontWeight.Bold).fontColor('#203D43').width('100%')
      Text(new Date(note.updatedAt).toLocaleDateString()).fontSize(12).fontColor('#79888A').width('100%')
      if (note.paperContext?.excerpt) {
        Text(`「${note.paperContext.excerpt}」`).fontSize(15).lineHeight(26).fontColor('#628476').width('100%')
          .copyOption(CopyOptions.LocalDevice).id('paper-note-excerpt')
      }
      if (this.editing) {
        TextArea({ text: this.draft, placeholder: '写下自己的感受' }).height(140).maxLength(4000)
          .fontSize(16).fontColor('#234149').backgroundColor('#FFFCF4').borderRadius(14)
          .id('paper-edit-body').onChange((value: string) => { this.draft = value; })
        Button('保存文字', { type: ButtonType.Normal }).width('100%').height(46).fontColor('#FFF9E9')
          .backgroundColor('#2C5E59').borderRadius(13).enabled(!this.saving).id('paper-edit-save')
          .onClick(() => { this.save(); })
      } else if (note.body.trim()) {
        Text(note.body).fontSize(17).lineHeight(29).fontColor('#29454B').width('100%')
          .copyOption(CopyOptions.LocalDevice).id('paper-note-body')
      } else {
        Text('这一页只留下了作品，感想可以慢慢补上。').fontSize(14).fontColor('#7B8B87').width('100%')
      }
      Row({ space: 8 }) {
        Button(this.editing ? '取消编辑' : '补写这一页', { type: ButtonType.Normal }).height(38).layoutWeight(1)
          .fontSize(13).fontColor('#315B56').backgroundColor('#E2EAE0').borderRadius(11)
          .id('paper-note-edit').onClick(() => { this.draft = note.body; this.editing = !this.editing; })
        Button('分享', { type: ButtonType.Normal }).height(38).layoutWeight(1).fontSize(13)
          .fontColor('#315B56').backgroundColor('#E2EAE0').borderRadius(11).id('paper-note-share')
          .onClick(() => this.onShare(note))
        Button('删除', { type: ButtonType.Normal }).height(38).fontSize(13).fontColor('#A66D59')
          .backgroundColor(Color.Transparent).id('paper-note-delete').onClick(() => this.remove())
      }.width('100%')
      if (this.message) { Text(this.message).fontSize(12).fontColor('#6B817A').width('100%') }
      Divider().color('#D8DFD3')
      Text('这张纸背后的文化').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#29454B').width('100%')
      Text(note.paperContext?.culture || '').fontSize(13).fontColor('#71817C').lineHeight(22).width('100%')
      if (note.paperContext) {
        ForEach(note.paperContext.sources, (source: PaperMemorySource) => {
          Column({ space: 5 }) {
            Text(`${source.title} · ${source.era}`).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#365D59').width('100%')
            Text(source.quote).fontSize(13).lineHeight(22).fontColor('#6D7D77').width('100%')
            Text(`${source.url}\n保存时查阅日期：${source.accessedAt}`).fontSize(10).lineHeight(16).fontColor('#89938C')
              .width('100%').copyOption(CopyOptions.LocalDevice)
          }.width('100%').padding(14).backgroundColor('#FBF9F0').borderRadius(13)
        }, (source: PaperMemorySource) => source.id)
        Button('回到这座城，接着创作  →', { type: ButtonType.Normal }).width('100%').height(46)
          .fontColor('#FFF6DE').backgroundColor('#2B5755').borderRadius(13).id('paper-note-continue')
          .onClick(() => this.onContinue(note.paperContext!.cityId))
      }
      Button('阅读原文化档案', { type: ButtonType.Normal }).width('100%').height(40).fontSize(13)
        .fontColor('#647A72').backgroundColor(Color.Transparent).id('paper-note-archive')
        .onClick(() => this.onArchive(note.siteId))
    }.width('100%').alignItems(HorizontalAlign.Start).padding(22)
  }

  build() {
    NavDestination() {
      if (this.note()?.paperContext) {
        Scroll() {
          Column() {
            PaperJourneyScene({ work: this.note()!.paperContext!.work,
              cityId: this.note()!.paperContext!.cityId, interactive: false, unfolded: true,
              reducedMotion: this.reducedMotion, showGuide: false })
              .width('100%').height(this.containerWidth >= 900 ? 420 : 320).id('paper-note-preview')
            this.textContent(this.note()!)
          }.width('100%').constraintSize({ maxWidth: 1000 })
        }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off).id('paper-memory-page')
          .onAreaChange((_old: Area, area: Area) => { this.containerWidth = Number(area.width); })
      } else {
        Column({ space: 12 }) {
          Text('这页记忆暂不在这里').fontSize(18).fontColor('#36554F')
          Button('返回记忆').onClick(() => this.onBack())
        }.width('100%').padding(24)
      }
    }.title('我的纸景').backgroundColor('#F2F0E6')
      // 正文页沿用浅纸背景，不能继承夜色首页的浅色状态栏文字。
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .systemBarStyle({ statusBarContentColor: '#FF203D43' })
      .onShown(() => { setPaperWindowText(this.getUIContext(), '#203D43'); })
      .onHidden(() => { setPaperWindowText(this.getUIContext(), '#F4ECD9'); })
  }
}
