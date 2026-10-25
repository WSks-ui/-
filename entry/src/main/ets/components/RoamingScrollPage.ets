import { ArchiveRecord, activeRecords } from '../domain/ArchiveDomain';
import { RoamChapter, roamProgress } from '../domain/Roaming';
import { ROAM_CHAPTERS } from '../data/RoamingCatalog';
import { culturalEntryForId } from '../data/CulturalContentIndex';
import { ArchiveTheme as T } from './ArchiveTheme';

@Component
export struct RoamingScrollPage {
  @Prop records: ArchiveRecord[] = [];
  onRead: (note: ArchiveRecord) => void = () => {};
  onOpenChapter: (chapterId: string) => void = () => {};
  onOpenContent: (id: string) => void = () => {};
  onLegacyJourney: () => void = () => {};
  onBack: () => void = () => {};

  private notes(chapter: RoamChapter): ArchiveRecord[] {
    return activeRecords(this.records, 'note').filter(note =>
      (note.roamingContext?.city || culturalEntryForId(note.siteId)?.city) === chapter.city);
  }

  private favorites(chapter: RoamChapter): ArchiveRecord[] {
    return activeRecords(this.records, 'favorite').filter(record => culturalEntryForId(record.siteId)?.city === chapter.city);
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 22 }) {
          Text('我的黄河长卷').fontSize(30).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
          Text('沿河收藏片刻，把自己的话慢慢写进来。').fontSize(15).fontColor(T.muted).width('100%')
          Text(`${activeRecords(this.records, 'note').length} 页亲笔记忆 · ${activeRecords(this.records, 'favorite').length} 条收藏`)
            .fontSize(14).fontColor(T.mintInk).width('100%').id('roam-scroll-count')
          if (activeRecords(this.records, 'note').length > 0) {
            Text('最近留下').fontSize(16).fontWeight(FontWeight.Medium).fontColor(T.mintInk).width('100%')
            ForEach(activeRecords(this.records, 'note').slice(0, 2), (note: ArchiveRecord) => {
              Button({ type: ButtonType.Normal }) {
                Column({ space: 9 }) {
                  Text(note.roamingContext?.title || culturalEntryForId(note.siteId)?.name || '我的手账')
                    .fontSize(18).fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
                  Text(note.body).fontSize(15).fontColor(T.muted).lineHeight(25).maxLines(3).width('100%')
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text('翻开这一页  ›').fontSize(13).fontColor(T.mintInk).width('100%')
                }.width('100%').padding(19).alignItems(HorizontalAlign.Start)
              }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(18)
                .onClick(() => this.onRead(note)).id(`roam-recent-note-${note.id}`)
            }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
          }
          ForEach(ROAM_CHAPTERS, (chapter: RoamChapter, index: number) => {
            Column({ space: 13 }) {
              Row({ space: 10 }) {
                Text(`0${index + 1}`).fontSize(14).fontColor(T.mintInk)
                Text(chapter.city).fontSize(23).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
                Text(`线上线索 ${roamProgress(this.records, chapter).completedCount}/3`)
                  .fontSize(12).fontColor(T.muted)
              }.width('100%')
              ForEach(this.notes(chapter), (note: ArchiveRecord) => {
                Button({ type: ButtonType.Normal }) {
                  Column({ space: 9 }) {
                    Text(note.roamingContext?.title || culturalEntryForId(note.siteId)?.name || '我的手账')
                      .fontSize(16).fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%').maxLines(2)
                    Text(note.body).fontSize(15).lineHeight(25).fontColor(T.muted).width('100%').maxLines(4)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (note.tags.length) {
                      Text(note.tags.map(tag => `#${tag}`).join('  ')).fontSize(12).fontColor(T.mintInk).width('100%')
                    }
                    Text('打开这一页  ›').fontSize(13).fontColor(T.accent).width('100%')
                  }.width('100%').padding(17)
                }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(17)
                  .onClick(() => this.onRead(note)).id(`roam-scroll-note-${note.id}`)
              }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
              ForEach(this.favorites(chapter), (favorite: ArchiveRecord) => {
                Button(`已收藏 · ${culturalEntryForId(favorite.siteId)?.name || '原内容暂不可用'}  ›`, { type: ButtonType.Normal })
                  .width('100%').fontSize(13).fontColor(T.mintInk).backgroundColor(T.mint).borderRadius(11)
                  .onClick(() => this.onOpenContent(favorite.siteId))
              }, (favorite: ArchiveRecord) => `${favorite.id}:${favorite.updatedAt}`)
              if (this.notes(chapter).length === 0 && this.favorites(chapter).length === 0) {
                Text('这里还没有你的记录。先逛一段，也可以只把喜欢的内容收下。')
                  .fontSize(14).fontColor(T.muted).lineHeight(24).width('100%')
              }
              Button(`继续 ${chapter.title}`, { type: ButtonType.Normal }).fontSize(13).fontColor(T.mintInk)
                .backgroundColor(T.mint).onClick(() => this.onOpenChapter(chapter.id))
            }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(T.soft).borderRadius(21)
              .id(`roam-scroll-city-${chapter.id}`)
          }, (chapter: RoamChapter) => chapter.id)
          Button('重温旧主题 · 泥火成器').width('100%').fontSize(14).fontColor(T.muted)
            .backgroundColor(T.surface).onClick(() => this.onLegacyJourney()).id('roam-scroll-legacy')
          Text('线上探索只记录应用中的游历。亲笔文字、收藏与真实到访分别保留。')
            .fontSize(12).lineHeight(21).fontColor(T.muted).width('100%')
        }.width('100%').constraintSize({ maxWidth: 1000 }).padding({ left: 22, right: 22, top: 24, bottom: 50 })
      }.height('100%').width('100%').align(Alignment.Top).id('roam-personal-scroll')
    }.title('我的黄河长卷').backgroundColor(T.canvas)
      .onBackPressed(() => { this.onBack(); return true; })
  }
}
