import {
  CONFUSION_SKILL_ID,
  LearningTaskMode,
  REVIEW_SKILL_ID,
  routeLearningRequest,
  SkillRoute
} from './SkillRouter';
import {
  CONFUSION_HINT,
  CONFUSION_PAIR,
  CONFUSION_SCENARIOS,
  REVIEW_WORDS,
  ReviewWordContent
} from './LearningContent';

export interface ReviewAttempt {
  word: string;
  outcome: 'know' | 'hinted' | 'miss';
  hintLevel: number;
}

export interface ConfusionAttempt {
  pair: string[];
  choice: string;
  correct: boolean;
  hintLevel: number;
}

export interface ReviewSessionSnapshot {
  schemaVersion: number;
  taskId: string;
  contextId?: string;
  mode: LearningTaskMode;
  currentIndex: number;
  hintLevel: number;
  attempts: ReviewAttempt[];
  confusionAttempts: ConfusionAttempt[];
  updatedAt: string;
}

export interface ReviewSessionRepository {
  load(taskId: string): ReviewSessionSnapshot | undefined;
  loadLatestByContext(contextId: string): ReviewSessionSnapshot | undefined;
  save(session: ReviewSessionSnapshot): void;
  delete(taskId: string): void;
  deleteByContext(contextId: string): number;
}

export interface ReviewTaskResult {
  completed: boolean;
  message: string;
  artifact?: string;
  artifactName?: string;
  artifactType?: string;
  skillId?: string;
  restored?: boolean;
  rejected?: boolean;
  rejectionReason?: string;
}

const CONFUSION_PROMPT = CONFUSION_SCENARIOS[0].question;
const CONFUSION_EXPLANATION = CONFUSION_SCENARIOS[0].explanation;

class InMemoryReviewSessionRepository implements ReviewSessionRepository {
  private readonly sessions: Map<string, ReviewSessionSnapshot> = new Map();

  load(taskId: string): ReviewSessionSnapshot | undefined {
    return this.sessions.get(taskId);
  }

  loadLatestByContext(contextId: string): ReviewSessionSnapshot | undefined {
    let latest: ReviewSessionSnapshot | undefined;
    this.sessions.forEach((session: ReviewSessionSnapshot): void => {
      if (session.contextId === contextId && (!latest || session.updatedAt > latest.updatedAt)) {
        latest = session;
      }
    });
    return latest;
  }

  save(session: ReviewSessionSnapshot): void {
    this.sessions.set(session.taskId, session);
  }

  delete(taskId: string): void {
    this.sessions.delete(taskId);
  }

  deleteByContext(contextId: string): number {
    const taskIds: string[] = [];
    this.sessions.forEach((session: ReviewSessionSnapshot, taskId: string): void => {
      if (session.contextId === contextId) taskIds.push(taskId);
    });
    taskIds.forEach((taskId: string): void => {
      this.sessions.delete(taskId);
    });
    return taskIds.length;
  }
}

export class ReviewTaskEngine {
  private readonly repository: ReviewSessionRepository;

  constructor(repository: ReviewSessionRepository = new InMemoryReviewSessionRepository()) {
    this.repository = repository;
  }

  handle(
    taskId: string,
    contextId: string | undefined,
    relatedTaskIds: string[],
    userInput: string,
    explicitSkillId?: string
  ): ReviewTaskResult {
    const normalized = userInput.trim().toLowerCase();
    let session = this.repository.load(taskId);
    if (!session) {
      const explicitRoute: SkillRoute | undefined = explicitSkillId
        ? routeLearningRequest('', explicitSkillId)
        : undefined;
      if (explicitRoute && !explicitRoute.accepted) {
        return this.reject(explicitRoute);
      }
      const recovered = this.findRelatedSession(
        taskId,
        contextId,
        relatedTaskIds,
        this.isResumeCommand(normalized),
        explicitRoute?.mode
      );
      if (recovered) {
        this.repository.delete(recovered.taskId);
        recovered.taskId = taskId;
        if (contextId) recovered.contextId = contextId;
        this.touch(recovered);
        this.repository.save(recovered);
        return {
          completed: false,
          restored: true,
          message: this.buildResumeMessage(recovered)
        };
      }

      const route: SkillRoute = explicitRoute ?? routeLearningRequest(normalized);
      if (!route.accepted || !route.mode || !route.skillId) {
        return this.reject(route);
      }

      session = {
        schemaVersion: 2,
        taskId,
        contextId,
        mode: route.mode,
        currentIndex: 0,
        hintLevel: 0,
        attempts: [],
        confusionAttempts: [],
        updatedAt: new Date().toISOString()
      };
      this.repository.save(session);
      if (session.mode === 'confusion') {
        return {
          completed: false,
          skillId: CONFUSION_SKILL_ID,
          message: CONFUSION_PROMPT
        };
      }
      return {
        completed: false,
        skillId: REVIEW_SKILL_ID,
        message: `本轮共 ${REVIEW_WORDS.length} 个词。${REVIEW_WORDS[0].prompt}`
      };
    }

    if (contextId && !session.contextId) {
      session.contextId = contextId;
    }

    if (this.isResumeCommand(normalized)) {
      this.persist(session);
      return {
        completed: false,
        restored: true,
        message: this.buildResumeMessage(session)
      };
    }

    if (session.mode === 'confusion') {
      return this.handleConfusion(taskId, session, normalized);
    }

    if (this.isFinishCommand(normalized)) {
      return this.complete(taskId, session, true);
    }

    const word = REVIEW_WORDS[session.currentIndex];
    if (this.isHintRequest(normalized)) {
      if (session.hintLevel < word.hints.length) {
        session.hintLevel += 1;
        this.persist(session);
        return {
          completed: false,
          message: word.hints[session.hintLevel - 1]
        };
      }
      return this.recordAndAdvance(taskId, session, 'miss', `仍未想起。${word.word}：${word.answer}。`);
    }

    if (this.matchesAnswer(word, normalized)) {
      const outcome: 'know' | 'hinted' = session.hintLevel === 0 ? 'know' : 'hinted';
      const evidence = outcome === 'know' ? '独立想起' : `提示 ${session.hintLevel} 后想起`;
      return this.recordAndAdvance(taskId, session, outcome, `回答已记录为“${evidence}”。${word.word}：${word.answer}。`);
    }

    if (session.hintLevel < word.hints.length) {
      session.hintLevel += 1;
      this.persist(session);
      return {
        completed: false,
        message: `这个回答还不准确。${word.hints[session.hintLevel - 1]}`
      };
    }

    return this.recordAndAdvance(taskId, session, 'miss', `两层提示后仍未答对。${word.word}：${word.answer}。`);
  }

  cancel(taskId: string): void {
    this.repository.delete(taskId);
  }

  clearContext(contextId: string): number {
    return this.repository.deleteByContext(contextId);
  }

  getSkillId(taskId: string): string | undefined {
    const session = this.repository.load(taskId);
    if (!session) return undefined;
    return session.mode === 'confusion' ? CONFUSION_SKILL_ID : REVIEW_SKILL_ID;
  }

  private findRelatedSession(
    taskId: string,
    contextId: string | undefined,
    relatedTaskIds: string[],
    allowContextFallback: boolean,
    expectedMode?: LearningTaskMode
  ): ReviewSessionSnapshot | undefined {
    for (let index = 0; index < relatedTaskIds.length; index += 1) {
      const relatedTaskId = relatedTaskIds[index];
      if (relatedTaskId === taskId) continue;
      const related = this.repository.load(relatedTaskId);
      if (related && (!expectedMode || related.mode === expectedMode)) return related;
    }
    const contextual = contextId && allowContextFallback
      ? this.repository.loadLatestByContext(contextId)
      : undefined;
    return contextual && (!expectedMode || contextual.mode === expectedMode) ? contextual : undefined;
  }

  private reject(route: SkillRoute): ReviewTaskResult {
    return {
      completed: false,
      rejected: true,
      rejectionReason: route.reason ?? 'unsupported_intent',
      skillId: route.skillId,
      message: '我目前只支持到期/易错词抽背，以及 resilient 与 resistant 的辨析。你可以说“陪我复习今天到期的单词”。'
    };
  }

  private buildResumeMessage(session: ReviewSessionSnapshot): string {
    if (session.mode === 'confusion') {
      const hint = session.hintLevel > 0 ? `已使用提示 ${session.hintLevel} / 1。` : '';
      return `已恢复易混词辨析：${CONFUSION_PAIR.join(' / ')}。${hint}${CONFUSION_PROMPT}`;
    }
    const word = REVIEW_WORDS[session.currentIndex];
    const hint = session.hintLevel > 0 ? `，已用提示 ${session.hintLevel} / ${word.hints.length}` : '';
    return `已恢复同一轮学习：完成 ${session.attempts.length} / ${REVIEW_WORDS.length}，当前是 ${word.word}${hint}。${word.prompt}`;
  }

  private recordAndAdvance(
    taskId: string,
    session: ReviewSessionSnapshot,
    outcome: 'know' | 'hinted' | 'miss',
    feedback: string
  ): ReviewTaskResult {
    const word = REVIEW_WORDS[session.currentIndex];
    session.attempts.push({
      word: word.word,
      outcome,
      hintLevel: session.hintLevel
    });
    session.currentIndex += 1;
    session.hintLevel = 0;

    if (session.currentIndex >= REVIEW_WORDS.length) {
      return this.complete(taskId, session, false, feedback);
    }

    this.persist(session);
    return {
      completed: false,
      message: `${feedback} 下一词：${REVIEW_WORDS[session.currentIndex].prompt}`
    };
  }

  private complete(
    taskId: string,
    session: ReviewSessionSnapshot,
    partial: boolean,
    feedback: string = ''
  ): ReviewTaskResult {
    let independentRecall = 0;
    let hintedRecall = 0;
    let missed = 0;
    session.attempts.forEach((attempt: ReviewAttempt): void => {
      if (attempt.outcome === 'know') independentRecall += 1;
      else if (attempt.outcome === 'hinted') hintedRecall += 1;
      else missed += 1;
    });

    const weakAttempt = session.attempts.find((attempt: ReviewAttempt): boolean => attempt.outcome !== 'know');
    const nextActionWord = weakAttempt?.word ?? REVIEW_WORDS[0].word;
    const artifact = JSON.stringify({
      type: 'learning.review-summary.v1',
      sessionId: taskId,
      contextId: session.contextId,
      partial,
      planned: REVIEW_WORDS.length,
      completed: session.attempts.length,
      independentRecall,
      hintedRecall,
      missed,
      attempts: session.attempts,
      nextAction: `review_${nextActionWord}`,
      nextReviewAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    });

    this.repository.delete(taskId);
    const prefix = feedback ? `${feedback} ` : '';
    return {
      completed: true,
      message: `${prefix}本轮已${partial ? '提前结束' : '完成'}：${session.attempts.length} / ${REVIEW_WORDS.length} 个词，学习证据已经生成。`,
      artifact,
      artifactName: '本轮复习摘要',
      artifactType: 'learning.review-summary.v1',
      skillId: REVIEW_SKILL_ID
    };
  }

  private handleConfusion(
    taskId: string,
    session: ReviewSessionSnapshot,
    normalized: string
  ): ReviewTaskResult {
    if (this.isHintRequest(normalized)) {
      session.hintLevel = 1;
      this.persist(session);
      return {
        completed: false,
        message: CONFUSION_HINT
      };
    }

    const choseResilient = normalized.includes('resilient');
    const choseResistant = normalized.includes('resistant');
    if (!choseResilient && !choseResistant) {
      session.hintLevel = 1;
      this.persist(session);
      return {
        completed: false,
        message: `请先在 resilient 和 resistant 中选一个。${CONFUSION_HINT}`
      };
    }

    const choice = choseResilient ? 'resilient' : 'resistant';
    const correct = choice === CONFUSION_SCENARIOS[0].answer;
    session.confusionAttempts.push({
      pair: CONFUSION_PAIR,
      choice,
      correct,
      hintLevel: session.hintLevel
    });
    const artifact = JSON.stringify({
      type: 'learning.confusion-repair.v1',
      sessionId: taskId,
      contextId: session.contextId,
      pair: CONFUSION_PAIR,
      prompt: CONFUSION_PROMPT,
      choice,
      correct,
      hintLevel: session.hintLevel,
      explanation: CONFUSION_EXPLANATION,
      nextReviewAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    });
    this.repository.delete(taskId);
    return {
      completed: true,
      message: `${correct ? '判断正确。' : '这次仍有混淆。'}${CONFUSION_EXPLANATION} 已安排 24 小时后用新情境复测。`,
      artifact,
      artifactName: '易混词辨析结果',
      artifactType: 'learning.confusion-repair.v1',
      skillId: CONFUSION_SKILL_ID
    };
  }

  private persist(session: ReviewSessionSnapshot): void {
    this.touch(session);
    this.repository.save(session);
  }

  private touch(session: ReviewSessionSnapshot): void {
    session.updatedAt = new Date().toISOString();
  }

  private matchesAnswer(word: ReviewWordContent, normalized: string): boolean {
    if (!normalized) return false;
    return word.acceptedTokens.some((token: string): boolean => normalized.includes(token));
  }

  private isHintRequest(normalized: string): boolean {
    return ['提示', '不会', '不知道', '卡住', '模糊', '再给一层', '没想起']
      .some((token: string): boolean => normalized.includes(token));
  }

  private isFinishCommand(normalized: string): boolean {
    return ['结束复习', '结束本轮', '生成复盘', '查看复盘'].includes(normalized);
  }

  private isResumeCommand(normalized: string): boolean {
    return ['继续', '继续复习', '继续刚才的复习', '恢复复习', '接着复习'].includes(normalized);
  }

}
