import { CONFUSION_PAIR, CONFUSION_SCENARIOS } from './LearningContent';
import {
  PublicIntentRoute,
  routePublicIntent
} from './PublicIntentRouter';

export interface PublicIntentResult {
  completed: boolean;
  rejected?: boolean;
  rejectionReason?: string;
  message: string;
  artifact?: string;
  artifactName?: string;
  artifactType?: string;
  publicIntent?: string;
  skillId?: string;
  interactionMode?: string;
  continuation?: string;
}

interface ReviewHandoffEntities {
  scope: string;
  suggestedCount: number;
}

interface ConfusionHandoffEntities {
  wordA: string;
  wordB: string;
}

type HandoffEntities = ReviewHandoffEntities | ConfusionHandoffEntities;

interface HandoffAppInfo {
  bundleName: string;
  moduleName: string;
  abilityName: string;
}

interface AppHandoffArtifact {
  type: string;
  publicIntent?: string;
  interactionMode?: string;
  continuation: string;
  appRoute: string;
  appInfo: HandoffAppInfo;
  entities: HandoffEntities;
  handoffStatus: string;
}

interface AppContinuation {
  publicIntent: string;
  appRoute: string;
}

interface QuickConfusionArtifact {
  type: string;
  publicIntent?: string;
  interactionMode?: string;
  continuation: string;
  pair: string[];
  explanation: string;
  appContinuation: AppContinuation;
}

export class PublicIntentEngine {
  handle(userInput: string, explicitId?: string): PublicIntentResult {
    const route: PublicIntentRoute = routePublicIntent(userInput, explicitId);
    if (!route.accepted || !route.intent || !route.interactionMode) {
      return this.reject(route);
    }

    if (route.intent === 'QUICK_CONFUSION_QA') {
      return this.quickConfusion(route);
    }
    if (route.intent === 'PRACTICE_CONFUSION_IN_APP') {
      return this.appHandoff(route, 'confusion/practice', {
        wordA: CONFUSION_PAIR[0],
        wordB: CONFUSION_PAIR[1]
      });
    }
    return this.appHandoff(route, 'review/start', {
      scope: 'due_and_weak',
      suggestedCount: 6
    });
  }

  private appHandoff(
    route: PublicIntentRoute,
    appRoute: string,
    entities: HandoffEntities
  ): PublicIntentResult {
    const continuation = 'COMPLETE_AFTER_HANDOFF';
    const artifactType = 'learning.app-handoff.v1';
    const appInfo: HandoffAppInfo = {
      bundleName: 'com.example.echowordcompanion',
      moduleName: 'entry',
      abilityName: 'EntryAbility'
    };
    const artifact: AppHandoffArtifact = {
      type: artifactType,
      publicIntent: route.intent,
      interactionMode: route.interactionMode,
      continuation,
      appRoute,
      appInfo,
      entities,
      handoffStatus: 'REQUESTED_NOT_OBSERVED'
    };
    return {
      completed: true,
      publicIntent: route.intent,
      skillId: route.skillId,
      interactionMode: route.interactionMode,
      continuation,
      message: '已准备好回声词伴的应用入口。进入应用后，由应用内 Agent 独立创建或恢复学习会话。',
      artifactName: '应用交接请求',
      artifactType,
      artifact: JSON.stringify(artifact)
    };
  }

  private quickConfusion(route: PublicIntentRoute): PublicIntentResult {
    const continuation = 'COMPLETE_AFTER_RESULT';
    const artifactType = 'learning.quick-confusion-answer.v1';
    const scenario = CONFUSION_SCENARIOS[0];
    const appContinuation: AppContinuation = {
      publicIntent: 'PRACTICE_CONFUSION_IN_APP',
      appRoute: 'confusion/practice'
    };
    const artifact: QuickConfusionArtifact = {
      type: artifactType,
      publicIntent: route.intent,
      interactionMode: route.interactionMode,
      continuation,
      pair: CONFUSION_PAIR,
      explanation: scenario.explanation,
      appContinuation
    };
    return {
      completed: true,
      publicIntent: route.intent,
      skillId: route.skillId,
      interactionMode: route.interactionMode,
      continuation,
      message: `${scenario.explanation} 如果想真正练会，可以进入回声词伴做一个新的情境判断。`,
      artifactName: '易混词快速解释',
      artifactType,
      artifact: JSON.stringify(artifact)
    };
  }

  private reject(route: PublicIntentRoute): PublicIntentResult {
    const platformPending = route.reason === 'system_capability_not_verified' ||
      route.reason === 'system_companion_not_verified';
    return {
      completed: false,
      rejected: true,
      rejectionReason: route.reason ?? 'unsupported_intent',
      publicIntent: route.intent,
      skillId: route.skillId,
      interactionMode: route.interactionMode,
      message: platformPending
        ? '这个请求需要尚未在目标设备验证的系统能力，当前版本不会伪造成功。你仍可以先进入回声词伴完成学习。'
        : '我目前支持打开回声词伴开始复习、在小艺侧快速辨析 resilient 与 resistant，或进入应用做深度练习。'
    };
  }
}
