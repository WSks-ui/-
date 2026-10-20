import type { ArchiveRecord, HeritageSite, MemoryPose } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { memoryPoseLabel, paperThemeLabel } from '../domain/MemoryJournal';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { MemoryPosePreview } from './MemoryPosePreview';
import { PunchRow } from './PunchRow';

// 一张手账卡只保留“看什么、写了什么、何时留下、下一步做什么”。
// 旧文字笔记不再渲染空白视角框，避免把缺失的观察画面伪装成待开发占位。
@Component
export struct MemoryPostcardItem {
  @Prop note: ArchiveRecord = {
    id: '', kind: 'note', siteId: HERITAGE_SITES[0].id, body: '', tags: [],
    updatedAt: 0, deviceId: '', deleted: false
  };
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Prop compact: boolean = false;
  @Prop syncLabel: string = '已保存在本机';
  onOpen: () => void = () => {};
  onPose: () => void = () => {};
  onEdit: () => void = () => {};
  onDelete: () => void = () => {};
  onAsk: () => void = () => {};
  @Prop canAsk: boolean = false;
  @Prop editable: boolean = false;
  @Prop busy: boolean = false;
  // 管理模式下整张卡只响应选择，避免编辑/删除与多选手势互相抢占。
  @Prop selectMode: boolean = false;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  private hasPose(): boolean {
    return this.note.snapshot3DPose !== undefined;
  }

  private stampText(): string {
    return this.note.stampType || '';
  }

  private stampLine(index: number): string {
    const stamp: string = this.stampText();
    return index === 0 ? stamp.slice(0, 2) : stamp.slice(2, 4);
  }

  private themeLabel(): string {
    return this.note.paperTheme ? paperThemeLabel(this.note.paperTheme) : '';
  }

  private paperSurface(): Resource {
    if (this.note.paperTheme === 'ochre') return T.yellow;
    if (this.note.paperTheme === 'jade') return T.mint;
    if (this.note.paperTheme === 'ink') return T.sunken;
    if (this.note.paperTheme === 'rose') return T.accentSoft;
    return T.surface;
  }

  private poseLabel(): string {
    const pose: MemoryPose | undefined = this.note.snapshot3DPose;
    return pose ? memoryPoseLabel(pose) : '';
  }

  private dateLabel(): string {
    if (!Number.isFinite(this.note.updatedAt) || this.note.updatedAt <= 0) return '时间未知';
    const value: Date = new Date(this.note.updatedAt);
    if (Number.isNaN(value.getTime())) return '时间未知';
    const month = value.getMonth() + 1;
    const day = value.getDate();
    const hour = value.getHours().toString().padStart(2, '0');
    const minute = value.getMinutes().toString().padStart(2, '0');
    return `${month}月${day}日 ${hour}:${minute}`;
  }

  build() {
    // Stack 只用于把打孔串覆盖到留白带：卡片本体仍是原来那个 Column，
    // 尺寸、圆角、边框、阴影与交互全部不变。
    Stack() {
    Column() {
      Column({ space: this.compact ? 10 : 13 }) {
        Row({ space: 8 }) {
          if (this.selectMode) {
            Checkbox({ name: `memory-select-${this.note.id}` }).select(this.selected)
              .selectedColor(T.accent).width(20).height(20).id(`memory-select-${this.note.id}`)
              .onChange(() => { this.onSelect(); })
          }
          Row({ space: 7 }) {
            Row().width(7).height(7).borderRadius(4).backgroundColor(T.accent)
            Text('云河手记').fontSize(F.caption).fontColor(T.accent).fontWeight(FontWeight.Medium)
            if (this.themeLabel()) {
              Text(this.themeLabel()).fontSize(F.caption).fontColor(T.yellowInk)
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .backgroundColor(this.paperSurface()).borderRadius(8)
            }
            if (this.note.aiAssist) {
              // AI 辅助用青色语义，和纸色 / 印章等装饰标签区分；不占用主色玫瑰。
              Text('AI 辅助').fontSize(F.caption).fontColor(T.mintInk)
                .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor(T.mint).borderRadius(8)
                .id(`memory-ai-assist-${this.note.id}`)
            }
          }.layoutWeight(1)
          if (this.editable && !this.selectMode) {
            Button({ type: ButtonType.Normal }) {
              SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(15).fontColor([T.accent])
            }.width(34).height(34).backgroundColor(T.accentSoft).borderRadius(10)
              .accessibilityText('编辑这条手账').enabled(!this.busy).id(`edit-${this.note.id}`).onClick(() => this.onEdit())
            Button({ type: ButtonType.Normal }) {
              SymbolGlyph($r('sys.symbol.trash')).fontSize(15).fontColor([T.muted])
            }.width(34).height(34).backgroundColor(T.soft).borderRadius(10)
              .accessibilityText('删除这条手账').enabled(!this.busy).id(`delete-${this.note.id}`).onClick(() => this.onDelete())
          }
        }.width('100%').alignItems(VerticalAlign.Center)

        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(`${this.site.city} · ${this.site.era}`).fontSize(F.caption).fontColor(T.muted)
            Text(this.site.name).fontSize(F.card).fontWeight(FontWeight.Bold)
              .fontColor(T.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          if (this.stampText()) {
            Column({ space: 2 }) {
              Text(this.stampLine(0)).fontSize(9).fontWeight(FontWeight.Bold).fontColor(T.onAccent)
              Text(this.stampLine(1)).fontSize(9).fontWeight(FontWeight.Bold).fontColor(T.onAccent)
            }.width(34).height(34).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(T.accent).borderRadius(7)
              .accessibilityText(`${this.stampText()}，朱砂方印`)
          }
        }.width('100%').alignItems(VerticalAlign.Center)

        if (this.hasPose()) {
          if (!this.compact) {
            MemoryPosePreview({
              siteId: this.note.siteId,
              poseJson: JSON.stringify(this.note.snapshot3DPose),
              previewHeight: 156,
              previewId: `memory-preview-${this.note.id}`,
              onOpen: this.onPose
            })
          }
          Text(`当时在看 · ${this.poseLabel()}`).fontSize(F.caption).fontColor(T.mintInk)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        if (this.note.body) {
          Text(this.note.body).fontSize(F.body).fontColor(T.ink).lineHeight(this.compact ? 23 : 26)
            .maxLines(this.hasPose() ? (this.compact ? 2 : 2) : (this.compact ? 5 : 8))
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        if (this.note.quotedPoemOrFact) {
          Text(`资料摘录 · ${this.note.quotedPoemOrFact}`).fontSize(F.caption).fontColor(T.muted).lineHeight(20)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        Row({ space: 8 }) {
          Text(this.dateLabel()).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
          Text(this.syncLabel || '已保存在本机').fontSize(F.caption).fontColor(T.mintInk)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%')

        if (this.note.tags.length > 0) {
          Text(this.note.tags.slice(0, 3).map((tag: string) => `#${tag}`).join('   '))
            .fontSize(F.caption).fontColor(T.accent).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        Row({ space: 8 }) {
          if (this.hasPose()) {
            Button('重温', { type: ButtonType.Normal }).id(`memory-pose-${this.note.id}`)
              .layoutWeight(1).height(38).fontSize(F.caption).fontColor(T.onAccent)
              .backgroundColor(T.accent).borderRadius(11)
              .accessibilityText(`重温${this.site.name}保存的观察视角`).onClick(() => this.onPose())
          }
          Button('读手账', { type: ButtonType.Normal }).id(`memory-open-${this.note.id}`)
            .layoutWeight(1).height(38).fontSize(F.caption).fontColor(T.accent)
            .backgroundColor(T.accentSoft).borderRadius(11)
            .accessibilityText(`阅读${this.site.name}手账全文`).onClick(() => this.onOpen())
          if (this.canAsk) {
            Button('问 AI', { type: ButtonType.Normal }).id(`memory-ask-${this.note.id}`)
              .constraintSize({ minHeight: 38 }).fontSize(F.caption).fontColor(T.mintInk)
              .backgroundColor(T.mint).borderRadius(11).accessibilityText('带着这页手账继续问 AI')
              .onClick(() => this.onAsk())
          }
        }.width('100%')
      }
      .width('100%').padding(this.compact ? 13 : 16)
      .backgroundColor(T.surface).border({ width: 1, color: T.line, radius: 17 }).borderRadius(17)
    }
    .width('100%').padding(3)
    .backgroundColor(this.paperSurface()).border({ width: 1, color: T.line, radius: 20 }).borderRadius(20)
    // 顶部留白带上一排横向打孔：孔洞透出页面画布色，只留孔形态，不做整圈齿边。
    PunchRow({ offsetX: 19, offsetY: 8 })
    }.width('100%').id(`memory-card-${this.note.id}`)
  }
}
