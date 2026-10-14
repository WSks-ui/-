@Entry
@Component
struct TestHost {
  build() {
    Column() {
      Text('设备回归准备中').fontSize(18)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}
