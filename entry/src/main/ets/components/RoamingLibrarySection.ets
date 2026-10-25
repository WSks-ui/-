import { ArchiveRecord, activeRecords } from '../domain/ArchiveDomain';
import { RoamChapter, RoamClue, RoamSource } from '../domain/Roaming';
import { ROAM_CHAPTERS, ROAM_SOURCES } from '../data/RoamingCatalog';
import { roamingContentType } from '../data/CulturalContentIndex';
import { ArchiveTheme as T } from './ArchiveTheme';
import { RoamingTheme as R } from './RoamingTheme';

@Component
export struct RoamingLibrarySection {
  @Prop records: ArchiveRecord[] = [];
  @Prop keyword: string = '';
  @Prop city: string = '全部城市';
  @Prop era: string = '全部年代';
  @Prop type: string = '全部类型';
  onExplore: (chapterId: string, clueId: string) => void = () => {};
  onFavorite: (clueId: string) => void = () => {};
  @State private expanded: string = '';

  private clues(chapter: RoamChapter): RoamClue[] {
    const query = this.keyword.trim().toLowerCase();
    if (this.city !== '全部城市' && this.city !== chapter.city) return [];
    return chapter.clues.filter((clue: RoamClue) => (this.era === '全部年代' || this.era === clue.era) &&
      (this.type === '全部类型' || this.type === roamingContentType(clue)) &&
      `${chapter.city} ${chapter.title} ${clue.title} ${clue.body} ${clue.era} ${roamingContentType(clue)}`
        .toLowerCase().includes(query));
  }

  private favorite(id: string): boolean {
    return activeRecords(this.records, 'favorite').some(item => item.siteId === id);
  }

  private sources(clue: RoamClue): RoamSource[] {
    return ROAM_SOURCES.filter(source => clue.sourceIds.includes(source.id));
  }

  build() {
    Column({ space: 17 }) {
      ForEach(ROAM_CHAPTERS, (chapter: RoamChapter) => {
        if (this.clues(chapter).length) {
          Column({ space: 11 }) {
            Text(`${chapter.city} / ${chapter.title}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text(chapter.subtitle).fontSize(13).fontColor(T.muted).lineHeight(21).width('100%')
            ForEach(this.clues(chapter), (clue: RoamClue) => {
              Column({ space: 8 }) {
                // 单行列表：标题与元信息左对齐，收藏改图标按钮，展开后再给正文与入口。
                // 原来整块居中 + 底部独立按钮，读起来像网页卡片而不是列表项。
                Row({ space: 8 }) {
                  Column({ space: 3 }) {
                    Text(clue.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(T.ink)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                      .id(`culture-clue-${clue.id}`)
                    Text(`${roamingContentType(clue)} · ${clue.era}`).fontSize(11).fontColor(T.muted)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                    Text(clue.goal).fontSize(12).fontColor(T.tertiary).maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(17).width('100%')
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    .onClick(() => { this.expanded = this.expanded === clue.id ? '' : clue.id; })
                  Button({ type: ButtonType.Normal }) {
                    SymbolGlyph(this.favorite(clue.id) ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
                      .fontSize(18).fontColor([this.favorite(clue.id) ? T.accent : T.tertiary])
                  }.width(36).height(36).borderRadius(18).backgroundColor(Color.Transparent)
                    .onClick(() => this.onFavorite(clue.id)).id(`culture-favorite-${clue.id}`)
                    .accessibilityText(this.favorite(clue.id) ? '取消收藏' : '收藏这一段')
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([T.tertiary])
                    .rotate({ angle: this.expanded === clue.id ? 90 : 0 })
                }.width('100%').alignItems(VerticalAlign.Top)
                if (this.expanded === clue.id) {
                  // 线索正文用漫游主题的软墨色（R.inkSoft），与篇章页 goal 正文同一阅读层级。
                  Text(clue.body).fontSize(13).lineHeight(21).fontColor(R.inkSoft).width('100%')
                    .copyOption(CopyOptions.LocalDevice)
                  ForEach(this.sources(clue), (source: RoamSource) => {
                    Text(`${source.title}\n${source.url}`).fontSize(11).lineHeight(17).fontColor(T.mintInk).width('100%')
                      .copyOption(CopyOptions.LocalDevice)
                  }, (source: RoamSource) => source.id)
                  Text('初稿待校审 · 完整资料离线可读').fontSize(11).fontColor(T.tertiary).width('100%')
                  Button('走进这一段', { type: ButtonType.Normal }).width('100%').height(36).fontSize(13)
                    .fontColor(T.mintInk).backgroundColor(T.mint).borderRadius(8)
                    .onClick(() => this.onExplore(chapter.id, clue.id))
                }
              }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 11 })
                .backgroundColor(T.surface).borderRadius(12)
            }, (clue: RoamClue) => clue.id)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
      }, (chapter: RoamChapter) => chapter.id)
      if (ROAM_CHAPTERS.every(chapter => this.clues(chapter).length === 0)) {
        Text('没有匹配的文化线索，试试其他城市或关键词。').fontSize(15).fontColor(T.muted).padding(22)
      }
    }.width('100%')
  }
}
