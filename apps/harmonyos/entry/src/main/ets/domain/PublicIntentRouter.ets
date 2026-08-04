export const START_REVIEW_SKILL_ID = 'start_word_review_in_app';
export const QUICK_CONFUSION_SKILL_ID = 'quick_word_confusion_qa';
export const PRACTICE_CONFUSION_SKILL_ID = 'practice_word_confusion_in_app';

export type PublicLearningIntent =
  'START_REVIEW_IN_APP' |
  'QUICK_CONFUSION_QA' |
  'PRACTICE_CONFUSION_IN_APP' |
  'SCHEDULE_REVIEW_WITH_SYSTEM' |
  'ENABLE_SYSTEM_COMPANION';

export type InteractionMode =
  'APP_HANDOFF' |
  'SYSTEM_RESULT' |
  'SYSTEM_CAPABILITY' |
  'MINIMAL_PROJECTION';

export interface PublicIntentRoute {
  accepted: boolean;
  source: 'metadata' | 'text' | 'none';
  intent?: PublicLearningIntent;
  skillId?: string;
  interactionMode?: InteractionMode;
  reason?: string;
}

const REVIEW_TOKENS: string[] = ['复习', '抽背', '背单词', '背词', '易错词', '到期词', '继续上次'];
const CONFUSION_TOKENS: string[] = ['区别', '不同', '辨析', '混淆', '区分', '解释'];
const PRACTICE_TOKENS: string[] = ['练习', '情境', '真正区分', '帮我区分', '用一题', '测试我'];
const SCHEDULE_TOKENS: string[] = ['提醒', '闹钟', '每天晚上', '定时', '计划复习'];
const COMPANION_TOKENS: string[] = ['小艺显示进度', '系统伴随', '离开应用后继续', '退出应用后继续'];

export function routePublicIntent(userInput: string, explicitId?: string): PublicIntentRoute {
  const explicit = explicitId?.trim();
  if (explicit) return routeExplicit(explicit);

  const normalized = userInput.trim().toLowerCase();
  if (COMPANION_TOKENS.some((token: string): boolean => normalized.includes(token))) {
    return {
      accepted: false,
      source: 'text',
      intent: 'ENABLE_SYSTEM_COMPANION',
      interactionMode: 'MINIMAL_PROJECTION',
      reason: 'system_companion_not_verified'
    };
  }
  if (SCHEDULE_TOKENS.some((token: string): boolean => normalized.includes(token))) {
    return {
      accepted: false,
      source: 'text',
      intent: 'SCHEDULE_REVIEW_WITH_SYSTEM',
      interactionMode: 'SYSTEM_CAPABILITY',
      reason: 'system_capability_not_verified'
    };
  }

  const hasPair = normalized.includes('resilient') && normalized.includes('resistant');
  if (hasPair && PRACTICE_TOKENS.some((token: string): boolean => normalized.includes(token))) {
    return accepted(
      'PRACTICE_CONFUSION_IN_APP',
      PRACTICE_CONFUSION_SKILL_ID,
      'APP_HANDOFF',
      'text'
    );
  }
  if (hasPair && CONFUSION_TOKENS.some((token: string): boolean => normalized.includes(token))) {
    return accepted('QUICK_CONFUSION_QA', QUICK_CONFUSION_SKILL_ID, 'SYSTEM_RESULT', 'text');
  }
  if (REVIEW_TOKENS.some((token: string): boolean => normalized.includes(token))) {
    return accepted('START_REVIEW_IN_APP', START_REVIEW_SKILL_ID, 'APP_HANDOFF', 'text');
  }
  return {
    accepted: false,
    source: 'none',
    reason: normalized.length === 0 ? 'empty_input' : 'unsupported_intent'
  };
}

function routeExplicit(explicit: string): PublicIntentRoute {
  if (explicit === START_REVIEW_SKILL_ID || explicit === 'START_REVIEW_IN_APP') {
    return accepted('START_REVIEW_IN_APP', START_REVIEW_SKILL_ID, 'APP_HANDOFF', 'metadata');
  }
  if (explicit === QUICK_CONFUSION_SKILL_ID || explicit === 'QUICK_CONFUSION_QA') {
    return accepted('QUICK_CONFUSION_QA', QUICK_CONFUSION_SKILL_ID, 'SYSTEM_RESULT', 'metadata');
  }
  if (explicit === PRACTICE_CONFUSION_SKILL_ID || explicit === 'PRACTICE_CONFUSION_IN_APP') {
    return accepted(
      'PRACTICE_CONFUSION_IN_APP',
      PRACTICE_CONFUSION_SKILL_ID,
      'APP_HANDOFF',
      'metadata'
    );
  }
  if (explicit === 'SCHEDULE_REVIEW_WITH_SYSTEM') {
    return {
      accepted: false,
      source: 'metadata',
      intent: 'SCHEDULE_REVIEW_WITH_SYSTEM',
      interactionMode: 'SYSTEM_CAPABILITY',
      reason: 'system_capability_not_verified'
    };
  }
  if (explicit === 'ENABLE_SYSTEM_COMPANION') {
    return {
      accepted: false,
      source: 'metadata',
      intent: 'ENABLE_SYSTEM_COMPANION',
      interactionMode: 'MINIMAL_PROJECTION',
      reason: 'system_companion_not_verified'
    };
  }
  return {
    accepted: false,
    source: 'metadata',
    skillId: explicit,
    reason: 'unsupported_public_intent'
  };
}

function accepted(
  intent: PublicLearningIntent,
  skillId: string,
  interactionMode: InteractionMode,
  source: 'metadata' | 'text'
): PublicIntentRoute {
  return {
    accepted: true,
    source,
    intent,
    skillId,
    interactionMode
  };
}
