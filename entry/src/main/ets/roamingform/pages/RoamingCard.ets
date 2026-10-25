const cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct RoamingCard {
  @LocalStorageProp('cardLabel') cardLabel: string = '继续这段漫游';
  @LocalStorageProp('title') title: string = '沿河，开启一城故事';
  @LocalStorageProp('excerpt') excerpt: string = '从五座城里选择一段故事，在家也能沿河发现文化线索。';
  @LocalStorageProp('chapterId') chapterId: string = '';
  @LocalStorageProp('noteId') noteId: string = '';
  @LocalStorageProp('routeAction') routeAction: string = 'home';
  @LocalStorageProp('progressLabel') progressLabel: string = '';
  @LocalStorageProp('progressValue') progressValue: number = 0;
  @LocalStorageProp('showProgress') showProgress: boolean = false;
  @LocalStorageProp('testStoreName') testStoreName: string = '';

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.roaming_card_river'))
        .width('100%').height('100%').objectFit(ImageFit.Cover)
      Column({ space: 5 }) {
        Row() {
          Text('云河纪').fontSize(11).fontColor('#40675D').fontWeight(FontWeight.Medium)
          Blank()
          Text(this.cardLabel).fontSize(10).fontColor('#647568')
        }.width('100%')
        Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#233E35')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(this.excerpt).fontSize(11).fontColor('#526159').lineHeight(16)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('84%')
        Blank()
        if (this.showProgress) {
          Row({ space: 9 }) {
            Progress({ value: this.progressValue, total: 100, type: ProgressType.Linear })
              .width(68).color('#3C8170').backgroundColor('#DFE6D7')
            Text(this.progressLabel).fontSize(10).fontColor('#40675D').maxLines(1)
          }.width('100%')
        } else {
          Text('打开云河纪  ›').fontSize(10).fontColor('#40675D').width('100%')
        }
      }.padding({ left: 16, right: 16, top: 13, bottom: 13 }).width('100%').height('100%')
      Text('原创河流图景').fontSize(7).fontColor('#718679')
        .position({ right: 10, bottom: 6 })
    }
    .width('100%').height('100%').backgroundColor('#F4F0E4').borderRadius(20).clip(true)
    .onClick(() => {
      // router 只启动本应用，冷 / 热启动均由 EntryAbility 转交窗口级路由。
      // 不在卡片内调用 note 保存，也不把打开卡片算作一条探索完成。
      if (this.testStoreName.length > 0) {
        postCardAction(this, {
          action: 'router', abilityName: 'EntryAbility',
          params: {
            roamingAction: this.routeAction,
            roamingChapterId: this.chapterId,
            roamingNoteId: this.noteId,
            yunhejiTestStore: this.testStoreName
          }
        });
      } else {
        postCardAction(this, {
          action: 'router', abilityName: 'EntryAbility',
          params: {
            roamingAction: this.routeAction,
            roamingChapterId: this.chapterId,
            roamingNoteId: this.noteId
          }
        });
      }
    })
  }
}
