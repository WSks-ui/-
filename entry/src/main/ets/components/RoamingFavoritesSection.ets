import { ArchiveRecord, activeRecords, COLLECTION_TAGS } from '../domain/ArchiveDomain';
import { culturalEntryForId, roamingChapterForId } from '../data/CulturalContentIndex';
import { ArchiveTheme as T } from './ArchiveTheme';

@Component
export struct RoamingFavoritesSection {
  @Prop records: ArchiveRecord[] = [];
  @Prop keyword: string = '';
  @Prop tag: string = '全部标签';
  @Prop saving: boolean = false;
  onOpen: (id: string) => void = () => {};
  onTag: (id: string, tag: string) => void = () => {};
  onRemove: (id: string) => void = () => {};

  private items(): ArchiveRecord[] {
    return activeRecords(this.records, 'favorite').filter((record: ArchiveRecord) => {
      const entry = culturalEntryForId(record.siteId);
      return roamingChapterForId(record.siteId) !== undefined && entry !== undefined &&
        (this.tag === '全部标签' || record.tags.includes(this.tag)) &&
        `${entry.name} ${entry.city} ${entry.overview} ${record.tags.join(' ')}`.toLowerCase()
          .includes(this.keyword.trim().toLowerCase());
    });
  }

  private category(record: ArchiveRecord): string {
    return record.tags.find((tag: string) => COLLECTION_TAGS.includes(tag)) || '未分类';
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.items(), (record: ArchiveRecord) => {
        Column({ space: 12 }) {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 6 }) {
              Text(culturalEntryForId(record.siteId)?.name || '文化片段').fontSize(17)
                .fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
              Text(culturalEntryForId(record.siteId)?.summary || '').fontSize(13).lineHeight(22)
                .fontColor(T.muted).width('100%')
              Text('重访文化片段  ›').fontSize(12).fontColor(T.mintInk).width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start)
          }.width('100%').padding(0).backgroundColor(Color.Transparent)
            .id(`culture-collection-${record.siteId}`).onClick(() => this.onOpen(record.siteId))
          Row({ space: 12 }) {
            Select(['未分类'].concat(COLLECTION_TAGS).map((value: string): SelectOption => ({ value })))
              .value(this.category(record)).font({ size: 12 }).layoutWeight(1).height(36)
              .fontColor(T.mintInk).backgroundColor(T.mint).enabled(!this.saving)
              .id(`culture-collection-tag-${record.siteId}`)
              .onSelect((_index: number, value: string) => this.onTag(record.siteId, value))
            Button('取消收藏', { type: ButtonType.Normal }).height(36).fontSize(12)
              .fontColor(T.muted).backgroundColor(T.soft).enabled(!this.saving)
              .onClick(() => this.onRemove(record.siteId))
          }.width('100%')
        }.width('100%').padding(17).backgroundColor(T.surface).borderRadius(17)
          .border({ width: 1, color: T.line, radius: 17 })
      }, (record: ArchiveRecord) => `${record.id}:${record.updatedAt}`)
    }.width('100%')
  }
}
