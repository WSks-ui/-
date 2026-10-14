import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 动态统计通过 @Prop 发布，避免 @Builder 的值参数捕获首次快照后一直显示旧数字。
@Component
export struct ArchiveStat {
  @Prop value: string = '0';
  @Prop label: string = '';
  @Prop valueId: string = '';
  build() {
    Column({ space: 6 }) {
      Text(this.value).fontSize(28).fontWeight(FontWeight.Bold).fontColor(T.ink).id(this.valueId)
      Text(this.label).fontSize(F.caption).fontColor(T.muted)
    }.layoutWeight(1)
  }
}

@Component
export struct PaperSurface {
  @Prop contentHeight: number = 115;
  @Prop color: ResourceColor = T.surface;
  @Prop surfaceId: string = '';
  build() {
    Column() {
      Row().width('74%').height(26).backgroundColor(this.color).borderRadius({ topLeft: 20, topRight: 24 })
      Row().width('100%').height(this.contentHeight - 26).backgroundColor(this.color)
        .borderRadius({ topRight: 24, bottomLeft: 20, bottomRight: 20 })
    }.width('100%').height(this.contentHeight).alignItems(HorizontalAlign.Start)
      .hitTestBehavior(HitTestMode.None).id(this.surfaceId)
  }
}

@Component
export struct ArchiveStatusRow {
  @Prop value: string = '';
  @Prop label: string = '';
  @Prop valueId: string = '';
  build() {
    Row({ space: 12 }) {
      Text(this.label).fontSize(F.small).fontColor(T.muted).layoutWeight(1)
      Text(this.value).fontSize(F.small).fontColor(T.ink).constraintSize({ maxWidth: '60%' })
        .textAlign(TextAlign.End).id(this.valueId)
    }.width('100%').padding({ top: 16, bottom: 16 })
  }
}
