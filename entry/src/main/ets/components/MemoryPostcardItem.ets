import type { ArchiveRecord, HeritageSite, MemoryPose } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { memoryPoseLabel, paperThemeLabel } from '../domain/MemoryJournal';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { MemoryPosePreview } from './MemoryPosePreview';
import { PunchRow } from './PunchRow';
import { RoamingScene } from './RoamingScene';
import { ROAM_CHAPTERS } from '../data/RoamingCatalog';

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

  private roamScene(): string {
    const context = this.note.roamingContext;
    if (!context || context.sceneRevision !== 1) return '';
    const chapter = ROAM_CHAPTERS.find(item => item.id === context.chapterId);
    const clue = chapter?.clues.find(item => item.id === context.clueId);
    if (!clue || !clue.options.some(item => item.id === context.choiceId)) return '';
    return chapter?.scene || '';
  }

  private roamStage(): number {
    const chapter = ROAM_CHAPTERS.find(item => item.id === this.note.roamingContext?.chapterId);
    return Math.max(0, chapter?.clues.findIndex(item => item.id === this.note.roamingContext?.clueId) ?? 0);
  }

  private roamChoice(): number {
    const chapter = ROAM_CHAPTERS.find(item => item.id === this.note.roamingContext?.chapterId);
    return chapter?.clues[this.roamStage()]?.options.findIndex(item => item.id === this.note.roamingContext?.choiceId) ?? -1;
  }

  build() {
    // Stack 只把打孔串覆盖到顶部留白带，不参与两种卡片布局或拦截内容交互。
    Stack() {
    Column() {
      Column({ space: this.compact ? 10 : 13 }) {
        // 列表优先展示档案与正文，不重复堆叠品牌与纸色标签；
        // AI 来源标识与管理选择保留独立行，不能随装饰一起隐藏。
        if (!this.compact || this.selectMode || this.note.aiAssist !== undefined) {
          Row({ space: 8 }) {
            if (this.selectMode) {
              Checkbox({ name: `memory-select-${this.note.id}` }).select(this.selected)
                .selectedColor(T.accent).width(20).height(20).id(`memory-select-${this.note.id}`)
                .onChange(() => { this.onSelect(); })
            }
            Row({ space: 7 }) {
              if (!this.compact) {
                Row().width(7).height(7).borderRadius(4).backgroundColor(T.accent)
                Text('云河手记').fontSize(F.caption).fontColor(T.accent).fontWeight(FontWeight.Medium)
                if (this.themeLabel()) {
                  Text(this.themeLabel()).fontSize(F.caption).fontColor(T.yellowInk)
                    .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                    .backgroundColor(this.paperSurface()).borderRadius(8)
                }
              }
              if (this.note.aiAssist) {
                // AI 辅助用青色语义，和纸色 / 印章等装饰标签区分；不占用主色玫瑰。
                Text('AI 辅助').fontSize(F.caption).fontColor(T.mintInk)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor(T.mint).borderRadius(8)
                  .id(`memory-ai-assist-${this.note.id}`)
              }
            }.layoutWeight(1)
            // 列表通过“读手账”进入详情操作；画廊继续保留原编辑 / 删除入口及 ID。
            if (this.editable && !this.compact && !this.selectMode) {
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
        }

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

        if (this.note.roamingContext && !this.compact && this.roamScene()) {
          // 漫游保存的是文化片段的选择与原创图景修订，不替代旧器物的原取景 pose。
          RoamingScene({ scene: this.roamScene(), stage: this.roamStage(), choice: this.roamChoice(),
            amount: 100, found: ['kiln', 'home', 'dragon', 'tiger'], illuminated: this.roamStage() === 2,
            sceneHeight: 190, interactive: false })
          Text('当时留下的文化片段 · 原创图景').fontSize(F.caption).fontColor(T.mintInk).width('100%')
        }
        if (this.hasPose()) {
          // 管理态只保留选择，画廊预览也不能触发导航，与底部操作保持同一规则。
          if (!this.compact && !this.selectMode) {
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
            .maxLines(this.hasPose() ? 2 : (this.compact ? 3 : 8))
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        // 摘录留在画廊 / 全文中，列表只承担辨认和重访，不改变记录内容。
        if (!this.compact && this.note.quotedPoemOrFact) {
          Text(`资料摘录 · ${this.note.quotedPoemOrFact}`).fontSize(F.caption).fontColor(T.muted).lineHeight(20)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        Row({ space: 8 }) {
          Text(this.dateLabel()).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
          Text(this.syncLabel || '已保存在本机').fontSize(F.caption).fontColor(T.mintInk)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%')

        if (this.note.tags.length > 0) {
          // 列表保留两项真实标签辅助辨认，完整记录与画廊原有三项摘要规则不变。
          Text(this.note.tags.slice(0, this.compact ? 2 : 3).map((tag: string) => `#${tag}`).join('   '))
            .fontSize(F.caption).fontColor(T.accent).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        if (!this.selectMode) {
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
      }
      // 列表移除装饰标题行后，顶部仍为打孔留出空白，不能让孔串压到城市文字上。
      .width('100%').padding({ left: this.compact ? 13 : 16, right: this.compact ? 13 : 16,
        top: this.compact ? 20 : 16, bottom: this.compact ? 13 : 16 })
      .backgroundColor(T.surface).border({ width: 1, color: T.line, radius: 17 }).borderRadius(17)
    }
    .width('100%').padding(3)
    .backgroundColor(this.paperSurface()).border({ width: 1, color: T.line, radius: 20 }).borderRadius(20)
    // 顶部留白带上一排横向打孔：孔洞透出页面画布色，只留孔形态，不做整圈齿边。
    PunchRow({ offsetX: 19, offsetY: 8 })
    }.width('100%').id(`memory-card-${this.note.id}`)
  }
}
