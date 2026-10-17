import { HeritageSite } from '../domain/ArchiveDomain';
import { siteIllustration } from './SiteRow';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 遗址图片轮播组件。
// photos 有内容时展示真实遗址照片（左右滑动），否则降级显示主题插画。
// 图片文件放在 resources/base/media/ 下，文件名在 HeritageSite.photos 中声明。
// 版权和来源由内容录入者负责；此组件不生成任何几何体或 3D 示意。
@Component
export struct SiteObject3D {
  @Prop site: HeritageSite;
  @Prop reducedMotion: boolean = false;
  @Prop active: boolean = true;
  @State private current: number = 0;
  private swipeStartX: number = 0;

  private photos(): string[] {
    return this.site.photos ?? [];
  }

  private hasPhotos(): boolean {
    return this.photos().length > 0;
  }

  private prev(): void {
    const n = this.photos().length;
    if (n < 2) return;
    this.current = (this.current - 1 + n) % n;
  }

  private next(): void {
    const n = this.photos().length;
    if (n < 2) return;
    this.current = (this.current + 1) % n;
  }

  @Builder
  photoViewer() {
    const photos = this.photos();
    Stack({ alignContent: Alignment.Bottom }) {
      // 当前图片
      Image($rawfile(photos[this.current]))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(14)

      // 左右翻页箭头（超过 1 张时显示）
      if (photos.length > 1) {
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(16).fontColor([T.ink])
          }.width(36).height(36).backgroundColor('rgba(255,255,255,0.75)')
            .onClick(() => this.prev())
            .accessibilityText('上一张')

          Blank()

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.ink])
          }.width(36).height(36).backgroundColor('rgba(255,255,255,0.75)')
            .onClick(() => this.next())
            .accessibilityText('下一张')
        }.width('100%').padding({ left: 8, right: 8 })

        // 页码指示点
        Row({ space: 5 }) {
          ForEach(photos, (_p: string, i: number) => {
            Circle()
              .width(i === this.current ? 8 : 5)
              .height(i === this.current ? 8 : 5)
              .fill(i === this.current ? T.accent : 'rgba(255,255,255,0.6)')
              .animation({ duration: this.reducedMotion ? 0 : 150 })
          }, (_p: string, i: number) => `dot-${i}`)
        }.margin({ bottom: 10 })
      }
    }
    .width('100%').height(210)
    .borderRadius(14).clip(true)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 30 })
        .onActionEnd((e: GestureEvent) => {
          if (e.offsetX < -20) this.next();
          else if (e.offsetX > 20) this.prev();
        })
    )
  }

  @Builder
  illustrationFallback() {
    // 没有真实照片时，显示主题插画 + "暂无照片"提示
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(siteIllustration(this.site))
        .width('100%').height('100%')
        .objectFit(ImageFit.Contain)
        .accessibilityText('文化主题示意图')

      Text('暂无遗址照片')
        .fontSize(F.caption).fontColor(T.muted)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(6)
        .backgroundColor('rgba(255,255,255,0.72)')
        .margin({ left: 10, bottom: 10 })
    }
    .width('100%').height(210)
    .borderRadius(14).clip(true)
    .backgroundColor(T.soft)
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text('遗址图片').fontSize(F.small).fontColor(T.ink).fontWeight(FontWeight.Bold)
          Text(this.hasPhotos()
            ? `${this.photos().length} 张 · 左右滑动`
            : '暂未收录').fontSize(F.caption).fontColor(T.accent)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        if (this.hasPhotos()) {
          Text(`${this.current + 1} / ${this.photos().length}`)
            .fontSize(F.caption).fontColor(T.muted)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(8).backgroundColor(T.surface)
        }
      }.width('100%')

      if (this.hasPhotos()) {
        this.photoViewer()
      } else {
        this.illustrationFallback()
      }

      if (this.hasPhotos()) {
        Text('图片来源与版权信息见各条目说明；照片反映现状，不作为考古复原依据。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      }
    }
    .width('100%').padding(16).borderRadius(T.cardRadius).backgroundColor(T.soft)
    .id('site-object-card').margin({ top: 12, bottom: 4 })
  }
}
