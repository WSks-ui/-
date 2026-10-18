import type { AiFactSnapshot } from '../domain/ArchiveDomain';
import type {
  AiDraftAdoption, AiHotspotScope, AiKnowledgeScope, AiObservationAction, AiObservationReply,
  AiObservationRequest, AiSourceScope, AiTurn
} from '../domain/AiObservation';
import {
  AI_MAX_OBSERVATION_LENGTH, AI_MAX_QUESTION_LENGTH, AI_MAX_TURNS, acceptAiReply, aiErrorMessage,
  aiStatusLabel, collectAiReplyFactIds
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
      this.errorText = '先写下你想问的问题。';
      return;
    }
    if (text.length > AI_MAX_QUESTION_LENGTH) {
      this.errorText = `问题最多 ${AI_MAX_QUESTION_LENGTH} 字。`;
      return;
    }
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

  private showEvidence(action: AiObservationAction): void {
    if (action.type === 'show_evidence') {
      this.evidenceFactIds = action.factIds.slice();
    }
    this.evidenceOpen = true;
  }

  private toggleEvidence(): void {
    this.evidenceOpen = !this.evidenceOpen;
    if (this.evidenceOpen && this.evidenceFactIds.length === 0) this.evidenceFactIds = this.replyFactIds.slice();
  }

  private hasEvidenceAction(): boolean {
    return this.actions.some((action: AiObservationAction) => action.type === 'show_evidence');
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
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('原始资料').fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.mintInk)
        Text('馆方来源 · 不是模型生成').fontSize(F.caption).fontColor(T.muted)
        Blank()
        Button('收起', { type: ButtonType.Normal }).height(30).fontSize(F.caption)
          .fontColor(T.mintInk).backgroundColor(Color.Transparent).onClick(() => { this.evidenceOpen = false; })
      }.width('100%')
      ForEach(this.evidenceFacts(), (fact: AiFactSnapshot) => {
        this.evidenceCard(fact)
      }, (fact: AiFactSnapshot) => fact.id)
      Text(this.scope?.evidenceLimit || '').fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.mint).borderRadius(14)
      .id('ai-evidence-list')
  }

  @Builder
  answerBlock() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(aiStatusLabel(this.status)).fontSize(F.caption).fontWeight(FontWeight.Medium)
          .fontColor(T.accent).padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(T.accentSoft).borderRadius(7).id('ai-answer-status')
        if (this.status === 'insufficient_evidence') {
          Text('当前资料不足，未作推测').fontSize(F.caption).fontColor(T.yellowInk)
        }
        Blank()
        if (this.hotspotId) {
          Text(`当前观察 · ${this.hotspotLabel(this.hotspotId)}`).fontSize(F.caption).fontColor(T.muted).maxLines(1)
        }
      }.width('100%')
      Text(this.answer).fontSize(F.body).fontColor(T.ink).lineHeight(26).width('100%').id('ai-answer')
        .maxLines(this.answerExpanded ? 999 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.actions.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.actions, (action: AiObservationAction, index: number) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 7 }) {
                SymbolGlyph(action.type === 'focus_hotspot' ? $r('sys.symbol.map') : $r('sys.symbol.bookmark'))
                  .fontSize(16).fontColor([T.accent])
                Text(action.label).fontSize(F.small).fontColor(T.accent).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }.width('100%').justifyContent(FlexAlign.Start)
            }.width('100%').height(40).padding({ left: 12, right: 12 })
              .backgroundColor(T.surface).borderRadius(11).border({ width: 1, color: T.line, radius: 11 })
              .id(`ai-action-${index}`)
              .onClick(() => {
                if (action.type === 'focus_hotspot') this.focusAction(action);
                else this.showEvidence(action);
              })
          }, (action: AiObservationAction, index: number) => `${index}:${action.type}:${action.hotspotId}`)
        }.width('100%')
      }
      if (this.answer.length > 80) {
        Button(this.answerExpanded ? '收起完整解释' : '展开完整解释', { type: ButtonType.Normal })
          .id('ai-answer-toggle').height(32).fontSize(F.caption).fontColor(T.muted)
          .backgroundColor(Color.Transparent).onClick(() => { this.answerExpanded = !this.answerExpanded; })
      }
      if ((!this.hasEvidenceAction() || this.evidenceOpen) &&
        (this.replyFactIds.length > 0 || this.evidenceFactIds.length > 0)) {
        Button(this.evidenceOpen ? '收起依据' : `查看本次依据 · ${this.evidenceFactIds.length || this.replyFactIds.length} 条`)
          .id('ai-evidence-toggle').width('100%').height(38).fontSize(F.caption)
          .fontColor(T.mintInk).backgroundColor(T.mint).borderRadius(11).onClick(() => this.toggleEvidence())
      }
      if (this.evidenceOpen) { this.evidenceBlock() }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.soft).borderRadius(14)
  }

  @Builder
  waitingBlock() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        LoadingProgress().width(22).height(22).color(T.accent)
        Column({ space: 3 }) {
          Text('AI 正在依据本件资料组织解释').fontSize(F.small).fontColor(T.ink)
          Text(`已等待 ${this.elapsedSeconds} 秒 · 不会自动转动镜头或保存`).fontSize(F.caption).fontColor(T.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Button('停止等待', { type: ButtonType.Normal }).id('ai-stop').width('100%').height(38).fontSize(F.caption)
        .fontColor(T.accent).backgroundColor(T.surface).borderRadius(11).onClick(() => this.stopWaiting())
    }.width('100%').padding(12).backgroundColor(T.accentSoft).borderRadius(14).id('ai-waiting')
  }

  @Builder
  draftBlock() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('把这次发现留下').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).layoutWeight(1)
        Text('AI 草稿可编辑').fontSize(F.caption).fontColor(T.accent)
      }.width('100%')
      Text('写下你自己的观察，AI 帮你整理。').fontSize(F.caption).fontColor(T.muted)
        .lineHeight(19).width('100%')
      TextArea({ text: this.observationText, placeholder: '例如：我先数到正面四组，转到折角才明白另外四组在哪里…' })
        // 从已保存手账带入较长观察时，要在编辑前看见多行上下文；超出高度仍可在输入框内滚动。
        .height(116).maxLength(AI_MAX_OBSERVATION_LENGTH).fontSize(F.small).fontColor(T.ink)
        .placeholderColor(T.muted).backgroundColor(T.surface).borderRadius(11).padding(10)
        .id('ai-observation-input').onChange((text: string) => {
          this.observationText = text; this.observationHint = '';
        })
      if (this.observationHint) {
        Text(this.observationHint).fontSize(F.caption).fontColor($r('app.color.danger')).width('100%')
      }
      Button(this.phase === 'waiting' ? '正在整理' : '整理为手账草稿', { type: ButtonType.Normal })
        .id('ai-draft-request').width('100%').height(40).fontSize(F.small).fontColor(T.accent)
        .backgroundColor(T.accentSoft).borderRadius(11).enabled(this.phase !== 'waiting')
        .onClick(() => { this.askDraft(); })
      if (this.draftVisible) {
        Column({ space: 8 }) {
          Text('AI 建议草稿 · 可在编辑器中继续修改').fontSize(F.caption).fontWeight(FontWeight.Medium)
            .fontColor(T.accent).width('100%')
          Text(this.draftBody).fontSize(F.small).fontColor(T.ink).lineHeight(23).width('100%')
            .id('ai-draft-body')
          if (this.draftTags.trim()) {
            Text(`建议标签：${this.draftTags}`).fontSize(F.caption).fontColor(T.muted).width('100%')
          }
          Text(`参考事实：${this.draftFactIds.join(' · ')}`).fontSize(F.caption).fontColor(T.muted).width('100%')
          Row({ space: 8 }) {
            Button('采纳并编辑', { type: ButtonType.Normal }).id('ai-draft-adopt').layoutWeight(1).height(40)
              .fontSize(F.small).fontColor(T.onAccent).backgroundColor(T.accent).borderRadius(11)
              .onClick(() => this.adoptDraft())
            Button('放弃草稿', { type: ButtonType.Normal }).id('ai-draft-discard').layoutWeight(1).height(40)
              .fontSize(F.small).fontColor(T.accent).backgroundColor(T.surface).borderRadius(11)
              .onClick(() => this.discardDraft())
          }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.surface)
          .borderRadius(12).border({ width: 1, color: T.line, radius: 12 }).id('ai-draft-card')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12).margin({ top: 4 })
      .backgroundColor(T.surface).borderRadius(14).border({ width: 1, color: T.line, radius: 14 })
  }

  @Builder
  inputBlock() {
    Column({ space: 8 }) {
      TextArea({ text: this.question, placeholder: '问一个关于这件方鼎的具体问题…', controller: this.questionController })
        .height(78).maxLength(AI_MAX_QUESTION_LENGTH).fontSize(F.small).fontColor(T.ink)
        .placeholderColor(T.muted).backgroundColor(T.surface).borderRadius(11).padding(10)
        .id('ai-question-input').enabled(this.phase !== 'waiting')
        .onChange((text: string) => { this.question = text; this.errorText = ''; })
      Row({ space: 8 }) {
        Text(`${this.question.length} / ${AI_MAX_QUESTION_LENGTH}`).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
        Button(this.phase === 'waiting' ? '等待中' : '提问', { type: ButtonType.Normal }).id('ai-send')
          .height(40).padding({ left: 18, right: 18 }).fontSize(F.small).fontColor(T.onAccent)
          .backgroundColor(T.accent).borderRadius(11).enabled(this.phase !== 'waiting')
          .onClick(() => { this.submit(); })
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding(12).backgroundColor(T.soft).borderRadius(14)
  }

  @Builder
  starters() {
    Column({ space: 6 }) {
      Text('试试这样问').fontSize(F.caption).fontColor(T.muted).width('100%')
      Button('只有四面，八组是怎么数出来的？', { type: ButtonType.Normal }).id('ai-starter-0')
        .width('100%').height(36).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.surface)
        .borderRadius(9).onClick(() => { this.submit('只有四面，八组是怎么数出来的？'); })
      Button('我只看到四个，带我看看另外几个。', { type: ButtonType.Normal }).id('ai-starter-1')
        .width('100%').height(36).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.surface)
        .borderRadius(9).onClick(() => { this.submit('我只看到四个，带我看看另外几个。'); })
      Button('那些小圆点也算八组里面的吗？', { type: ButtonType.Normal }).id('ai-starter-2')
        .width('100%').height(36).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.surface)
        .borderRadius(9).onClick(() => { this.submit('那些小圆点也算八组里面的吗？'); })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  lockedBlock() {
    Column({ space: 6 }) {
      Text(this.signedIn ? '本机未配置账号服务' : '登录后可与 AI 一起观察').fontSize(F.small)
        .fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
      Text(this.signedIn ?
        '在线 AI 暂不可用；手动聚焦、原始资料和手写手账仍可继续。' :
        '在线 AI 只读取本件已核事实并引导观察；游客仍可手动转动模型、查看资料和写手账。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.soft).borderRadius(12)
      .id('ai-locked')
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(21).fontColor([T.accent])
        }.width(40).height(40).borderRadius(13).backgroundColor(T.accentSoft)
          .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        Column({ space: 3 }) {
          Text('AI 观察导览').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).id('ai-panel-title')
          Text(this.online() ? '在线模型 · 本件已核事实' : (this.signedIn ? '服务未配置 · 本地观察可用' : '登录后可用'))
            .fontSize(F.caption).fontColor(T.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.expanded ? '收起' : '展开', { type: ButtonType.Normal }).id('ai-panel-toggle')
          .height(34).padding({ left: 12, right: 12 }).fontSize(F.caption).fontColor(T.accent)
          .backgroundColor(T.accentSoft).borderRadius(10).onClick(() => this.toggle())
      }.width('100%').alignItems(VerticalAlign.Center)
      if (!this.expanded) {
        Text('“四面方鼎，为什么有八组上腹兽面纹？” 让 AI 带你找壁面正中与四个折角。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      } else {
        if (!this.online()) {
          this.lockedBlock()
        } else {
          if (this.phase === 'waiting') { this.waitingBlock() }
          if (this.phase === 'error') {
            Column({ space: 8 }) {
              Text(this.errorText).fontSize(F.caption).fontColor($r('app.color.danger')).lineHeight(20).width('100%')
              Button('重试这次提问', { type: ButtonType.Normal }).id('ai-retry').width('100%').height(38)
                .fontSize(F.caption).fontColor(T.accent).backgroundColor(T.surface).borderRadius(11)
                .onClick(() => { this.submit(this.question); })
            }.width('100%').padding(12).backgroundColor(T.accentSoft).borderRadius(12).id('ai-error')
          }
          if (this.phase === 'answered') { this.answerBlock() }
          if (this.infoText) {
            Text(this.infoText).fontSize(F.caption).fontColor(T.mintInk).lineHeight(19).width('100%')
              .padding(10).backgroundColor(T.mint).borderRadius(10).id('ai-info')
          }
          if (this.phase === 'idle' && this.turns.length === 0 && !this.errorText && !this.initialQuestion) { this.starters() }
          if ((this.phase === 'answered' && this.status === 'grounded') || this.initialObservation) { this.draftBlock() }
          this.inputBlock()
        }
      }
    }.width('100%').padding(14).backgroundColor(T.surface).borderRadius(18)
      .border({ width: 1, color: T.line, radius: 18 }).margin({ top: 4 })
      .id('ai-observation-panel')
  }
}
