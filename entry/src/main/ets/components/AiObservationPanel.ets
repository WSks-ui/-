import type { AiFactSnapshot } from '../domain/ArchiveDomain';
import type {
  AiDraftAdoption, AiHotspotScope, AiKnowledgeScope, AiObservationAction, AiObservationReply,
  AiObservationRequest, AiSourceScope, AiTurn
} from '../domain/AiObservation';
import {
  AI_MAX_DRAFT_TAGS, AI_MAX_OBSERVATION_LENGTH, AI_MAX_QUESTION_LENGTH, AI_MAX_TURNS, acceptAiReply,
  aiErrorMessage, aiStatusLabel, collectAiReplyFactIds
} from '../domain/AiObservation';
import { aiKnowledgeScope } from '../domain/AiObservationKnowledge';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 原生 AI 观察面板：自由提问、等待 / 停止、重试、聚焦、原地依据和可编辑草稿。
// 面板不自动转动镜头、不自动保存；回答到达只更新本面板，聚焦与保存都必须由用户点击触发。
@Component
export struct AiObservationPanel {
  @Prop siteId: string = '';
  @Prop sceneRevision: number = 2;
  @Prop @Watch('contextChanged') hotspotId: string = '';
  @Prop signedIn: boolean = false;
  @Prop serviceConfigured: boolean = false;
  @Prop startExpanded: boolean = false;
  @Prop reducedMotion: boolean = false;
  @Prop initialQuestion: string = '';
  @Prop initialObservation: string = '';
  onFocusHotspot: (hotspotId: string) => void = () => {};
  onAdoptDraft: (draft: AiDraftAdoption) => void = () => {};
  onAiRequest: (request: AiObservationRequest) => Promise<AiObservationReply> = async () => {
    throw new Error('AI_NOT_CONFIGURED');
  };
  onAiCancel: () => void = () => {};

  @State private expanded: boolean = false;
  @State private question: string = '';
  // 输入校验用行内提示，不再写进只在 phase=error 时渲染的错误块。
  @State private questionHint: string = '';
  @State private turns: AiTurn[] = [];
  @State private phase: string = 'idle';
  @State private status: string = '';
  @State private answer: string = '';
  @State private replyFactIds: string[] = [];
  @State private actions: AiObservationAction[] = [];
  @State private evidenceOpen: boolean = false;
  @State private answerExpanded: boolean = false;
  @State private evidenceFactIds: string[] = [];
  @State private errorText: string = '';
  @State private infoText: string = '';
  @State private elapsedSeconds: number = 0;
  @State private observationText: string = '';
  @State private observationHint: string = '';
  @State private draftVisible: boolean = false;
  @State private draftBody: string = '';
  @State private draftTags: string = '';
  @State private draftFactIds: string[] = [];
  @State private draftQuestion: string = '';
  // 草稿预览默认只露出 4 行，避免长文把“采纳 / 放弃”推到屏幕外。
  @State private draftExpanded: boolean = false;

  private scope: AiKnowledgeScope | undefined = undefined;
  private questionController: TextAreaController = new TextAreaController();
  private activeRequestId: string = '';
  private generation: number = 0;
  private startedAt: number = 0;
  private timer: number = -1;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.scope = aiKnowledgeScope(this.siteId);
    // 游客默认收起，只露出入口；登录后从首页进入才直接展开，避免详情首屏被登录提示占满。
    this.expanded = this.startExpanded && this.signedIn && this.serviceConfigured;
    this.question = this.initialQuestion.slice(0, AI_MAX_QUESTION_LENGTH);
    this.observationText = this.initialObservation.slice(0, AI_MAX_OBSERVATION_LENGTH);
    if (this.initialObservation) {
      this.infoText = this.initialObservation.length > AI_MAX_OBSERVATION_LENGTH ?
        '已带入手账前 300 字，可修改后提问；原手账保持完整。' : '已带入这页手账的问题与观察，可修改后提问。';
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.generation++;
    this.stopTimer();
    if (this.phase === 'waiting') this.onAiCancel();
  }

  private contextChanged(): void {
    // 对象和场景修订由父组件保证；热点变化不取消在途请求，回复仍按发起时的上下文校验。
    if (!this.scope) this.scope = aiKnowledgeScope(this.siteId);
  }

  private online(): boolean {
    return this.signedIn && this.serviceConfigured && this.scope !== undefined;
  }

  private toggle(): void {
    this.expanded = !this.expanded;
  }

  private startTimer(): void {
    this.stopTimer();
    this.startedAt = Date.now();
    this.elapsedSeconds = 0;
    this.timer = setInterval(() => {
      this.elapsedSeconds = Math.max(0, Math.floor((Date.now() - this.startedAt) / 1000));
    }, 250);
  }

  private stopTimer(): void {
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
  }

  private isCurrent(request: AiObservationRequest): boolean {
    return !this.disposed && this.activeRequestId === request.requestId;
  }

  private nextTurns(question: string, answer: string): AiTurn[] {
    const next: AiTurn[] = this.turns.slice();
    next.push({ role: 'user', content: question });
    next.push({ role: 'assistant', content: answer });
    while (next.length > AI_MAX_TURNS) next.shift();
    return next;
  }

  private newRequest(purpose: string, questionText: string, observation: string): AiObservationRequest {
    this.generation++;
    const requestId = `ai-${Date.now()}-${this.generation}`;
    this.activeRequestId = requestId;
    return {
      version: 1, requestId, siteId: this.siteId, sceneRevision: this.sceneRevision,
      hotspotId: this.hotspotId, purpose, question: questionText, turns: this.turns.slice(),
      userObservation: observation
    };
  }

  private applyObserveReply(reply: AiObservationReply, questionText: string): void {
    this.status = reply.status;
    this.answer = reply.answer;
    this.replyFactIds = reply.factIds.slice();
    this.actions = reply.actions.slice();
    this.evidenceFactIds = collectAiReplyFactIds(reply);
    this.evidenceOpen = false;
    this.answerExpanded = false;
    this.errorText = '';
    this.infoText = '';
    this.phase = 'answered';
    this.turns = this.nextTurns(questionText, reply.answer);
    if (!reply.draft) {
      this.draftVisible = false;
    }
  }

  private applyDraftReply(reply: AiObservationReply, questionText: string): void {
    this.status = reply.status;
    this.answer = reply.answer;
    this.replyFactIds = reply.factIds.slice();
    this.actions = reply.actions.slice();
    this.evidenceFactIds = collectAiReplyFactIds(reply);
    this.evidenceOpen = false;
    this.answerExpanded = false;
    this.errorText = '';
    this.infoText = '';
    this.phase = 'answered';
    if (reply.draft) {
      this.draftBody = reply.draft.body;
      this.draftTags = reply.draft.tags.join('，');
      this.draftFactIds = reply.draft.factIds.slice();
      this.draftQuestion = questionText;
      this.draftVisible = true;
      this.draftExpanded = false;
      this.infoText = '草稿已生成，可在编辑器中修改。';
    } else {
      this.draftVisible = false;
      this.infoText = '模型没有返回可采用的草稿，问答记录仍保留。';
    }
  }

  private async runRequest(request: AiObservationRequest, draftMode: boolean, questionText: string): Promise<void> {
    this.phase = 'waiting';
    this.errorText = '';
    this.infoText = '';
    this.status = '';
    this.answer = '';
    this.replyFactIds = [];
    this.actions = [];
    this.evidenceOpen = false;
    this.answerExpanded = false;
    this.evidenceFactIds = [];
    this.draftVisible = false;
    this.draftExpanded = false;
    this.startTimer();
    try {
      const reply = await this.onAiRequest(request);
      if (!this.isCurrent(request)) return;
      if (!acceptAiReply(reply, request, this.siteId, this.sceneRevision, this.activeRequestId)) {
        this.phase = 'error';
        this.errorText = '回答与当前问题或资料版本不一致，本次没有采用，请重试。';
        return;
      }
      if (draftMode) this.applyDraftReply(reply, questionText);
      else this.applyObserveReply(reply, questionText);
    } catch (error) {
      if (!this.isCurrent(request)) return;
      const code = (error as Error).message;
      if (code === 'AI_REQUEST_CANCELLED') {
        this.phase = 'idle';
        this.infoText = '已停止等待，问题仍保留。';
      } else {
        this.phase = 'error';
        this.errorText = aiErrorMessage(code);
      }
    } finally {
      if (this.isCurrent(request)) this.stopTimer();
    }
  }

  private async submit(questionOverride: string = ''): Promise<void> {
    if (this.phase === 'waiting') return;
    if (!this.online()) {
      this.errorText = this.signedIn ? '本机未配置账号服务，在线 AI 暂不可用。' : '登录后可使用在线 AI；手动观察和手写手账不受影响。';
      return;
    }
    const text = (questionOverride || this.question).trim();
    if (!text) {
      this.questionHint = '先写下你想问的问题。';
      return;
    }
    if (text.length > AI_MAX_QUESTION_LENGTH) {
      this.questionHint = `问题最多 ${AI_MAX_QUESTION_LENGTH} 字。`;
      return;
    }
    this.questionHint = '';
    this.question = text;
    this.observationHint = '';
    const request = this.newRequest('observe', text, this.initialObservation ? this.observationText.trim() : '');
    await this.runRequest(request, false, text);
  }

  private async askDraft(): Promise<void> {
    if (this.phase === 'waiting') return;
    if (!this.online()) {
      this.errorText = this.signedIn ? '本机未配置账号服务，在线 AI 暂不可用。' : '登录后可使用在线 AI；手动观察和手写手账不受影响。';
      return;
    }
    const observation = this.observationText.trim();
    if (!observation) {
      this.observationHint = '先写一句你自己的观察，AI 不会替你编造到馆经历。';
      return;
    }
    if (observation.length > AI_MAX_OBSERVATION_LENGTH) {
      this.observationHint = `一句观察最多 ${AI_MAX_OBSERVATION_LENGTH} 字。`;
      return;
    }
    this.observationHint = '';
    const text = this.question.trim() || '把这次观察整理为手账';
    const request = this.newRequest('draft_memory', text, observation);
    await this.runRequest(request, true, text);
  }

  private stopWaiting(): void {
    this.generation++;
    this.activeRequestId = '';
    this.stopTimer();
    this.phase = 'idle';
    this.infoText = '已停止等待，问题仍保留。';
    this.onAiCancel();
  }

  private focusAction(action: AiObservationAction): void {
    if (action.type === 'focus_hotspot' && action.hotspotId) {
      // 先收起键盘，否则软键盘会继续占住下半屏，模型即使滚回上方也看不完整。
      this.questionController.stopEditing();
      this.onFocusHotspot(action.hotspotId);
      this.infoText = `已请求聚焦 · ${action.label}`;
    }
  }

  private toggleEvidence(): void {
    this.evidenceOpen = !this.evidenceOpen;
    if (this.evidenceOpen && this.evidenceFactIds.length === 0) this.evidenceFactIds = this.replyFactIds.slice();
  }

  private factsFor(ids: string[]): AiFactSnapshot[] {
    const facts: AiFactSnapshot[] = [];
    ids.forEach((id: string) => {
      const fact = this.scope?.facts.find((item: AiFactSnapshot) => item.id === id);
      if (fact) facts.push(fact);
    });
    return facts;
  }

  private evidenceFacts(): AiFactSnapshot[] {
    return this.factsFor(this.evidenceFactIds);
  }

  private sourcesFor(fact: AiFactSnapshot): AiSourceScope[] {
    const sources: AiSourceScope[] = [];
    fact.sourceIds.forEach((id: string) => {
      const source = this.scope?.sources.find((item: AiSourceScope) => item.id === id);
      if (source) sources.push(source);
    });
    return sources;
  }

  private hotspotLabel(id: string): string {
    return this.scope?.hotspots.find((item: AiHotspotScope) => item.id === id)?.label || '';
  }

  private objectName(): string {
    return this.scope?.objectName || '这件器物';
  }

  // 只把“聚焦部位”渲染成可点操作；依据由面板统一的“依据 · N 条”开关承载，
  // 避免同一个动作在回答下方出现两次（模型动作一次、固定按钮一次）。
  private focusActions(): AiObservationAction[] {
    return this.actions.filter((action: AiObservationAction) => action.type === 'focus_hotspot' && !!action.hotspotId);
  }

  private factTitles(ids: string[]): string {
    const titles: string[] = [];
    ids.forEach((id: string) => {
      const fact = this.scope?.facts.find((item: AiFactSnapshot) => item.id === id);
      if (fact && !titles.includes(fact.title)) titles.push(fact.title);
    });
    return titles.join('、');
  }

  private statusInk(status: string): Resource {
    if (status === 'insufficient_evidence') return T.yellowInk;
    if (status === 'needs_clarification') return T.muted;
    return T.mintInk;
  }

  private statusSurface(status: string): Resource {
    if (status === 'insufficient_evidence') return T.yellow;
    if (status === 'needs_clarification') return T.soft;
    return T.mint;
  }

  private draftTagList(): string[] {
    return this.draftTags.split(/[,，]/).map((tag: string) => tag.trim())
      .filter((tag: string) => tag.length > 0).slice(0, AI_MAX_DRAFT_TAGS);
  }

  private adoptDraft(): void {
    if (!this.scope || !this.draftBody.trim() || this.draftFactIds.length === 0) return;
    const facts = this.factsFor(this.draftFactIds);
    if (facts.length !== this.draftFactIds.length) {
      this.infoText = '草稿引用的资料已不在当前范围，不能按旧依据保存。';
      return;
    }
    const tags = this.draftTags.split(/[,，]/).map((tag: string) => tag.trim())
      .filter((tag: string) => tag.length > 0).slice(0, 3);
    this.onAdoptDraft({
      question: this.draftQuestion || this.question || '把这次观察整理为手账',
      factIds: this.draftFactIds.slice(), contentRevision: this.scope.contentRevision,
      facts, body: this.draftBody.trim(), tags
    });
    this.draftVisible = false;
    this.infoText = '已交给手账编辑器，保存后生效。';
  }

  private discardDraft(): void {
    this.draftVisible = false;
    this.draftBody = '';
    this.draftTags = '';
    this.draftFactIds = [];
    this.draftExpanded = false;
    this.infoText = '已放弃这份草稿，问答记录仍保留。';
  }

  @Builder
  evidenceCard(fact: AiFactSnapshot) {
    Column({ space: 6 }) {
      Text(fact.title).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
      Text(fact.body).fontSize(F.caption).fontColor(T.ink).lineHeight(21)
      ForEach(this.sourcesFor(fact), (source: AiSourceScope) => {
        Text(`${source.publisher} · ${source.title} · 核验 ${source.checkedAt}`)
          .fontSize(F.caption).fontColor(T.muted).lineHeight(19)
      }, (source: AiSourceScope) => `${fact.id}:${source.id}`)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
      .backgroundColor(T.surface).borderRadius(12).border({ width: 1, color: T.line, radius: 12 })
      .id(`ai-evidence-${fact.id}`)
  }

  @Builder
  evidenceBlock() {
    Column({ space: 10 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.bookmark')).fontSize(15).fontColor([T.mintInk])
        Text('原始资料').fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.mintInk)
        Text('馆方来源 · 不是模型生成').fontSize(F.caption).fontColor(T.muted).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
      ForEach(this.evidenceFacts(), (fact: AiFactSnapshot) => {
        this.evidenceCard(fact)
      }, (fact: AiFactSnapshot) => fact.id)
      if (this.scope?.evidenceLimit) {
        Text(this.scope.evidenceLimit).fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.mint).borderRadius(14)
      .id('ai-evidence-list')
  }

  @Builder
  answerBlock() {
    Column({ space: 10 }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(aiStatusLabel(this.status)).fontSize(F.caption).fontWeight(FontWeight.Medium)
            .fontColor(this.statusInk(this.status)).padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.statusSurface(this.status)).borderRadius(8).id('ai-answer-status')
          Blank()
          if (this.evidenceFactIds.length > 0 || this.replyFactIds.length > 0) {
            // 依据只有一个入口：模型返回的 show_evidence 动作合并到这里，不再重复第二颗按钮。
            Button({ type: ButtonType.Normal }) {
              Row({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.bookmark')).fontSize(14).fontColor([T.mintInk])
                Text(this.evidenceOpen ? '收起依据' :
                  `依据 · ${this.evidenceFactIds.length || this.replyFactIds.length} 条`)
                  .fontSize(F.caption).fontColor(T.mintInk)
              }.padding({ left: 8, right: 8 })
            }.height(30).backgroundColor(this.evidenceOpen ? T.mint : Color.Transparent).borderRadius(8)
              .id('ai-evidence-toggle')
              .accessibilityText(this.evidenceOpen ? '收起依据' : '查看本次回答引用的资料')
              .onClick(() => { this.toggleEvidence(); })
          }
        }.width('100%')
        Text(this.answer).fontSize(F.body).fontColor(T.ink).lineHeight(26).width('100%').id('ai-answer')
          .maxLines(this.answerExpanded ? 999 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.answer.length > 80) {
          Button(this.answerExpanded ? '收起完整解释' : '展开完整解释', { type: ButtonType.Normal })
            .id('ai-answer-toggle').height(30).fontSize(F.caption).fontColor(T.muted)
            .padding({ left: 0, right: 0 }).backgroundColor(Color.Transparent)
            .onClick(() => { this.answerExpanded = !this.answerExpanded; })
        }
        if (this.focusActions().length > 0) {
          // 动作按内容宽度换行：窄屏两个一行，宽屏自然排成一行，不写死百分比宽度。
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.focusActions(), (action: AiObservationAction) => {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.map')).fontSize(15).fontColor([T.mintInk])
                  Text(action.label).fontSize(F.small).fontColor(T.mintInk).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }.padding({ left: 11, right: 11 })
              }.constraintSize({ minHeight: 38 }).padding(0).margin({ right: 8, bottom: 8 })
                .backgroundColor(T.surface).borderRadius(11).border({ width: 1, color: T.line, radius: 11 })
                .id(`ai-action-${action.hotspotId}`)
                .accessibilityText(`聚焦观察部位：${action.label}`)
                .onClick(() => { this.focusAction(action); })
            }, (action: AiObservationAction) => `${action.type}:${action.hotspotId}`)
          }.width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(T.soft).borderRadius(14)
      if (this.evidenceOpen) { this.evidenceBlock() }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  waitingBlock() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        LoadingProgress().width(22).height(22).color(T.mintInk)
        Column({ space: 4 }) {
          Text('正在依据本件资料组织解释').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
          Text(`已等待 ${this.elapsedSeconds} 秒 · 不会自动转动镜头或保存`).fontSize(F.caption).fontColor(T.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      // 三条静态占位只稳定面板高度，不伪造进度或回答内容。
      Column({ space: 7 }) {
        Text('').width('88%').height(9).backgroundColor(T.line).borderRadius(5).opacity(0.55)
        Text('').width('96%').height(9).backgroundColor(T.line).borderRadius(5).opacity(0.55)
        Text('').width('72%').height(9).backgroundColor(T.line).borderRadius(5).opacity(0.55)
      }.width('100%').alignItems(HorizontalAlign.Start)
      Button('停止等待', { type: ButtonType.Normal }).id('ai-stop')
        .width('100%').constraintSize({ minHeight: 38 }).fontSize(F.caption)
        .fontColor(T.mintInk).backgroundColor(T.surface).borderRadius(11)
        .onClick(() => { this.stopWaiting(); })
    }.width('100%').padding(14).backgroundColor(T.mint).borderRadius(14).id('ai-waiting')
  }

  @Builder
  draftBlock() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('把这次发现留下').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
        Text('AI 整理').fontSize(F.caption).fontColor(T.mintInk).padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor(T.mint).borderRadius(7)
      }.width('100%')
      Text('先写一句自己的观察，AI 只帮你整理成可编辑草稿。').fontSize(F.caption).fontColor(T.muted)
        .lineHeight(19).width('100%')
      TextArea({ text: this.observationText,
        placeholder: this.scope?.siteId === 'zz-dahecun' ?
          '例如：我先看两只壶口，再顺着腹部找到那个椭圆通口…' : '例如：我先数到正面四组，转到折角才明白另外四组在哪里…' })
        // 从已保存手账带入较长观察时，要在编辑前看见多行上下文；超出高度仍可在输入框内滚动。
        .constraintSize({ minHeight: 112 }).maxLength(AI_MAX_OBSERVATION_LENGTH).fontSize(F.small)
        .fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft).borderRadius(11).padding(11)
        .border({ width: 1, color: T.line, radius: 11 })
        .id('ai-observation-input').onChange((text: string) => {
          this.observationText = text; this.observationHint = '';
        })
      if (this.observationHint) {
        Text(this.observationHint).fontSize(F.caption).fontColor($r('app.color.danger')).width('100%')
      }
      Button(this.phase === 'waiting' ? '正在整理' : '整理为手账草稿', { type: ButtonType.Normal })
        .id('ai-draft-request').width('100%').constraintSize({ minHeight: 42 }).fontSize(F.small)
        .fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(11).enabled(this.phase !== 'waiting')
        .accessibilityText('把个人观察整理为可编辑的 AI 手账草稿')
        .onClick(() => { this.askDraft(); })
      if (this.draftVisible) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('AI 建议草稿').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).layoutWeight(1)
            Text('可在编辑器中修改').fontSize(F.caption).fontColor(T.muted)
          }.width('100%')
          Text(this.draftBody).fontSize(F.small).fontColor(T.ink).lineHeight(23).width('100%')
            .maxLines(this.draftExpanded ? 999 : 4).textOverflow({ overflow: TextOverflow.Ellipsis })
            .id('ai-draft-body')
          if (this.draftBody.length > 120) {
            Button(this.draftExpanded ? '收起草稿' : '展开完整草稿', { type: ButtonType.Normal })
              .id('ai-draft-toggle').height(30).fontSize(F.caption).fontColor(T.mintInk)
              .padding({ left: 0, right: 0 }).backgroundColor(Color.Transparent)
              .onClick(() => { this.draftExpanded = !this.draftExpanded; })
          }
          if (this.draftTagList().length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.draftTagList(), (tag: string) => {
                Text(`#${tag}`).fontSize(F.caption).fontColor(T.mintInk)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(T.mint).borderRadius(6).margin({ right: 6, bottom: 6 })
              }, (tag: string) => tag)
            }.width('100%')
          }
          Text(`依据：${this.factTitles(this.draftFactIds) || '本件已核资料'}`)
            .fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
          Row({ space: 10 }) {
            Button('采纳并编辑', { type: ButtonType.Normal }).id('ai-draft-adopt').layoutWeight(1)
              .constraintSize({ minHeight: 42 }).fontSize(F.small).fontColor(T.onAccent)
              .backgroundColor(T.accent).borderRadius(11)
              .accessibilityText('采纳这份草稿并打开手账编辑器')
              .onClick(() => this.adoptDraft())
            Button('放弃', { type: ButtonType.Normal }).id('ai-draft-discard')
              .constraintSize({ minHeight: 42 }).fontSize(F.small).fontColor(T.muted)
              .backgroundColor(Color.Transparent).onClick(() => this.discardDraft())
          }.width('100%').alignItems(VerticalAlign.Center)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.soft)
          .borderRadius(12).id('ai-draft-card')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(14).margin({ top: 4 })
      .backgroundColor(T.surface).borderRadius(14).border({ width: 1, color: T.line, radius: 14 })
  }

  @Builder
  inputBlock() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('问这件器物').fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.mintInk).layoutWeight(1)
        Text(`${this.question.length} / ${AI_MAX_QUESTION_LENGTH}`).fontSize(F.caption).fontColor(T.tertiary)
      }.width('100%')
      TextArea({ text: this.question, placeholder: `关于${this.objectName()}，你还想确认什么？`, controller: this.questionController })
        .constraintSize({ minHeight: 76 }).maxLength(AI_MAX_QUESTION_LENGTH).fontSize(F.small).fontColor(T.ink)
        .placeholderColor(T.tertiary).backgroundColor(T.soft).borderRadius(11).padding(11)
        .border({ width: 1, color: T.line, radius: 11 })
        .id('ai-question-input').enabled(this.phase !== 'waiting')
        .accessibilityText(`向 AI 提问，关于${this.objectName()}`)
        .onChange((text: string) => { this.question = text; this.errorText = ''; this.questionHint = ''; })
      if (this.questionHint) {
        Text(this.questionHint).fontSize(F.caption).fontColor($r('app.color.danger')).width('100%')
          .id('ai-question-hint')
      }
      Button(this.phase === 'waiting' ? '等待回答' : '提问', { type: ButtonType.Normal }).id('ai-send')
        .width('100%').constraintSize({ minHeight: 42 }).fontSize(F.small).fontColor(T.onAccent)
        .backgroundColor(T.accent).borderRadius(11).enabled(this.phase !== 'waiting')
        .accessibilityText('发送问题给 AI')
        .onClick(() => { this.submit(); })
    }.width('100%').padding({ top: 2 })
  }

  @Builder
  starters() {
    Column({ space: 8 }) {
      Text('从一个具体问题开始').fontSize(F.caption).fontColor(T.muted).width('100%')
      // 起始问法随对象切换；不能把方鼎的“八组”问法带到双连壶上。
      ForEach(this.scope?.starters || [], (question: string, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 10 }) {
            Text(`0${index + 1}`).fontSize(F.caption).fontColor(T.mintInk).width(22)
            Text(question).fontSize(F.small).fontColor(T.ink).layoutWeight(1).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Start)
              .id(`ai-starter-text-${index}`)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([T.tertiary])
          }.width('100%')
        }.width('100%').constraintSize({ minHeight: 44 }).padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(T.surface).borderRadius(12).border({ width: 1, color: T.line, radius: 12 })
          .id(`ai-starter-${index}`).accessibilityText(`提问：${question}`)
          .onClick(() => { this.submit(question); })
      }, (question: string) => question)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  lockedBlock() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([T.mintInk])
        }.width(34).height(34).borderRadius(11).backgroundColor(T.mint)
          .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        Text(this.signedIn ? '本机未配置账号服务' : '登录后与 AI 一起观察')
          .fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).layoutWeight(1)
      }.width('100%')
      Text(this.signedIn ?
        '在线 AI 暂不可用；手动聚焦、原始资料和手写手账仍可继续。' :
        'AI 只依据本件已核事实解释，资料不足会明确说明，不替代馆方原文。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      if (!this.signedIn) {
        Text('登录入口：我的 → 账号与同步。离线仍可转动模型、查看资料和写手账。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(T.soft).borderRadius(14)
      .id('ai-locked')
  }

  build() {
    Column({ space: 12 }) {
      // 整条标题栏都可点击展开 / 收起，不再只依赖右上角的小按钮。
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(19).fontColor([T.mintInk])
        }.width(36).height(36).borderRadius(12).backgroundColor(T.mint)
          .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        Column({ space: 3 }) {
          Text('AI 观察').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).id('ai-panel-title')
          Text(this.online() ? '在线模型 · 已核事实' :
            (this.signedIn ? '服务未配置 · 本地观察可用' : '登录后可用'))
            .fontSize(F.caption).fontColor(T.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.mintInk])
          .rotate({ angle: this.expanded ? 90 : 0 })
      }.width('100%').alignItems(VerticalAlign.Center)
        .id('ai-panel-toggle')
        .accessibilityText(this.expanded ? '收起 AI 观察' : '展开 AI 观察')
        .onClick(() => this.toggle())

      if (!this.expanded) {
        Column({ space: 7 }) {
          Text(this.scope?.question || '这件器物该从哪里看？').fontSize(F.small).fontColor(T.ink)
            .lineHeight(22).width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 6 }) {
            Text(`和 AI 一起看${this.objectName()}`).fontSize(F.caption).fontColor(T.mintInk).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(14).fontColor([T.mintInk])
          }.width('100%')
        }.width('100%').padding(12).backgroundColor(T.soft).borderRadius(12)
          .onClick(() => this.toggle())
      } else {
        if (!this.online()) {
          this.lockedBlock()
        } else {
          // 当前对象与部位只出现一次，作为整段观察的上下文，不再和回答状态争夺一行。
          Text(this.hotspotId && this.hotspotLabel(this.hotspotId) ?
            `${this.objectName()} · ${this.hotspotLabel(this.hotspotId)}` : this.objectName())
            .fontSize(F.caption).fontColor(T.mintInk).width('100%')
            .padding({ left: 9, right: 9, top: 5, bottom: 5 }).backgroundColor(T.mint).borderRadius(8)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.phase === 'waiting') { this.waitingBlock() }
          if (this.phase === 'error') {
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Text('!').fontSize(F.small).fontWeight(FontWeight.Bold).fontColor($r('app.color.danger'))
                  .width(18).height(18).textAlign(TextAlign.Center).backgroundColor(T.surface).borderRadius(9)
                Text('这次没有生成回答').fontSize(F.small).fontWeight(FontWeight.Medium)
                  .fontColor(T.ink).layoutWeight(1)
              }.width('100%')
              Text(this.errorText).fontSize(F.caption).fontColor($r('app.color.danger')).lineHeight(20).width('100%')
              Row({ space: 10 }) {
                Button('重试', { type: ButtonType.Normal }).id('ai-retry').layoutWeight(1)
                  .constraintSize({ minHeight: 40 }).fontSize(F.small).fontColor(T.accent)
                  .backgroundColor(T.surface).borderRadius(11).border({ width: 1, color: T.accent, radius: 11 })
                  .onClick(() => { this.submit(this.question); })
                Button('手动观察', { type: ButtonType.Normal }).id('ai-error-manual').layoutWeight(1)
                  .constraintSize({ minHeight: 40 }).fontSize(F.small).fontColor(T.muted)
                  .backgroundColor(Color.Transparent).onClick(() => { this.expanded = false; })
              }.width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
              .backgroundColor(T.accentSoft).borderRadius(14).id('ai-error')
          }
          if (this.phase === 'answered') { this.answerBlock() }
          if (this.infoText) {
            Text(this.infoText).fontSize(F.caption).fontColor(T.mintInk).lineHeight(19).width('100%')
              .padding(10).backgroundColor(T.mint).borderRadius(10).id('ai-info')
          }
          if (this.phase === 'idle' && this.turns.length === 0 && !this.errorText && !this.initialQuestion) { this.starters() }
          // 追问输入紧跟回答；草稿是第二步，放在输入之后，避免把“继续问”推到屏幕外。
          this.inputBlock()
          if ((this.phase === 'answered' && this.status === 'grounded') || this.initialObservation) { this.draftBlock() }
          Divider().color(T.line)
          Text(`AI 仅使用本件 ${this.scope?.facts.length || 0} 条已核事实与 ` +
            `${this.scope?.hotspots.length || 0} 个观察部位；资料不足会明确说明。`)
            .fontSize(F.caption).fontColor(T.muted).lineHeight(18).width('100%')
        }
      }
    }.width('100%').padding(16).backgroundColor(T.surface).borderRadius(18)
      .border({ width: 1, color: T.line, radius: 18 }).margin({ top: 4 })
      .id('ai-observation-panel')
  }
}
