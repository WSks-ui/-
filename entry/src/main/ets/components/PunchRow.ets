import { ArchiveTheme as T } from './ArchiveTheme';

/**
 * 邮票打孔串：一条横向等距的圆形凹孔。
 *
 * 约束与边界（改动前请先读）：
 * 1. 只做“局部横向打孔”，不做整圈齿边。孔串覆盖在宿主的排版留白处，
 *    不参与布局计算，因此宿主的尺寸、圆角、边框、阴影全部保持原样。
 * 2. 孔洞用页面画布色（canvas）填充，等同于真的打穿到背景；
 *    绝不使用白色填充点，深浅色主题下都随背景色自适应。
 * 3. 孔洞由两层构成：底层 surface_sunken 露出的月牙是孔壁内阴影，
 *    上层 canvas 圆是真正透出背景的孔洞；不是白色填充点。
 *    不使用 stroke：当前 SDK 的描边颜色只接受字符串，写死会失去深浅色适配。
 * 4. hitTestBehavior 设为 None：孔洞不拦截点击、滚动与长按，交互与无孔时完全一致。
 * 5. accessibilityLevel 为 no：纯装饰，不进入无障碍树。
 */
@Component
export struct PunchRow {
  /** 孔数量；控制孔串长度比例，宿主留白不足时应调小而不是压缩间距。 */
  @Prop count: number = 8;
  /** 圆心间距（vp）。 */
  @Prop spacing: number = 14;
  /** 孔直径（vp）。 */
  @Prop diameter: number = 5.4;
  /** 相对宿主左上角的横向偏移（vp）。 */
  @Prop offsetX: number = 19;
  /** 相对宿主左上角的纵向偏移（vp）。 */
  @Prop offsetY: number = 8;

  private punchIndexes(): number[] {
    const indexes: number[] = [];
    for (let index = 0; index < this.count; index++) {
      indexes.push(index);
    }
    return indexes;
  }

  build() {
    Row({ space: this.spacing - this.diameter }) {
      ForEach(this.punchIndexes(), (index: number) => {
        // 一个孔由两层构成：底层沉色圆露出的月牙就是孔壁内阴影，
        // 上层画布色圆是真正“透出背景”的孔洞。深浅色主题都成立：
        // sunken 在两种主题下都比卡片底色更暗，canvas 就是页面背景色。
        Stack() {
          Circle().width(this.diameter).height(this.diameter).fill(T.sunken)
          Circle().width(this.diameter - 1.4).height(this.diameter - 1.4)
            .fill(T.canvas).translate({ x: 0.6, y: 0.6 })
        }
        .width(this.diameter)
        .height(this.diameter)
      }, (index: number) => `punch-${index}`)
    }
    .position({ x: this.offsetX, y: this.offsetY })
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no')
  }
}
