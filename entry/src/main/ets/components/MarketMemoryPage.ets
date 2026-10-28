import { activeRecords, ArchiveRecord, ArchiveSnapshot, copySnapshot, emptySnapshot, MAX_NOTE_LENGTH,
  MAX_NOTE_TAGS, MAX_NOTE_TAG_LENGTH, MAX_NOTE_TAGS_TEXT_LENGTH, nextTimestamp } from '../domain/ArchiveDomain';
import { MarketMemoryContext, MarketMemorySource, MarketMemoryStall } from '../domain/MarketMemory';
import { MARKET_CULTURE_BOUNDARY } from '../data/MarketCultureCatalog';
import { setPaperWindowText } from '../platform/PaperWindowStyle';

// 缩图和正文页共用这一只读画布，只读冻结layout，不向经营领域拼接一个假state。
// 保存页不播放客流或改变进度；未来sceneRevision变化时仍保留文字与出处供重读。
@Component
export struct MarketMemoryPreview {
  @Prop @Watch('paint') context: MarketMemoryContext | undefined = undefined;
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;
  private widthVp: number = 360;
  private heightVp: number = 210;

  private line(x: number, y: number, x2: number, y2: number, color: string, width: number = 1): void {
    const c = this.canvas; c.beginPath(); c.moveTo(x, y); c.lineTo(x2, y2); c.strokeStyle = color; c.lineWidth = width; c.stroke();
  }

  private paint(): void {
    if (!this.ready) return;
    const c = this.canvas; c.clearRect(0, 0, this.widthVp, this.heightVp);
    c.fillStyle = '#163238'; c.fillRect(0, 0, this.widthVp, this.heightVp);
    if (!this.context || this.context.sceneRevision !== 1) return;
    c.save(); c.scale(this.widthVp / 700, this.heightVp / 360);
    c.fillStyle = '#DCCB99'; c.beginPath(); c.arc(620, 43, 17, 0, Math.PI * 2); c.fill();
    c.fillStyle = '#163238'; c.beginPath(); c.arc(613, 37, 17, 0, Math.PI * 2); c.fill();
    for (let i = 0; i < 11; i++) {
      const x = 10 + i * 66; const y = 72 - i * 1.9;
      c.fillStyle = i % 2 ? '#36524A' : '#28483F'; c.fillRect(x, y, 58, 51);
      c.beginPath(); c.moveTo(x - 5, y + 4); c.lineTo(x + 29, y - 21); c.lineTo(x + 64, y + 4); c.closePath(); c.fill();
    }
    c.fillStyle = '#8A8B66'; c.beginPath(); c.moveTo(0, 140); c.lineTo(700, 93);
    c.lineTo(700, 292); c.lineTo(0, 340); c.closePath(); c.fill();
    c.fillStyle = '#B8A77B'; c.beginPath(); c.moveTo(0, 206); c.lineTo(700, 158);
    c.lineTo(700, 215); c.lineTo(0, 263); c.closePath(); c.fill();
    c.fillStyle = '#17454A'; c.beginPath(); c.moveTo(0, 312); c.lineTo(700, 264);
    c.lineTo(700, 360); c.lineTo(0, 360); c.closePath(); c.fill();
    this.line(0, 309, 700, 261, '#D2BC86', 5);
    for (let i = 0; i < 15; i++) this.line(i * 53, 335 + i % 3 * 7, i * 53 + 37, 332 + i % 3 * 7, '#3A6562', 2);
    this.context.layout.stalls.forEach((stall: MarketMemoryStall) => {
      const zone = Math.floor(stall.lotId / 2); const x = 92 + zone * 223 + (stall.lotId % 2) * 36;
      const y = (stall.lotId % 2 ? 275 : 170) - zone * 15;
      if (!stall.type) {
        c.strokeStyle = '#637860'; c.lineWidth = 2; c.strokeRect(x - 38, y - 24, 76, 24); return;
      }
      c.fillStyle = '#756C4D'; c.fillRect(x - 39, y - 52, 78, 55);
      c.fillStyle = stall.type === 'rice' ? '#D6BF89' : stall.type === 'meat' ? '#BB795B' :
        stall.type === 'tea' ? '#6C9B83' : '#D3AB5C';
      c.beginPath(); c.moveTo(x - 48, y - 52); c.lineTo(x - 34, y - 76); c.lineTo(x + 34, y - 76);
      c.lineTo(x + 49, y - 52); c.closePath(); c.fill();
      c.fillStyle = '#DFC58E'; c.fillRect(x - 30, y - 25, 60, 10);
      for (let worker = 0; worker < stall.workers; worker++) {
        const wx = x - 25 + worker * 12;
        c.fillStyle = '#D6BA86'; c.beginPath(); c.arc(wx, y - 10, 3.7, 0, Math.PI * 2); c.fill();
        c.fillStyle = '#486E61'; c.fillRect(wx - 3, y - 6, 6, 11);
      }
      if (stall.type === 'lantern') {
        for (let i = 0; i < 3; i++) {
          c.fillStyle = '#F0C176'; c.beginPath(); c.ellipse(x - 25 + i * 25, y - 46, 7, 10, 0, 0, Math.PI * 2); c.fill();
        }
      }
    });
    this.context.layout.lamps.forEach((lit: boolean, zone: number) => {
      const x = 181 + zone * 223; const y = 163 - zone * 15;
      this.line(x, y - 46, x, y + 32, '#6E7558', 3);
      c.fillStyle = lit ? '#F1C879' : '#7D704E'; c.beginPath(); c.ellipse(x, y - 35, 8, 12, 0, 0, Math.PI * 2); c.fill();
    });
    if (this.context.layout.tourZone >= 0) {
      const x = 91 + this.context.layout.tourZone * 223; const y = 225 - this.context.layout.tourZone * 15;
      c.fillStyle = '#DFC28B'; c.beginPath(); c.arc(x, y - 10, 5, 0, Math.PI * 2); c.fill();
      c.fillStyle = '#79A58D'; c.fillRect(x - 5, y - 5, 10, 16);
      c.fillStyle = '#C9D4AE'; c.beginPath(); c.ellipse(x + 11, y + 3, 5, 8, 0, 0, Math.PI * 2); c.fill();
    }
    c.restore();
  }

  build() {
    Canvas(this.canvas).width('100%').height('100%').onReady(() => { this.ready = true; this.paint(); })
      .onAreaChange((_old: Area, area: Area) => { this.widthVp = Number(area.width); this.heightVp = Number(area.height); this.paint(); })
      .accessibilityText('保存时的原创夜市布局，包含当时的铺位、人手、街灯与巡茶位置')
  }
}

@Component
export struct MarketMemoryPage {
  @Prop noteId: string = '';
  @Prop @Watch('refreshNote') records: ArchiveRecord[] = [];
  @Prop saving: boolean = false;
  @Prop reducedMotion: boolean = false;
  onCurrentSnapshot: () => ArchiveSnapshot = () => emptySnapshot('');
  onCommit: (snapshot: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onContinue: (nightId: string) => void = () => {};
  onArchive: (siteId: string) => void = () => {};
  onShare: (note: ArchiveRecord) => void = () => {};
  onBack: () => void = () => {};
  @State private editing: boolean = false;
  @State private draft: string = '';
  @State private tagsText: string = '';
  @State private message: string = '';
  @State private localSaving: boolean = false;
  @State private containerWidth: number = 360;

  private note(): ArchiveRecord | undefined { return activeRecords(this.records, 'note').find(note => note.id === this.noteId); }
  private refreshNote(): void {
    if (this.editing) return;
    this.draft = this.note()?.body || ''; this.tagsText = this.note()?.tags.join('，') || '';
  }
  aboutToAppear(): void { this.refreshNote(); }
  private route(id: string): string { return id === 'west' ? '西来客多' : id === 'east' ? '东来客多' : '三街均来'; }

  private async save(): Promise<void> {
    if (this.localSaving || this.saving) return;
    const tags = this.tagsText.split(/[,，]/).map((tag: string): string => tag.trim()).filter((tag: string): boolean => !!tag);
    if (tags.length > MAX_NOTE_TAGS || tags.some((tag: string): boolean => tag.length > MAX_NOTE_TAG_LENGTH)) {
      this.message = `最多${MAX_NOTE_TAGS}个标签，每个不超过${MAX_NOTE_TAG_LENGTH}字。`; return;
    }
    const next = copySnapshot(this.onCurrentSnapshot());
    const note = next.records.find(item => item.id === this.noteId && item.kind === 'note' && !item.deleted);
    if (!note || !note.marketContext) { this.message = '这一页已有变化，请返回记忆后重新打开。'; return; }
    if (!this.draft.trim() && !note.marketContext.excerpt.trim()) { this.message = '请留下自己的文字，或保留一段摘录。'; return; }
    // 只修改正文和标签。上下文来自最新快照的深拷贝，既不重冻当前经营，也不替换保存时出处。
    note.body = this.draft.trim().slice(0, MAX_NOTE_LENGTH); note.tags = tags;
    note.updatedAt = nextTimestamp(next.records, Date.now()); note.deviceId = next.deviceId;
    this.localSaving = true;
    try {
      if (await this.onCommit(next)) { this.editing = false; this.message = '文字和标签已保存，图景与出处仍是当时那一页。'; }
      else this.message = '还没有保存成功，编辑内容留在这里。';
    } catch (_error) { this.message = '还没有保存成功，编辑内容留在这里。'; }
    finally { this.localSaving = false; }
  }

  private remove(): void {
    this.getUIContext().showAlertDialog({ title: '删除这一夜的记忆？', message: '删除会随同一账号同步。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteConfirmed(); } } });
  }

  private async deleteConfirmed(): Promise<void> {
    if (this.localSaving || this.saving) return;
    const next = copySnapshot(this.onCurrentSnapshot());
    const note = next.records.find(item => item.id === this.noteId && !item.deleted);
    if (!note) return;
    // 保留整页墓碑与冻结上下文，避免另一设备的旧版本在重连后复活。
    note.deleted = true; note.updatedAt = nextTimestamp(next.records, Date.now()); note.deviceId = next.deviceId;
    this.localSaving = true;
    try { if (await this.onCommit(next)) this.onBack(); else this.message = '删除尚未保存，请稍后再试。'; }
    catch (_error) { this.message = '删除尚未保存，请稍后再试。'; }
    finally { this.localSaving = false; }
  }

  @Builder
  private textContent(note: ArchiveRecord) {
    Column({ space: 16 }) {
      Text(note.marketContext?.title || '我的三夜记忆').fontSize(28).fontWeight(FontWeight.Medium).fontColor('#203D43').width('100%')
      Text(new Date(note.updatedAt).toLocaleDateString()).fontSize(12).fontColor('#7D877E').width('100%')
      if (note.marketContext) {
        Text(note.marketContext.round >= 4 ? `${this.route(note.marketContext.routeId)} · 四段十二批已收市` :
          `${this.route(note.marketContext.routeId)} · 已完${note.marketContext.round}段 · 本段已迎${note.marketContext.batch}/3批`)
          .fontSize(12).fontColor('#8F724E').width('100%')
        Text(`接待 ${note.marketContext.summary.served} / ${note.marketContext.summary.arrivals} 客　余 ${note.marketContext.summary.cash} 钱`)
          .fontSize(15).fontColor('#365E54').width('100%').id('tn-memory-summary')
        if (note.marketContext.summary.teaServed > 0 || note.marketContext.summary.festivalServed > 0) {
          Text(`茶客 ${note.marketContext.summary.teaServed}　观灯后消费 ${note.marketContext.summary.festivalServed}`)
            .fontSize(12).fontColor('#718176').width('100%')
        }
      }
      if (note.marketContext?.excerpt) {
        Text(`「${note.marketContext.excerpt}」`).fontSize(15).lineHeight(26).fontColor('#648273').width('100%')
          .copyOption(CopyOptions.LocalDevice).id('tn-memory-excerpt')
      }
      if (this.editing) {
        TextArea({ text: this.draft, placeholder: '补写这一夜让你想到什么' }).height(140).maxLength(MAX_NOTE_LENGTH)
          .fontSize(16).fontColor('#234149').backgroundColor('#FFFCF4').borderRadius(12)
          .id('tn-memory-edit-body').onChange((value: string) => { this.draft = value; })
        TextInput({ text: this.tagsText, placeholder: '标签，用逗号分隔' }).height(44).maxLength(MAX_NOTE_TAGS_TEXT_LENGTH)
          .fontSize(13).fontColor('#234149').backgroundColor('#FFFCF4').borderRadius(10)
          .id('tn-memory-edit-tags').onChange((value: string) => { this.tagsText = value; })
        Button('保存文字与标签', { type: ButtonType.Normal }).width('100%').height(46).fontColor('#FFF9E9')
          .backgroundColor('#2C5E59').borderRadius(12).enabled(!this.saving && !this.localSaving).id('tn-memory-save')
          .onClick(() => { this.save(); })
      } else if (note.body.trim()) {
        Text(note.body).fontSize(17).lineHeight(29).fontColor('#29454B').width('100%')
          .copyOption(CopyOptions.LocalDevice).id('tn-memory-body')
      }
      if (note.tags.length > 0 && !this.editing) {
        Text(note.tags.map((tag: string): string => `#${tag}`).join('  ')).fontSize(12).fontColor('#89917E').width('100%')
      }
      Row({ space: 9 }) {
        Button(this.editing ? '取消编辑' : '编辑文字', { type: ButtonType.Normal }).height(38).layoutWeight(1)
          .fontSize(13).fontColor('#315B56').backgroundColor('#E2E8D9').borderRadius(10).id('tn-memory-edit')
          .onClick(() => { this.draft = note.body; this.tagsText = note.tags.join('，'); this.editing = !this.editing; })
        Button('分享', { type: ButtonType.Normal }).height(38).layoutWeight(1).fontSize(13).fontColor('#315B56')
          .backgroundColor('#E2E8D9').borderRadius(10).id('tn-memory-share').onClick(() => this.onShare(note))
        Button('删除', { type: ButtonType.Normal }).height(38).fontSize(13).fontColor('#A66D59')
          .backgroundColor(Color.Transparent).enabled(!this.saving && !this.localSaving).id('tn-memory-delete').onClick(() => this.remove())
      }.width('100%')
      if (this.message) { Text(this.message).fontSize(12).fontColor('#6B817A').width('100%') }
      Divider().color('#D8DFD3')
      Text('保存时的文献出处').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#29454B').width('100%')
      if (note.marketContext) {
        ForEach(note.marketContext.sources, (source: MarketMemorySource) => {
          Column({ space: 6 }) {
            Text(source.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#365D59').width('100%')
            Text(source.era).fontSize(11).fontColor('#9A7653').width('100%')
            Text(source.quote).fontSize(14).lineHeight(23).fontColor('#6D7D77').width('100%').copyOption(CopyOptions.LocalDevice)
            Text(`${source.url}\n保存时查阅日期：${source.accessedAt}`).fontSize(10).lineHeight(17).fontColor('#89938C')
              .width('100%').copyOption(CopyOptions.LocalDevice)
          }.width('100%').padding(16).backgroundColor('#FBF9F0').borderRadius(12)
        }, (source: MarketMemorySource) => source.id)
        Text(`文献修订 ${note.marketContext.contentRevision} · 图景修订 ${note.marketContext.sceneRevision}`)
          .fontSize(10).fontColor('#89938C').width('100%')
        Button('回到这一夜，接着开市  →', { type: ButtonType.Normal }).width('100%').height(46)
          .fontColor('#FFF6DE').backgroundColor('#2B5755').borderRadius(12).id('tn-memory-continue')
          .onClick(() => this.onContinue(note.marketContext!.nightId))
      }
      Button('再读这篇文化资料', { type: ButtonType.Normal }).width('100%').height(40).fontSize(13)
        .fontColor('#647A72').backgroundColor(Color.Transparent).id('tn-memory-archive').onClick(() => this.onArchive(note.siteId))
      Text(MARKET_CULTURE_BOUNDARY).fontSize(10).lineHeight(18).fontColor('#8A9387').width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(24)
  }

  build() {
    NavDestination() {
      if (this.note()?.marketContext) {
        Scroll() {
          Column() {
            if (this.note()!.marketContext!.sceneRevision === 1) {
              MarketMemoryPreview({ context: this.note()!.marketContext })
                .width('100%').height(this.containerWidth >= 900 ? 360 : 255).id('tn-memory-preview')
            } else {
              Text('这一页保留了较新修订的图景，文字与出处仍可重读。').fontSize(14).fontColor('#758578').padding(24)
            }
            this.textContent(this.note()!)
          }.width('100%').constraintSize({ maxWidth: 1000 })
        }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off).id('tn-memory-page')
          .onAreaChange((_old: Area, area: Area) => { this.containerWidth = Number(area.width); })
      } else {
        Column({ space: 12 }) {
          Text('这页记忆暂不在这里').fontSize(18).fontColor('#36554F')
          Button('返回记忆').onClick(() => this.onBack())
        }.width('100%').padding(24)
      }
    }.title('我的三夜记忆').backgroundColor('#F2F0E6')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .systemBarStyle({ statusBarContentColor: '#FF203D43' })
      .onShown(() => { setPaperWindowText(this.getUIContext(), '#203D43'); })
      .onHidden(() => { setPaperWindowText(this.getUIContext(), '#F4ECD9'); })
  }
}
