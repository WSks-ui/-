import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

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
