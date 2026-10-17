import type { ArchiveRecord, HeritageSite, MemoryPose } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import {
  memoryPoseLabel, memorySeasonLabel, paperThemeLabel
} from '../domain/MemoryJournal';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { MemoryPosePreview } from './MemoryPosePreview';

// 一张手账卡同时承载旧笔记与新记忆元数据；旧记录没有显式印章时显示“河流笔记”，不补造打卡状态。
// 卡片本体不接管点击，打开、凝视、编辑、删除均保持为独立入口，避免操作区域互相吞点击。
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
  @Prop editable: boolean = false;
  @Prop busy: boolean = false;

  // 只呈现记录里显式保存的印章类型。印章是手账装饰，缺失时不能替旧笔记推断用户做过打卡。
  private stampText(): string {
    return this.note.stampType || '';
  }

  private stampLine(index: number): string {
    const stamp: string = this.stampText();
    return index === 0 ? stamp.slice(0, 2) : stamp.slice(2, 4);
  }

  private savedTime(): string {
    if (!Number.isFinite(this.note.updatedAt) || this.note.updatedAt <= 0) return '时间待补';
    const value: Date = new Date(this.note.updatedAt);
    if (Number.isNaN(value.getTime())) return '时间待补';
    return value.toLocaleString('zh-CN');
  }

  private seasonLabel(): string {
    return this.note.updatedAt > 0 ? memorySeasonLabel(this.note.updatedAt) : '';
  }

  private themeLabel(): string {
    return this.note.paperTheme ? paperThemeLabel(this.note.paperTheme) : '';
  }

  private paperSurface(): Resource {
    // 纸色只留在细边与主题标签，画面和观察文字是主体；未知或旧主题回退为素白。
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

  build() {
    Column() {
      Column({ space: this.compact ? 11 : 15 }) {
        Row({ space: 8 }) {
          Row({ space: 7 }) {
            Row().width(7).height(7).borderRadius(4).backgroundColor(T.accent)
            Text('云河手记').fontSize(F.caption).fontColor(T.accent).fontWeight(FontWeight.Medium)
            if (this.themeLabel()) {
              Text(this.themeLabel()).fontSize(F.caption).fontColor(T.yellowInk)
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .backgroundColor(this.paperSurface()).borderRadius(9)
            }
          }.layoutWeight(1)
          if (this.editable) {
            Button('编辑').id(`edit-${this.note.id}`).height(32).fontSize(F.caption)
              .fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(10)
              .enabled(!this.busy).accessibilityText('编辑这条手账').onClick(() => this.onEdit())
            Button('删除').id(`delete-${this.note.id}`).height(32).fontSize(F.caption)
              .fontColor(T.accent).backgroundColor(T.surface).borderRadius(10)
              .border({ width: 1, color: T.line, radius: 10 })
              .enabled(!this.busy).accessibilityText('删除这条手账').onClick(() => this.onDelete())
          }
        }.width('100%').alignItems(VerticalAlign.Center)

        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(`${this.site.city} · ${this.site.era}`)
              .fontSize(F.caption).fontColor(T.muted)
            Text(this.site.name).fontSize(F.card).fontWeight(FontWeight.Bold)
              .fontColor(T.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)

          if (this.stampText()) {
            Column({ space: 2 }) {
              Text(this.stampLine(0)).fontSize(9).fontWeight(FontWeight.Bold).fontColor(T.onAccent)
              Text(this.stampLine(1)).fontSize(9).fontWeight(FontWeight.Bold).fontColor(T.onAccent)
            }.width(34).height(34).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(T.accent).borderRadius(6)
              .accessibilityText(`${this.stampText()}，朱砂方印`)
          } else {
            Text('河流笔记').fontSize(F.caption).fontColor(T.muted).fontWeight(FontWeight.Medium)
              .padding({ left: 9, right: 9, top: 7, bottom: 7 })
              .backgroundColor(T.soft).borderRadius(11).accessibilityText('普通河流笔记')
          }
        }.width('100%').alignItems(VerticalAlign.Center)

        MemoryPosePreview({
          siteId: this.note.siteId,
          poseJson: this.note.snapshot3DPose ? JSON.stringify(this.note.snapshot3DPose) : '',
          previewHeight: this.compact ? 176 : 218,
          previewId: `memory-preview-${this.note.id}`,
          onOpen: this.onPose
        })

        if (this.note.snapshot3DPose) {
          Column({ space: 4 }) {
            Text('当时在看').fontSize(F.caption).fontColor(T.accent).fontWeight(FontWeight.Medium)
            Text(this.poseLabel()).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).lineHeight(22)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').alignItems(HorizontalAlign.Start)
        }

        if (this.note.quotedPoemOrFact) {
          Row({ space: 10 }) {
            Column().width(2).height(this.compact ? 44 : 56).backgroundColor(T.rose).borderRadius(1)
            Column({ space: 4 }) {
              Text('私人摘录').fontSize(F.caption).fontColor(T.accent).fontWeight(FontWeight.Medium)
              Text(this.note.quotedPoemOrFact).fontSize(F.small).fontColor(T.muted).lineHeight(22)
                .maxLines(this.compact ? 2 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').alignItems(VerticalAlign.Top)
        }

        Row({ space: 8 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 7 }) {
              Text('◉').fontSize(F.small).fontColor(T.mintInk)
              Text(this.poseLabel() ? '重返我的观察' : '打开观察场景')
                .fontSize(F.caption).fontColor(T.mintInk).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.width('100%').justifyContent(FlexAlign.Start)
          }
          .id(`memory-pose-${this.note.id}`).layoutWeight(1).height(36)
          .padding({ left: 10, right: 10 }).backgroundColor(T.mint).borderRadius(11)
          .accessibilityText(this.poseLabel() ? `打开手账保存的观察视角，${this.poseLabel()}` : `打开${this.site.name}的观察场景`)
          .onClick(() => this.onPose())
        }.width('100%')

        Text(this.note.body || '这页手记还没有写下文字。')
          .fontSize(F.body).fontColor(T.ink).lineHeight(this.compact ? 24 : 27)
          .maxLines(this.compact ? 3 : 8).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.savedTime()).fontSize(F.caption).fontColor(T.muted).maxLines(1).width('100%')
        Row({ space: 7 }) {
          if (this.seasonLabel()) {
            Text(this.seasonLabel()).fontSize(F.caption).fontColor(T.yellowInk).maxLines(1).layoutWeight(1)
          } else {
            Row().layoutWeight(1)
          }
          Text(this.syncLabel || '已保存在本机').fontSize(F.caption).fontColor(T.mintInk)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%')

        if (this.note.tags.length > 0) {
          Text(this.note.tags.map((tag: string) => `#${tag}`).join('  ·  '))
            .fontSize(F.caption).fontColor(T.accent).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }

        Row() {
          Row({ space: 5 }) {
            Row().width(4).height(4).borderRadius(2).backgroundColor(T.yellowInk)
            Text('留在个人记忆里').fontSize(F.caption).fontColor(T.muted)
          }.layoutWeight(1)
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              Text('打开档案').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.accent)
              Text('→').fontSize(F.small).fontColor(T.accent)
            }
          }
          .id(`memory-open-${this.note.id}`).height(38)
          .padding({ left: 12, right: 12 }).backgroundColor(T.accentSoft).borderRadius(12)
          .accessibilityText(`打开${this.site.name}档案`).onClick(() => this.onOpen())
        }.width('100%').alignItems(VerticalAlign.Center)
      }
      .width('100%').padding(this.compact ? 13 : 17)
      .backgroundColor(T.surface).border({ width: 1, color: T.line, radius: 17 }).borderRadius(17)
    }
    .width('100%').padding(3)
    .backgroundColor(this.paperSurface()).border({ width: 1, color: T.line, radius: 20 }).borderRadius(20)
    .id(`memory-card-${this.note.id}`)
  }
}
