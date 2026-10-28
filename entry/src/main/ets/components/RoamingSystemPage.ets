import { common } from '@kit.AbilityKit';
import { AddFormMenuItem } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData } from '@kit.FormKit';
import {
  defaultRoamingCardPreview, readRoamingCardPreview, roamingFormWant, RoamingCardPreview
} from '../platform/RoamingSystem';

const CHAPTER_PREVIEW_ID: string = 'roaming-system-preview-chapter';
const MEMORY_PREVIEW_ID: string = 'roaming-system-preview-memory';

@Component
export struct RoamingSystemPage {
  // 页面不持有正式 snapshot。上层需要保持页面常驻时，可递增此值重新读取派生缓存。
  @Prop @Watch('readPreviews') cacheRevision: number = 0;
  onBack: () => void = () => {};
  @State private chapterPreview: RoamingCardPreview = defaultRoamingCardPreview('chapter');
  @State private memoryPreview: RoamingCardPreview = defaultRoamingCardPreview('memory');
  @State private contentWidth: number = 0;
  @State private cacheUnavailable: boolean = false;

  aboutToAppear(): void {
    this.readPreviews();
  }

  private readPreviews(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.chapterPreview = readRoamingCardPreview(context, 'chapter');
      this.memoryPreview = readRoamingCardPreview(context, 'memory');
      this.cacheUnavailable = false;
    } catch {
      this.cacheUnavailable = true;
    }
  }

  private added(error: BusinessError, formId: string): void {
    if (error && error.code) {
      this.getUIContext().getPromptAction().showToast({ message: '未添加卡片，原记录保持不变。' });
      return;
    }
    // 只有系统添加回调给出真实 formId 才显示添加结果，不把打开菜单算作添加成功。
    if (typeof formId === 'string' && formId.length > 0) {
      this.getUIContext().getPromptAction().showToast({ message: '桌面卡片已添加。' });
    }
  }

  @Builder
  chapterMenu() {
    Menu() {
      AddFormMenuItem(roamingFormWant('chapter'), CHAPTER_PREVIEW_ID, {
        formBindingData: formBindingData.createFormBindingData(this.chapterPreview),
        style: { options: { content: '添加这张漫游卡片' } },
        callback: (error: BusinessError, formId: string) => this.added(error, formId)
      })
    }
  }

  @Builder
  memoryMenu() {
    Menu() {
      AddFormMenuItem(roamingFormWant('memory'), MEMORY_PREVIEW_ID, {
        formBindingData: formBindingData.createFormBindingData(this.memoryPreview),
        style: { options: { content: '添加这张记忆卡片' } },
        callback: (error: BusinessError, formId: string) => this.added(error, formId)
      })
    }
  }

  @Builder
  previewFace(preview: RoamingCardPreview, previewId: string) {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.roaming_card_river')).width('100%').height('100%').objectFit(ImageFit.Cover)
      Column({ space: 7 }) {
        Row() {
          Text('云河纪').fontSize(12).fontColor('#40675D').fontWeight(FontWeight.Medium)
          Blank()
          Text(preview.cardLabel).fontSize(11).fontColor('#647568')
        }.width('100%')
        Text(preview.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#233E35')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(preview.excerpt).fontSize(12).fontColor('#526159').lineHeight(18)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('86%')
        Blank()
        if (preview.showProgress) {
          Row({ space: 10 }) {
            Progress({ value: preview.progressValue, total: 100, type: ProgressType.Linear })
              .width(76).color('#3C8170').backgroundColor('#DFE6D7')
            Text(preview.progressLabel).fontSize(11).fontColor('#40675D').maxLines(1)
          }.width('100%')
        } else {
          Text('打开云河纪  ›').fontSize(11).fontColor('#40675D').width('100%')
        }
      }.padding({ left: 19, right: 19, top: 16, bottom: 17 }).width('100%').height('100%')
      Text('原创河流图景').fontSize(8).fontColor('#718679').position({ right: 10, bottom: 6 })
    }.width('100%').height(180).backgroundColor('#F4F0E4').borderRadius(20).clip(true).id(previewId)
  }

  @Builder
  chapterCard() {
    Column({ space: 12 }) {
      this.previewFace(this.chapterPreview, CHAPTER_PREVIEW_ID)
      Text(this.chapterPreview.cardLabel).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#243F36').width('100%')
      Text(this.chapterPreview.chapterId.startsWith('night-') ? '回到已保存的夜次和批次。桌面卡片不会替你推进生意。' :
        '从桌面回到已保存的城市篇章。线索进度与你亲手完成的探索一致。')
        .fontSize(13).fontColor('#657568').lineHeight(20).width('100%')
      Button('添加到桌面').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        .backgroundColor('#2E6F5D').width('100%').height(43).borderRadius(14)
        .enabled(!this.cacheUnavailable).bindMenu(this.chapterMenu).id('roaming-add-chapter')
    }.padding(16).borderRadius(24).backgroundColor('#FFFFFF')
      .width(this.contentWidth >= 760 ? '48.8%' : '100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  memoryCard() {
    Column({ space: 12 }) {
      this.previewFace(this.memoryPreview, MEMORY_PREVIEW_ID)
      Text('最近一页').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#243F36').width('100%')
      Text('把最近保存的一页摘录与感想留在桌面。轻点卡片，回去读自己的原文。')
        .fontSize(13).fontColor('#657568').lineHeight(20).width('100%')
      Button('添加到桌面').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#2E6F5D')
        .backgroundColor('#E7EEDF').width('100%').height(43).borderRadius(14)
        .enabled(!this.cacheUnavailable).bindMenu(this.memoryMenu).id('roaming-add-memory')
    }.padding(16).borderRadius(24).backgroundColor('#FFFFFF')
      .width(this.contentWidth >= 760 ? '48.8%' : '100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column({ space: 0 }) {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(19).fontColor(['#2E6F5D'])
        }.width(42).height(42).backgroundColor('#FFFFFF').accessibilityText('返回我的')
          .onClick(() => this.onBack()).id('roaming-system-back')
        Text('桌面卡片').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#243F36')
        Blank()
      }.padding({ left: 20, right: 20, top: 12, bottom: 14 }).width('100%')
      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 7 }) {
            Text('让河流，也停留在桌面').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#243F36')
            Text('选择一张卡片，把下一段故事或最近一页记忆留在手边。')
              .fontSize(14).fontColor('#657568').lineHeight(21)
          }.width('100%').alignItems(HorizontalAlign.Start)
          if (this.cacheUnavailable) {
            Text('卡片内容暂时无法读取，稍后重开此页。').fontSize(13).fontColor('#9D5842').width('100%')
          }
          Flex({ direction: this.contentWidth >= 760 ? FlexDirection.Row : FlexDirection.Column,
            justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
            this.chapterCard()
            if (this.contentWidth < 760) Blank().height(16)
            this.memoryCard()
          }.width('100%')
          Column({ space: 10 }) {
            Text('怎样添加').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#243F36')
            Text('1. 点卡片下方的“添加到桌面”，选择菜单中的添加项。\n2. 按系统提示确认，再回到桌面查看。\n3. 也可在桌面长按云河纪图标，进入“服务卡片”选择这两张卡片。')
              .fontSize(13).fontColor('#526159').lineHeight(22)
            Text('这里显示本机已保存的内容。尚未留下记忆时，卡片会保留开始入口；只有亲手保存或完成的内容才会改变它。')
              .fontSize(12).fontColor('#657568').lineHeight(20)
          }.width('100%').padding(18).borderRadius(20).backgroundColor('#E8EDDF')
            .alignItems(HorizontalAlign.Start)
        }.padding({ left: 20, right: 20, top: 8, bottom: 28 }).width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F3EB')
      .onAreaChange((_oldArea: Area, area: Area) => { this.contentWidth = Number(area.width); })
    }.hideTitleBar(true)
  }
}
