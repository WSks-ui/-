import { ArchiveRecord } from '../domain/ArchiveDomain';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import {
  DIG_ACUTE_WORK, DIG_COLUMNS, DIG_ROWS, DIG_WORK_DAYS, DigAction, DigLayout, DigVerdict, KaifengDigV1,
  createDigLayout, digAnswerColumn, digAnswerLayered, digCellAt, digCellKey, digDeeper, digEvidenceFor,
  digExcavate, digIsDeep, digIsDug, digNeedsSubmit, digRestart, digSubmit, digVerdict, emptyDig,
  parseDig, serializeDig
} from '../domain/KaifengDig';
import { kaifengDigFromRecords } from '../domain/KaifengDigRecords';

// 汴河探方：开封的主玩法。
//
// 和上一版三幕的区别只有一句：这里的正确答案不在说明文字里。
// 玩家要花工日换信息，再用信息做判断；判断错了会知道错在哪一列。
//
// 布局约束（上一版踩过）：探方格、提交按钮、工日必须在任何状态下都露在屏幕内。
// 所以这里不用浮层面板，改成「顶栏 + 网格 + 可滚动选择区 + 固定提交条」。

// 任务说明只给「找什么」，不给「几块才够」和「哪一列」——那两步要玩家自己走。
const DIG_TASK: string = '汴河在这一段自西向东流。桥横跨河道、以石材砌筑；河床是淤土与生活堆积。' +
  '找出桥轴压在哪一列，再判断这一处建过几次桥。';
const DIG_HELP: string = '探方布局为原创示意，不是州桥实测剖面。出土物只写通用类别。';

@Component
export struct KaifengDigPage {
  @Prop chapterId: string = 'roam-kf-night';
  @Prop records: ArchiveRecord[] = [];
  @Prop saving: boolean = false;
  onDigChange: (chapterId: string, digJson: string) => void = () => {};
  // 结算后由玩家确认，才把这一局写成一条手账；不自动写，避免每局都往记忆里塞东西。
  onArchive: (body: string) => Promise<boolean> = async () => false;
  onBack: () => void = () => {};

  @State private dig: KaifengDigV1 = emptyDig('roam-kf-night', 1, 0);
  @State private layout: DigLayout = { seed: 0, column: 0, layered: false, cells: [] };
  @State private selected: string = '';
  @State private message: string = '';
  @State private note: string = '';
  @State private archiving: boolean = false;
  @State private archived: boolean = false;

  private columns: number[] = [0, 1, 2, 3, 4];
  private rows: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    // 这里任何异常都不能让整页空白：捕获后仍给出一个可玩的第一局，
    // 并把原因写在提示条里（真机上曾因运行时不支持某个 API 而整页不渲染）。
    try {
      const saved = kaifengDigFromRecords(this.records, this.chapterId);
      const base = saved ? saved : emptyDig(this.chapterId, 1, Date.now());
      this.dig = base;
      this.layout = createDigLayout(this.chapterId, base.attempt);
      this.selected = '';
      this.message = saved ? '上次的探方已经恢复：工日、已挖格与判断都在。' :
        `你有 ${DIG_WORK_DAYS} 个工日：发掘一格 1 个，下挖一格 2 个。先想好先挖哪里。`;
    } catch (error) {
      this.dig = emptyDig(this.chapterId, 1, Date.now());
      this.message = `这一局没能载入（${(error as Error).message}），已给你一局新的。`;
    }
  }

  private persist(): void {
    try {
      this.onDigChange(this.chapterId, serializeDig(this.dig));
    } catch (_error) {
      this.note = '这一局的进度没能写进本机存档；画面仍可继续。';
    }
  }

  private apply(action: DigAction): void {
    if (!action.ok) {
      this.message = action.message;
      return;
    }
    const next = action.state;
    next.updatedAt = Date.now();
    this.dig = next;
    this.message = action.message;
    this.note = digNeedsSubmit(next) ? '工日已经用完。选定桥列，交付判断。' : '';
    this.persist();
  }

  private tapCell(col: number, row: number): void {
    if (this.dig.phase !== 'playing') return;
    if (!digIsDug(this.dig, col, row)) {
      // 点一下就挖：发掘是有代价的动作，不该再套一层确认。
      this.selected = digCellKey(col, row);
      this.apply(digExcavate(this.dig, this.layout, col, row));
      return;
    }
    const key = digCellKey(col, row);
    if (this.selected === key) {
      this.selected = '';
      return;
    }
    this.selected = key;
    const cell = digCellAt(this.layout, col, row);
    const evidence = cell ? digEvidenceFor(cell.top) : undefined;
    const deep = digIsDeep(this.dig, col, row);
    let text = `第 ${col + 1} 列第 ${row + 1} 行：${evidence ? evidence.label : ''}。${evidence ? evidence.note : ''}`;
    if (deep) {
      text += cell && cell.bottom !== '' ? ' 下层见到更早的桥基。' : ' 已到底，未见更早桥基。';
    }
    this.message = text;
  }

  private selectedLabel(): string {
    if (this.selected === '') return '';
    const parts = this.selected.split('-');
    return `第 ${parseInt(parts[0], 10) + 1} 列第 ${parseInt(parts[1], 10) + 1} 行`;
  }

  private canDeepen(): boolean {
    if (this.selected === '' || this.dig.phase !== 'playing') return false;
    const parts = this.selected.split('-');
    const col = parseInt(parts[0], 10);
    const row = parseInt(parts[1], 10);
    return digIsDug(this.dig, col, row) && !digIsDeep(this.dig, col, row);
  }

  private deepen(): void {
    if (!this.canDeepen()) return;
    const parts = this.selected.split('-');
    this.apply(digDeeper(this.dig, this.layout, parseInt(parts[0], 10), parseInt(parts[1], 10)));
  }

  private pickColumn(col: number): void {
    if (this.dig.phase !== 'playing') return;
    this.dig = digAnswerColumn(this.dig, col);
    this.dig.updatedAt = Date.now();
    this.persist();
  }

  private pickLayered(value: string): void {
    if (this.dig.phase !== 'playing') return;
    this.dig = digAnswerLayered(this.dig, value);
    this.dig.updatedAt = Date.now();
    this.persist();
  }

  private submit(): void {
    if (this.dig.phase !== 'playing') return;
    if (this.dig.answerColumn < 0) {
      this.message = '先选桥轴在第几列，再交付。';
      return;
    }
    const result = digSubmit(this.dig, this.layout, Date.now());
    this.dig = result.state;
    this.message = result.verdict.message;
    this.selected = '';
    this.persist();
  }

  private restart(): void {
    const next = digRestart(this.dig, Date.now());
    this.dig = next;
    this.layout = createDigLayout(this.chapterId, next.attempt);
    this.selected = '';
    this.message = `第 ${next.attempt} 局：布局已换。最佳记录仍保留。`;
    this.note = '';
    this.archived = false;
    this.archiving = false;
    this.persist();
  }

  private workTone(): Resource {
    return this.dig.workLeft <= 2 ? T.accent : T.ink;
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([T.ink])
      }.width(36).height(36).borderRadius(18).padding(0).backgroundColor(T.soft)
        .accessibilityText('返回').id('dig-back').onClick(() => this.onBack())

      Column({ space: 1 }) {
        Text('汴河探方').fontSize(17).fontWeight(FontWeight.Bold).fontColor(T.ink)
        Text(`第 ${this.dig.attempt} 局 · ${DIG_COLUMNS} × ${DIG_ROWS} 格 · 已挖 ${this.dig.dug.length} 格`)
          .fontSize(11).fontColor(T.muted).maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)

      Column({ space: 0 }) {
        Text(`${this.dig.workLeft}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.workTone())
          .id('dig-work-left')
        Text('工日').fontSize(10).fontColor(T.muted)
      }.alignItems(HorizontalAlign.Center)
    }.width('100%').padding({ left: 12, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  messageBar() {
    Text(this.message).fontSize(12).lineHeight(18).fontColor(T.ink).width('100%')
      .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(T.soft).borderRadius(8).id('dig-message')
  }

  // 探方网格直接写在本组件里，不再拆成 @Component + @Prop 传递：
  // 复杂对象经 @Prop 深拷贝时曾导致整页不渲染（实测空白，无异常日志）。
  private topLabel(col: number, row: number): string {
    if (!digIsDug(this.dig, col, row)) return '未挖';
    const cell = digCellAt(this.layout, col, row);
    const evidence = cell ? digEvidenceFor(cell.top) : undefined;
    return evidence ? evidence.label : '—';
  }

  private deepLabel(col: number, row: number): string {
    if (!digIsDeep(this.dig, col, row)) return '';
    const cell = digCellAt(this.layout, col, row);
    return !cell || cell.bottom === '' ? '到底 · 生土' : '下层 · 更早桥基';
  }

  private structural(col: number, row: number): boolean {
    const cell = digCellAt(this.layout, col, row);
    if (!cell || !digIsDug(this.dig, col, row)) return false;
    return cell.top === 'wall-block' || cell.top === 'deck-stone';
  }

  @Builder
  gridCell(col: number, row: number) {
    Column({ space: 2 }) {
      Text(this.topLabel(col, row))
        .fontSize(12)
        .fontWeight(this.structural(col, row) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(!digIsDug(this.dig, col, row) ? T.tertiary :
          this.structural(col, row) ? T.accent : T.ink)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.deepLabel(col, row) !== '') {
        Text(this.deepLabel(col, row)).fontSize(9).fontColor(T.muted).maxLines(1)
      } else if (!digIsDug(this.dig, col, row)) {
        Text(`${col + 1} · ${row + 1}`).fontSize(9).fontColor(T.tertiary)
      }
    }
    .layoutWeight(1).aspectRatio(1).justifyContent(FlexAlign.Center)
    .backgroundColor(!digIsDug(this.dig, col, row) ? T.sunken :
      this.structural(col, row) ? T.accentSoft : T.surface)
    .border({
      width: this.selected === digCellKey(col, row) ? 2 : 1,
      color: this.selected === digCellKey(col, row) ? T.accent :
        digIsDug(this.dig, col, row) ? T.line : T.tertiary,
      radius: 7,
      style: digIsDug(this.dig, col, row) ? BorderStyle.Solid : BorderStyle.Dashed
    })
    .stateStyles({ pressed: { .opacity(0.72) } })
    .id(`dig-cell-${col}-${row}`)
    .accessibilityText(`第 ${col + 1} 列第 ${row + 1} 行，${this.topLabel(col, row)}`)
    .onClick(() => this.tapCell(col, row))
  }

  @Builder
  digGrid() {
    Column({ space: 6 }) {
      ForEach(this.rows, (row: number) => {
        Row({ space: 6 }) {
          ForEach(this.columns, (col: number) => {
            this.gridCell(col, row)
          }, (col: number) => `${col}-${row}-${this.dig.dug.indexOf(digCellKey(col, row))}-` +
            `${this.dig.deep.indexOf(digCellKey(col, row))}-${this.selected === digCellKey(col, row)}`)
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (row: number) => {
        let key = `dig-row-${row}`;
        for (let col = 0; col < DIG_COLUMNS; col++) {
          key += `|${this.dig.dug.indexOf(digCellKey(col, row))}:${this.dig.deep.indexOf(digCellKey(col, row))}`;
        }
        return key;
      })
    }.width('100%').id('dig-grid')
  }

  @Builder
  columnLabels() {
    Row({ space: 6 }) {
      ForEach(this.columns, (col: number) => {
        Text(`${col + 1}`).fontSize(11).fontColor(T.muted).textAlign(TextAlign.Center)
          .layoutWeight(1)
      }, (col: number) => `dig-col-label-${col}`)
    }.width('100%')
  }

  @Builder
  pickerRow(title: string, hint: string) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(T.ink)
        Text(hint).fontSize(10).fontColor(T.tertiary).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  columnPicker() {
    Row({ space: 6 }) {
      ForEach(this.columns, (col: number) => {
        Button(`${col + 1}`, { type: ButtonType.Normal })
          .layoutWeight(1).height(38).fontSize(14)
          .fontColor(this.dig.answerColumn === col ? T.onAccent : T.ink)
          .backgroundColor(this.dig.answerColumn === col ? T.accent : T.surface)
          .border({ width: 1, color: this.dig.answerColumn === col ? T.accent : T.line, radius: 8 })
          .borderRadius(8)
          .id(`dig-column-${col}`)
          .accessibilityText(`桥轴在第 ${col + 1} 列`)
          .onClick(() => this.pickColumn(col))
      }, (col: number) => `dig-column-btn-${col}-${this.dig.answerColumn === col}`)
    }.width('100%')
  }

  @Builder
  layeredPicker() {
    Row({ space: 6 }) {
      Button('明桥压宋基', { type: ButtonType.Normal })
        .layoutWeight(1).height(38).fontSize(13)
        .fontColor(this.dig.answerLayered === 'layered' ? T.onAccent : T.ink)
        .backgroundColor(this.dig.answerLayered === 'layered' ? T.accent : T.surface)
        .border({ width: 1, color: this.dig.answerLayered === 'layered' ? T.accent : T.line, radius: 8 })
        .borderRadius(8).id('dig-layered-yes')
        .onClick(() => this.pickLayered('layered'))
      Button('仅见明桥', { type: ButtonType.Normal })
        .layoutWeight(1).height(38).fontSize(13)
        .fontColor(this.dig.answerLayered === 'single' ? T.onAccent : T.ink)
        .backgroundColor(this.dig.answerLayered === 'single' ? T.accent : T.surface)
        .border({ width: 1, color: this.dig.answerLayered === 'single' ? T.accent : T.line, radius: 8 })
        .borderRadius(8).id('dig-layered-no')
        .onClick(() => this.pickLayered('single'))
      Button('暂不', { type: ButtonType.Normal })
        .layoutWeight(0.7).height(38).fontSize(13)
        .fontColor(this.dig.answerLayered === 'unknown' ? T.ink : T.tertiary)
        .backgroundColor(this.dig.answerLayered === 'unknown' ? T.soft : T.surface)
        .border({ width: 1, color: T.line, radius: 8 }).borderRadius(8)
        .onClick(() => this.pickLayered('unknown'))
    }.width('100%')
  }

  @Builder
  playView() {
    Column({ space: 8 }) {
      this.messageBar()

      Column({ space: 6 }) {
        this.columnLabels()
        this.digGrid()
      }.width('100%')

      Scroll() {
        Column({ space: 10 }) {
          if (this.selected !== '') {
            Row({ space: 8 }) {
              Text(this.canDeepen() ? `已选${this.selectedLabel()}，可继续下挖。` : `已选${this.selectedLabel()}。`)
                .fontSize(11).fontColor(T.muted).layoutWeight(1).maxLines(2)
              if (this.canDeepen()) {
                Button(`下挖 · 2 工日`, { type: ButtonType.Normal })
                  .height(34).fontSize(12).padding({ left: 12, right: 12 })
                  .fontColor(this.dig.workLeft >= 2 ? T.onAccent : T.tertiary)
                  .backgroundColor(this.dig.workLeft >= 2 ? T.accent : T.soft)
                  .borderRadius(8).id('dig-deep-selected')
                  .enabled(this.dig.workLeft >= 2)
                  .onClick(() => this.deepen())
              }
            }.width('100%').padding(8).backgroundColor(T.surface).borderRadius(8)
          }

          Column({ space: 6 }) {
            this.pickerRow('桥轴在第几列？', '同列两次见石才算定轴')
            this.columnPicker()
          }.width('100%').alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            this.pickerRow('这一处的层序', '没下挖就答，按猜处理')
            this.layeredPicker()
          }.width('100%').alignItems(HorizontalAlign.Start)

          Text(DIG_TASK).fontSize(11).lineHeight(17).fontColor(T.muted).width('100%')
          Text(DIG_HELP).fontSize(10).lineHeight(15).fontColor(T.tertiary).width('100%')
        }.width('100%').padding({ top: 2, bottom: 8 })
      }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
        .edgeEffect(EdgeEffect.Spring)

      // 关键提示固定在提交条上方：放在滚动区里曾被裁掉半行，玩家看不到「工日已用完」。
      if (this.note !== '') {
        Text(this.note).fontSize(11).fontColor(T.accent).width('100%').id('dig-note')
      }
      Row({ space: 10 }) {
        Column({ space: 1 }) {
          Text(`已用 ${DIG_WORK_DAYS - this.dig.workLeft} / ${DIG_WORK_DAYS} 工日`).fontSize(11)
            .fontColor(T.muted)
          Text(this.dig.answerColumn < 0 ? '还没选桥列' : `桥列：第 ${this.dig.answerColumn + 1} 列`)
            .fontSize(11).fontColor(this.dig.answerColumn < 0 ? T.tertiary : T.ink)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Button(this.dig.answerColumn < 0 ? '先选桥列' : '交付判断', { type: ButtonType.Normal })
          .height(44).fontSize(15).padding({ left: 22, right: 22 })
          .fontColor(this.dig.answerColumn < 0 ? T.muted : T.onAccent)
          .backgroundColor(this.dig.answerColumn < 0 ? T.surface : T.accent)
          .border({ width: 1, color: this.dig.answerColumn < 0 ? T.line : T.accent, radius: 10 })
          .borderRadius(10).id('dig-submit')
          .enabled(this.dig.answerColumn >= 0 && !this.saving)
          .onClick(() => this.submit())
      }.width('100%').padding({ top: 6 })
    }.width('100%').layoutWeight(1).padding({ left: 12, right: 12 })
  }

  // 结算回放：交付之后网格会消失，玩家就没法核对「我到底挖了哪、桥轴在哪」。
  // 这里把答案与自己的操作叠在同一张图上，比只看文字依据更直接。
  @Builder
  replayCell(col: number, row: number) {
    Column({ space: 1 }) {
      Text(this.topLabel(col, row)).fontSize(10)
        .fontColor(digIsDug(this.dig, col, row) ? T.ink : T.tertiary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (col === this.layout.column) {
        Text('桥列').fontSize(8).fontColor(T.accent)
      }
    }
    .layoutWeight(1).aspectRatio(1).justifyContent(FlexAlign.Center)
    .backgroundColor(digIsDug(this.dig, col, row) ? T.surface : T.sunken)
    .border({
      width: col === this.layout.column ? 2 : 1,
      color: col === this.layout.column ? T.accent : T.line,
      radius: 5,
      style: digIsDug(this.dig, col, row) ? BorderStyle.Solid : BorderStyle.Dashed
    })
  }

  @Builder
  replayGrid() {
    Column({ space: 8 }) {
      Text('这一局你挖过的格').fontSize(12).fontWeight(FontWeight.Medium).fontColor(T.muted)
        .width('100%')
      Column({ space: 4 }) {
        ForEach(this.rows, (row: number) => {
          Row({ space: 4 }) {
            ForEach(this.columns, (col: number) => {
              this.replayCell(col, row)
            }, (col: number) => `replay-${col}-${row}-${digIsDug(this.dig, col, row)}`)
          }.width('100%')
        }, (row: number) => `replay-row-${row}-${digIsDug(this.dig, 0, row)}`)
      }.width('100%')
      Text('朱框是这一局真正的桥轴；灰底虚线是你没挖到的格。')
        .fontSize(10).fontColor(T.tertiary).width('100%')
    }.width('100%').padding(12).backgroundColor(T.soft).borderRadius(10)
      .alignItems(HorizontalAlign.Start).id('dig-replay')
  }

  private archiveBody(): string {
    const verdict = digVerdict(this.dig, this.layout);
    const column = this.dig.answerColumn >= 0 ? `第 ${this.dig.answerColumn + 1} 列` : '未选';
    const layered = this.dig.answerLayered === 'layered' ? '明桥压宋基' :
      this.dig.answerLayered === 'single' ? '仅见明桥' : '未判断';
    const lines: string[] = [];
    lines.push(`汴河探方 · 第 ${this.dig.attempt} 局 · ${verdict.grade}`);
    lines.push('');
    lines.push(`我判断桥轴在${column}，层序为「${layered}」。`);
    for (const reason of verdict.reasons) {
      lines.push(`· ${reason}`);
    }
    lines.push('');
    lines.push('探方布局为原创示意，不是州桥实测剖面。');
    return lines.join('\n');
  }

  private async archive(): Promise<void> {
    if (this.archived || this.archiving) return;
    this.archiving = true;
    try {
      const saved = await this.onArchive(this.archiveBody());
      this.archived = saved;
      if (!saved) this.message = '这一页没有存进记忆，探方记录仍在本机。';
    } catch (_error) {
      this.message = '这一页没有存进记忆，探方记录仍在本机。';
    }
    this.archiving = false;
  }

  @Builder
  resultView() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text(digVerdict(this.dig, this.layout).grade === '' ? '未过' : digVerdict(this.dig, this.layout).grade)
            .fontSize(52).fontWeight(FontWeight.Bold)
            .fontColor(digVerdict(this.dig, this.layout).grade === '甲' ? T.accent : T.ink)
            .id('dig-grade')
          Text(digVerdict(this.dig, this.layout).message).fontSize(13).fontColor(T.ink)
            .textAlign(TextAlign.Center).lineHeight(20)
        }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 12, bottom: 4 })

        this.replayGrid()

        Column({ space: 8 }) {
          Text('这一局的依据').fontSize(12).fontWeight(FontWeight.Medium).fontColor(T.muted)
            .width('100%')
          ForEach(digVerdict(this.dig, this.layout).reasons, (line: string, index: number) => {
            Row({ space: 8 }) {
              Row().width(4).height(4).borderRadius(2).backgroundColor(T.accent).margin({ top: 6 })
              Text(line).fontSize(12).lineHeight(19).fontColor(T.ink).layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Top)
          }, (line: string, index: number) => `dig-reason-${index}-${line.length}`)
        }.width('100%').padding(12).backgroundColor(T.surface).borderRadius(10)
          .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Row({ space: 6 }) {
            Text('本局桥轴').fontSize(11).fontColor(T.muted).width(70)
            Text(`第 ${this.layout.column + 1} 列`).fontSize(12).fontColor(T.ink)
          }.width('100%')
          Row({ space: 6 }) {
            Text('本局层序').fontSize(11).fontColor(T.muted).width(70)
            Text(this.layout.layered ? '明桥压宋基' : '仅见明桥').fontSize(12).fontColor(T.ink)
          }.width('100%')
          Row({ space: 6 }) {
            Text('甲级门槛').fontSize(11).fontColor(T.muted).width(70)
            Text(`两项都对，且不超过 ${DIG_ACUTE_WORK} 个工日`).fontSize(12).fontColor(T.ink).layoutWeight(1)
          }.width('100%')
        }.width('100%').padding(12).backgroundColor(T.soft).borderRadius(10)
          .alignItems(HorizontalAlign.Start)

        if (this.dig.bestGrade !== '') {
          Text(`本机最佳：${this.dig.bestGrade}`).fontSize(11).fontColor(T.muted).width('100%')
        }

        Button(this.archived ? '已存入记忆' : this.archiving ? '正在保存' : '存为发掘记',
          { type: ButtonType.Normal })
          .width('100%').height(44).fontSize(14)
          .fontColor(this.archived ? T.muted : T.ink)
          .backgroundColor(this.archived ? T.soft : T.surface)
          .border({ width: 1, color: this.archived ? T.line : T.accent, radius: 10 })
          .borderRadius(10).id('dig-archive')
          .enabled(!this.archived && !this.archiving && !this.saving)
          .onClick(() => { this.archive(); })

        Button('换一局（布局会变）', { type: ButtonType.Normal })
          .width('100%').height(46).fontSize(15).fontColor(T.onAccent).backgroundColor(T.accent)
          .borderRadius(10).id('dig-restart').onClick(() => this.restart())
        Button('回到这一城', { type: ButtonType.Normal })
          .width('100%').height(42).fontSize(13).fontColor(T.ink).backgroundColor(T.surface)
          .borderRadius(10).onClick(() => this.onBack())
        Text(DIG_HELP).fontSize(10).lineHeight(15).fontColor(T.tertiary).width('100%')
      }.width('100%').padding({ left: 16, right: 16, bottom: 16 }).alignItems(HorizontalAlign.Start)
    }.layoutWeight(1).width('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
  }

  build() {
    // navDestination 的根节点必须是 NavDestination 本身。
    // 直接返回 Column 时页面不会挂载：真机上表现为一片空白 + 一个系统返回按钮。
    NavDestination() {
      Column({ space: 4 }) {
        this.header()
        if (this.dig.phase === 'settled') {
          this.resultView()
        } else {
          this.playView()
        }
      }.width('100%').height('100%').backgroundColor(T.canvas).id('dig-page')
    }.hideTitleBar(true).backgroundColor(T.canvas)
  }
}
