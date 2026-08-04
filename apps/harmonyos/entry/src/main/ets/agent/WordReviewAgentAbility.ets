import { AgentExtensionAbility, common, Want } from '@kit.AbilityKit';
import {
  AgentOperation,
  createA2AServer,
  Message,
  OnDataCallback,
  RequestContext,
  Role,
  Server,
  TaskState
} from '@kit.AgentFrameworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PublicIntentEngine, PublicIntentResult } from '../domain/PublicIntentEngine';

const DOMAIN = 0x0000;
const TAG = 'EchoWordAgent';

interface PublicIntentMetadata {
  intentId?: string;
  intent_id?: string;
  skillId?: string;
  skill_id?: string;
}

interface CollaborationMetadata {
  publicIntent?: string;
  skillId?: string;
  interactionMode?: string;
  continuation?: string;
}

export default class WordReviewAgentAbility extends AgentExtensionAbility {
  private server: Server | null = null;
  private readonly engine: PublicIntentEngine = new PublicIntentEngine();
  private runId: string = 'not-created';
  private readonly taskStates: Map<string, TaskState> = new Map();
  private readonly taskCollaborations: Map<string, CollaborationMetadata> = new Map();
  private readonly taskContexts: Map<string, string> = new Map();

  private readonly handleOperation: OnDataCallback =
    (method: AgentOperation, context: RequestContext): void => {
      const currentTask = context.getCurrentTask();
      const taskId = context.getTaskId() ?? currentTask?.id;
      const contextId = context.getContextId() ?? currentTask?.contextId;
      const clientSessionId = context.getClientSessionId();
      const explicitId = this.extractPublicIntentId(context);
      const relatedCount = context.getRelatedTasks().length;

      hilog.info(
        DOMAIN,
        TAG,
        'runId=%{public}s operation=%{public}d taskId=%{public}s contextId=%{public}s clientSessionId=%{public}s explicitIntent=%{public}s relatedCount=%{public}d',
        this.runId,
        method,
        taskId ?? 'none',
        contextId ?? 'none',
        clientSessionId ?? 'none',
        explicitId ?? 'none',
        relatedCount
      );
      switch (method) {
        case AgentOperation.EXECUTE:
          if (!taskId) {
            hilog.error(DOMAIN, TAG, '%{public}s', 'EXECUTE missing taskId');
            return;
          }
          this.execute(taskId, contextId, context.getUserInput('\n'), explicitId);
          break;
        case AgentOperation.CANCEL:
          if (!taskId) {
            hilog.error(DOMAIN, TAG, '%{public}s', 'CANCEL missing taskId');
            return;
          }
          this.cancelCollaboration(taskId, contextId);
          break;
        case AgentOperation.CLEAR_CONTEXT:
          if (contextId) {
            this.clearAdapterContext(contextId);
          } else {
            hilog.warn(DOMAIN, TAG, '%{public}s', 'CLEAR_CONTEXT missing contextId');
          }
          break;
        case AgentOperation.PERCEPTION_SUGGEST:
          hilog.info(DOMAIN, TAG, '%{public}s', 'PERCEPTION_SUGGEST received; chips contract pending validation');
          break;
        default:
          hilog.warn(DOMAIN, TAG, 'Unsupported operation=%{public}d', method);
      }
    };

  onCreate(want: Want): void {
    this.runId = util.generateRandomUUID();
    try {
      this.server = createA2AServer(this.context.agentCard, this.handleOperation, want);
      hilog.info(
        DOMAIN,
        TAG,
        'runId=%{public}s onCreate agentId=%{public}s adapterMode=%{public}s',
        this.runId,
        this.context.agentCard.agentId,
        'public-intent-only'
      );
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'createA2AServer failed: %{public}s', JSON.stringify(error));
    }
  }

  onConnect(want: Want, proxy: common.AgentHostProxy): void {
    if (!this.server) {
      hilog.error(DOMAIN, TAG, 'runId=%{public}s %{public}s', this.runId, 'onConnect without server');
      return;
    }
    this.server.start();
    hilog.info(DOMAIN, TAG, 'runId=%{public}s %{public}s', this.runId, 'onConnect server started');
  }

  onData(proxy: common.AgentHostProxy, data: string): void {
    if (!this.server) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'onData received before server creation');
      return;
    }
    this.server.onMessage(data, (response: string): void => {
      try {
        proxy.sendData(response);
      } catch (error) {
        hilog.error(
          DOMAIN,
          TAG,
          'runId=%{public}s sendData failed error=%{public}s',
          this.runId,
          JSON.stringify(error)
        );
      }
    });
  }

  onAuth(proxy: common.AgentHostProxy, handshakeData: string): void {
    if (!this.server) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'onAuth received before server creation');
      return;
    }
    try {
      proxy.authorize(this.server.onAuth(handshakeData));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'authorize failed: %{public}s', JSON.stringify(error));
    }
  }

  onDisconnect(want: Want, proxy: common.AgentHostProxy): void {
    this.server?.stop();
    hilog.info(DOMAIN, TAG, '%{public}s', 'onDisconnect server stopped');
  }

  onDestroy(): void {
    this.server?.stop();
    this.server = null;
    this.taskStates.clear();
    this.taskCollaborations.clear();
    this.taskContexts.clear();
    hilog.info(DOMAIN, TAG, '%{public}s', 'onDestroy');
  }

  private execute(
    taskId: string,
    contextId: string | undefined,
    userInput: string,
    explicitId?: string
  ): void {
    try {
      const result: PublicIntentResult = this.engine.handle(userInput, explicitId);
      const collaboration: CollaborationMetadata = {
        publicIntent: result.publicIntent,
        skillId: result.skillId,
        interactionMode: result.interactionMode,
        continuation: result.continuation
      };
      this.taskCollaborations.set(taskId, collaboration);
      if (contextId) this.taskContexts.set(taskId, contextId);

      if (!this.updateTaskStatus(
        taskId,
        contextId,
        TaskState.WORKING,
        '正在解析公开意图并准备系统侧结果。',
        collaboration
      )) {
        return;
      }

      hilog.info(
        DOMAIN,
        TAG,
        'runId=%{public}s route taskId=%{public}s publicIntent=%{public}s mode=%{public}s continuation=%{public}s rejected=%{public}s reason=%{public}s',
        this.runId,
        taskId,
        result.publicIntent ?? 'none',
        result.interactionMode ?? 'none',
        result.continuation ?? 'none',
        result.rejected ? 'true' : 'false',
        result.rejectionReason ?? 'none'
      );

      if (result.rejected) {
        this.updateTaskStatus(taskId, contextId, TaskState.REJECTED, result.message, collaboration);
        this.removeTaskAssociation(taskId);
        return;
      }
      if (!result.completed || !result.artifact) {
        this.updateTaskStatus(
          taskId,
          contextId,
          TaskState.FAILED,
          '公开意图没有生成可交付的一次性结果。',
          collaboration
        );
        this.removeTaskAssociation(taskId);
        return;
      }
      if (!this.addTaskArtifact(
        taskId,
        result.artifact,
        result.artifactName ?? '公开意图结果',
        result.artifactType ?? 'application/json',
        collaboration
      )) {
        this.updateTaskStatus(taskId, contextId, TaskState.FAILED, '系统侧结果保存失败，请稍后重试。', collaboration);
        return;
      }
      this.updateTaskStatus(taskId, contextId, TaskState.COMPLETED, result.message, collaboration);
      this.removeTaskAssociation(taskId);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'execute failed taskId=%{public}s error=%{public}s', taskId, JSON.stringify(error));
      this.updateTaskStatus(
        taskId,
        contextId,
        TaskState.FAILED,
        '公开意图暂时无法处理，已保留故障日志，请稍后重试。',
        this.taskCollaborations.get(taskId)
      );
      this.removeTaskAssociation(taskId);
    }
  }

  private cancelCollaboration(taskId: string, contextId: string | undefined): void {
    const collaboration = this.taskCollaborations.get(taskId);
    this.updateTaskStatus(
      taskId,
      contextId,
      TaskState.CANCELED,
      '本次系统协作已取消；应用内已有学习会话不会被删除或改写。',
      collaboration
    );
    this.removeTaskAssociation(taskId);
  }

  private clearAdapterContext(contextId: string): void {
    const taskIds: string[] = [];
    this.taskContexts.forEach((storedContextId: string, taskId: string): void => {
      if (storedContextId === contextId) taskIds.push(taskId);
    });
    taskIds.forEach((taskId: string): void => this.removeTaskAssociation(taskId));
    hilog.info(
      DOMAIN,
      TAG,
      'runId=%{public}s clearContext contextId=%{public}s clearedAdapterTasks=%{public}d appSessionsAffected=%{public}d',
      this.runId,
      contextId,
      taskIds.length,
      0
    );
  }

  private removeTaskAssociation(taskId: string): void {
    this.taskCollaborations.delete(taskId);
    this.taskContexts.delete(taskId);
  }

  private updateTaskStatus(
    taskId: string,
    contextId: string | undefined,
    nextState: TaskState,
    messageText: string,
    collaboration?: CollaborationMetadata
  ): boolean {
    if (!this.server) {
      hilog.error(
        DOMAIN,
        TAG,
        'runId=%{public}s updateStatus skipped taskId=%{public}s nextState=%{public}d reason=no-server',
        this.runId,
        taskId,
        nextState
      );
      return false;
    }

    const previousState = this.taskStates.get(taskId) ?? TaskState.SUBMITTED;
    const message = this.createMessage(taskId, contextId, messageText, collaboration);
    const startedAt = Date.now();
    try {
      this.server.updateStatus(taskId, {
        state: nextState,
        timestamp: new Date().toISOString(),
        message
      });
      this.taskStates.set(taskId, nextState);
      hilog.info(
        DOMAIN,
        TAG,
        'runId=%{public}s taskId=%{public}s contextId=%{public}s previousState=%{public}d nextState=%{public}d messageId=%{public}s publicIntent=%{public}s mode=%{public}s continuation=%{public}s durationMs=%{public}d',
        this.runId,
        taskId,
        contextId ?? 'none',
        previousState,
        nextState,
        message.messageId,
        collaboration?.publicIntent ?? 'none',
        collaboration?.interactionMode ?? 'none',
        collaboration?.continuation ?? 'none',
        Date.now() - startedAt
      );
      return true;
    } catch (error) {
      hilog.error(
        DOMAIN,
        TAG,
        'runId=%{public}s updateStatus failed taskId=%{public}s nextState=%{public}d messageId=%{public}s error=%{public}s',
        this.runId,
        taskId,
        nextState,
        message.messageId,
        JSON.stringify(error)
      );
      return false;
    }
  }

  private addTaskArtifact(
    taskId: string,
    raw: string,
    name: string,
    artifactType: string,
    collaboration: CollaborationMetadata
  ): boolean {
    if (!this.server) return false;
    const artifactId = util.generateRandomUUID();
    const startedAt = Date.now();
    try {
      this.server.addArtifact(taskId, {
        artifactId,
        name,
        parts: [{ mediaType: 'application/json', raw }],
        metadata: {
          type: artifactType,
          publicIntent: collaboration.publicIntent,
          skillId: collaboration.skillId,
          interactionMode: collaboration.interactionMode,
          continuation: collaboration.continuation
        },
        lastChunk: true
      });
      hilog.info(
        DOMAIN,
        TAG,
        'runId=%{public}s taskId=%{public}s publicIntent=%{public}s mode=%{public}s continuation=%{public}s artifactType=%{public}s artifactId=%{public}s lastChunk=%{public}s durationMs=%{public}d',
        this.runId,
        taskId,
        collaboration.publicIntent ?? 'none',
        collaboration.interactionMode ?? 'none',
        collaboration.continuation ?? 'none',
        artifactType,
        artifactId,
        'true',
        Date.now() - startedAt
      );
      return true;
    } catch (error) {
      hilog.error(
        DOMAIN,
        TAG,
        'runId=%{public}s addArtifact failed taskId=%{public}s artifactId=%{public}s error=%{public}s',
        this.runId,
        taskId,
        artifactId,
        JSON.stringify(error)
      );
      return false;
    }
  }

  private createMessage(
    taskId: string,
    contextId: string | undefined,
    messageText: string,
    collaboration?: CollaborationMetadata
  ): Message {
    const message: Message = {
      messageId: util.generateRandomUUID(),
      role: Role.AGENT,
      taskId,
      parts: [{ mediaType: 'text/plain', text: messageText }],
      metadata: {
        type: 'learning.public-intent-status.v1',
        publicIntent: collaboration?.publicIntent,
        skillId: collaboration?.skillId,
        interactionMode: collaboration?.interactionMode,
        continuation: collaboration?.continuation
      }
    };
    if (contextId) {
      message.contextId = contextId;
    } else {
      hilog.warn(DOMAIN, TAG, 'taskId=%{public}s has no contextId', taskId);
    }
    return message;
  }

  private extractPublicIntentId(context: RequestContext): string | undefined {
    const contextMetadata = context.getMetadata() as PublicIntentMetadata;
    const messageMetadata = context.getMessage()?.metadata as PublicIntentMetadata | undefined;
    return contextMetadata.intentId ?? contextMetadata.intent_id ??
      contextMetadata.skillId ?? contextMetadata.skill_id ??
      messageMetadata?.intentId ?? messageMetadata?.intent_id ??
      messageMetadata?.skillId ?? messageMetadata?.skill_id;
  }
}
