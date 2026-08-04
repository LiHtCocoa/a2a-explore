import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  ReviewSessionRepository,
  ReviewSessionSnapshot
} from '../domain/ReviewTaskEngine';

const STORE_NAME = 'echo_word_review_sessions';
const STORE_KEY = 'sessions_v1';

export class PreferencesReviewSessionRepository implements ReviewSessionRepository {
  private readonly store: preferences.Preferences;

  constructor(context: common.Context) {
    this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
  }

  load(taskId: string): ReviewSessionSnapshot | undefined {
    return this.readAll().find((session: ReviewSessionSnapshot): boolean => session.taskId === taskId);
  }

  loadLatestByContext(contextId: string): ReviewSessionSnapshot | undefined {
    let latest: ReviewSessionSnapshot | undefined;
    this.readAll().forEach((session: ReviewSessionSnapshot): void => {
      if (session.contextId === contextId && (!latest || session.updatedAt > latest.updatedAt)) {
        latest = session;
      }
    });
    return latest;
  }

  save(session: ReviewSessionSnapshot): void {
    const sessions = this.readAll().filter(
      (candidate: ReviewSessionSnapshot): boolean => candidate.taskId !== session.taskId
    );
    sessions.push(session);
    this.writeAll(sessions);
  }

  delete(taskId: string): void {
    const sessions = this.readAll();
    const remaining = sessions.filter(
      (session: ReviewSessionSnapshot): boolean => session.taskId !== taskId
    );
    if (remaining.length !== sessions.length) this.writeAll(remaining);
  }

  deleteByContext(contextId: string): number {
    const sessions = this.readAll();
    const remaining = sessions.filter(
      (session: ReviewSessionSnapshot): boolean => session.contextId !== contextId
    );
    const deleted = sessions.length - remaining.length;
    if (deleted > 0) this.writeAll(remaining);
    return deleted;
  }

  private readAll(): ReviewSessionSnapshot[] {
    try {
      const stored = this.store.getSync(STORE_KEY, '[]');
      if (typeof stored !== 'string') return [];
      const sessions = JSON.parse(stored) as ReviewSessionSnapshot[];
      const normalized: ReviewSessionSnapshot[] = [];
      sessions.forEach((session: ReviewSessionSnapshot): void => {
        const candidate = this.normalize(session);
        if (candidate) normalized.push(candidate);
      });
      return normalized;
    } catch (error) {
      throw new Error(`read review sessions failed: ${JSON.stringify(error)}`);
    }
  }

  private writeAll(sessions: ReviewSessionSnapshot[]): void {
    try {
      this.store.putSync(STORE_KEY, JSON.stringify(sessions));
      this.store.flushSync();
    } catch (error) {
      throw new Error(`write review sessions failed: ${JSON.stringify(error)}`);
    }
  }

  private isValid(session: ReviewSessionSnapshot): boolean {
    const validModeState = session.mode === 'review'
      ? session.currentIndex >= 0 && session.currentIndex < 3 && session.hintLevel <= 2 && session.attempts.length <= 3
      : session.mode === 'confusion' && session.currentIndex === 0 && session.hintLevel <= 1 &&
        session.confusionAttempts.length <= 1;
    return session.schemaVersion === 2 &&
      session.taskId.length > 0 &&
      session.hintLevel >= 0 &&
      session.updatedAt.length > 0 &&
      validModeState;
  }

  private normalize(session: ReviewSessionSnapshot): ReviewSessionSnapshot | undefined {
    if (session.schemaVersion === 1) {
      session.schemaVersion = 2;
      session.mode = 'review';
      session.confusionAttempts = [];
    }
    if (!session.confusionAttempts) session.confusionAttempts = [];
    return this.isValid(session) ? session : undefined;
  }
}
