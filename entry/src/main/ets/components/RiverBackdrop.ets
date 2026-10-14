// 首页粉彩底纹是静态装饰，不代表真实地图、水流或鸿蒙光效。
// 单独绘制在内容后方，避免每张卡片重复绘制；整个背景穿透触摸。
@Component
export struct RiverBackdrop {
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;

  private draw(): void {
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    this.context.strokeStyle = '#087A6C70';
    this.context.lineWidth = 0.6;
    for (let y: number = 0; y < this.canvasHeight; y += 36) {
      for (let x: number = 0; x < this.canvasWidth; x += 36) {
        const offset: number = (y / 36) % 2 === 0 ? 0 : 18;
        this.context.beginPath();
        this.context.moveTo(x + offset, y + 5);
        this.context.bezierCurveTo(x + offset + 4, y, x + offset + 9, y + 10, x + offset + 14, y + 5);
        this.context.stroke();
      }
    }
  }

  build() {
    Canvas(this.context).width('100%').height('100%')
      .linearGradient({ angle: 145, colors: [
        [$r('app.color.home_rose'), 0], [$r('app.color.home_blue'), 0.43],
        [$r('app.color.home_mint'), 0.8], [$r('app.color.canvas'), 1]
      ] })
      .onReady(() => this.draw())
      .onAreaChange((_old: Area, area: Area) => {
        this.canvasWidth = Number(area.width);
        this.canvasHeight = Number(area.height);
        this.draw();
      })
      .hitTestBehavior(HitTestMode.None)
  }
}
