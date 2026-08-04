// App Agent internal commands. These IDs are not public AgentCard Skills.
export const REVIEW_SKILL_ID = 'app_review_session';
export const CONFUSION_SKILL_ID = 'app_confusion_practice';

export type LearningTaskMode = 'review' | 'confusion';
export type SkillRouteSource = 'metadata' | 'text' | 'none';

export interface SkillRoute {
  accepted: boolean;
  source: SkillRouteSource;
  skillId?: string;
  mode?: LearningTaskMode;
  reason?: string;
}

const REVIEW_INTENT_TOKENS: string[] = [
  '复习',
  '抽背',
  '背单词',
  '背词',
  '单词',
  '易错词',
  '到期词',
  '继续',
  '恢复'
];

const CONFUSION_INTENT_TOKENS: string[] = ['区别', '辨析', '混淆', '区分', '不同'];

export function routeLearningRequest(userInput: string, explicitSkillId?: string): SkillRoute {
  const normalizedSkillId = explicitSkillId?.trim();
  if (normalizedSkillId) {
    if (normalizedSkillId === REVIEW_SKILL_ID) {
      return {
        accepted: true,
        source: 'metadata',
        skillId: REVIEW_SKILL_ID,
        mode: 'review'
      };
    }
    if (normalizedSkillId === CONFUSION_SKILL_ID) {
      return {
        accepted: true,
        source: 'metadata',
        skillId: CONFUSION_SKILL_ID,
        mode: 'confusion'
      };
    }
    return {
      accepted: false,
      source: 'metadata',
      skillId: normalizedSkillId,
      reason: 'unsupported_skill'
    };
  }

  const normalized = userInput.trim().toLowerCase();
  const isConfusion = normalized.includes('resilient') && normalized.includes('resistant') &&
    CONFUSION_INTENT_TOKENS.some((token: string): boolean => normalized.includes(token));
  if (isConfusion) {
    return {
      accepted: true,
      source: 'text',
      skillId: CONFUSION_SKILL_ID,
      mode: 'confusion'
    };
  }

  const isReview = REVIEW_INTENT_TOKENS.some((token: string): boolean => normalized.includes(token));
  if (isReview) {
    return {
      accepted: true,
      source: 'text',
      skillId: REVIEW_SKILL_ID,
      mode: 'review'
    };
  }

  return {
    accepted: false,
    source: 'none',
    reason: normalized.length === 0 ? 'empty_input' : 'unsupported_intent'
  };
}
