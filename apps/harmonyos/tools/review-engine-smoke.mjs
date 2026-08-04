import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const defaultTypeScript = 'E:\\DevEnviorment\\DevEco Studio\\tools\\hvigor\\hvigor\\node_modules\\typescript\\lib\\typescript.js';
const typeScriptPath = process.env.DEVECO_TYPESCRIPT || defaultTypeScript;
const typeScriptModule = await import(pathToFileURL(typeScriptPath).href);
const ts = typeScriptModule.default || typeScriptModule;
const routerSourceUrl = new URL('../entry/src/main/ets/domain/SkillRouter.ets', import.meta.url);
const routerSource = fs.readFileSync(routerSourceUrl, 'utf8');
const routerCompiled = ts.transpileModule(routerSource, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ES2022
  },
  fileName: 'SkillRouter.ets'
}).outputText;
const routerModuleUrl = `data:text/javascript;base64,${Buffer.from(routerCompiled).toString('base64')}#${Date.now()}`;
const { CONFUSION_SKILL_ID, REVIEW_SKILL_ID, routeLearningRequest } = await import(routerModuleUrl);

const contentSourceUrl = new URL('../entry/src/main/ets/domain/LearningContent.ets', import.meta.url);
const contentSource = fs.readFileSync(contentSourceUrl, 'utf8');
const contentCompiled = ts.transpileModule(contentSource, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ES2022
  },
  fileName: 'LearningContent.ets'
}).outputText;
const contentModuleUrl = `data:text/javascript;base64,${Buffer.from(contentCompiled).toString('base64')}#${Date.now()}`;
const { CONFUSION_SCENARIOS, REVIEW_WORDS } = await import(contentModuleUrl);

const engineSourceUrl = new URL('../entry/src/main/ets/domain/ReviewTaskEngine.ets', import.meta.url);
const engineSource = fs.readFileSync(engineSourceUrl, 'utf8');
const engineCompiled = ts.transpileModule(engineSource, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ES2022
  },
  fileName: 'ReviewTaskEngine.ets'
}).outputText
  .replace(/from ['"]\.\/SkillRouter['"];/, `from '${routerModuleUrl}';`)
  .replace(/from ['"]\.\/LearningContent['"];/, `from '${contentModuleUrl}';`);
const moduleUrl = `data:text/javascript;base64,${Buffer.from(engineCompiled).toString('base64')}#${Date.now()}`;
const { ReviewTaskEngine } = await import(moduleUrl);

class MemoryRepository {
  constructor() {
    this.sessions = new Map();
  }

  clone(value) {
    return value ? JSON.parse(JSON.stringify(value)) : undefined;
  }

  load(taskId) {
    return this.clone(this.sessions.get(taskId));
  }

  loadLatestByContext(contextId) {
    let latest;
    for (const session of this.sessions.values()) {
      if (session.contextId === contextId && (!latest || session.updatedAt > latest.updatedAt)) latest = session;
    }
    return this.clone(latest);
  }

  save(session) {
    this.sessions.set(session.taskId, this.clone(session));
  }

  delete(taskId) {
    this.sessions.delete(taskId);
  }

  deleteByContext(contextId) {
    const taskIds = [...this.sessions.values()]
      .filter((session) => session.contextId === contextId)
      .map((session) => session.taskId);
    taskIds.forEach((taskId) => this.sessions.delete(taskId));
    return taskIds.length;
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const repository = new MemoryRepository();
let engine = new ReviewTaskEngine(repository);

assert(REVIEW_WORDS.length === 3, 'Shared learning content should expose the three-word review deck');
assert(REVIEW_WORDS.every((word) => word.hints.length === 2), 'Every shared review word should preserve two hint levels');
assert(CONFUSION_SCENARIOS.length >= 2, 'Shared confusion content should provide a fresh transfer scenario');

let route = routeLearningRequest('解释 resilient 和 resistant 的区别');
assert(route.accepted && route.skillId === CONFUSION_SKILL_ID, 'Text routing should select confusion repair');
route = routeLearningRequest('开始', REVIEW_SKILL_ID);
assert(route.accepted && route.source === 'metadata', 'Explicit supported skill metadata should take priority');
route = routeLearningRequest('陪我写一封邮件');
assert(!route.accepted && route.reason === 'unsupported_intent', 'Unrelated input should not silently start review');

let result = engine.handle('rejected-1', 'context-0', [], '陪我写一封邮件');
assert(result.rejected && result.rejectionReason === 'unsupported_intent', 'Unsupported intent should be rejected');
assert(!repository.load('rejected-1'), 'Rejected input must not create an active snapshot');

result = engine.handle('rejected-2', 'context-0', [], '开始', 'unknown_skill');
assert(result.rejected && result.rejectionReason === 'unsupported_skill', 'Unknown explicit skill should be rejected');
assert(!repository.load('rejected-2'), 'Unknown skill must not create an active snapshot');

result = engine.handle('metadata-review', 'context-0', [], '开始', REVIEW_SKILL_ID);
assert(!result.completed && result.skillId === REVIEW_SKILL_ID, 'Explicit review skill should accept a generic start message');
assert(engine.getSkillId('metadata-review') === REVIEW_SKILL_ID, 'Active task should expose its resolved skill');
engine.cancel('metadata-review');

result = engine.handle('task-1', 'context-1', [], '陪我复习今天的单词');
assert(!result.completed && result.message.includes('resilient'), 'A new task should start at resilient');

result = engine.handle('task-1', 'context-1', [], '提示');
assert(result.message.includes('提示 1 / 2'), 'The first hint should be persisted');
assert(repository.load('task-1').hintLevel === 1, 'Stored hint level should be 1');

engine = new ReviewTaskEngine(repository);
result = engine.handle('task-1', 'context-1', [], '继续');
assert(result.restored && result.message.includes('已用提示 1 / 2'), 'The same task should resume after engine recreation');

result = engine.handle('task-1', 'context-1', [], '它强调受压之后恢复');
assert(result.message.includes('下一词') && result.message.includes('subtle'), 'A hinted answer should advance to subtle');
assert(repository.load('task-1').attempts[0].outcome === 'hinted', 'Hinted recall should be recorded');

engine = new ReviewTaskEngine(repository);
result = engine.handle('task-2', 'context-1', ['task-1'], '继续刚才的复习');
assert(result.restored && result.message.includes('subtle'), 'A related task should inherit the stored session');
assert(!repository.load('task-1') && repository.load('task-2'), 'Recovery should migrate ownership to the new task');

result = engine.handle('task-2', 'context-1', [], '意思是微妙、不明显');
assert(result.message.includes('compelling'), 'Independent recall should advance to compelling');

result = engine.handle('task-2', 'context-1', [], '生成复盘');
assert(result.completed, 'Explicit review should complete the partial task');
const artifact = JSON.parse(result.artifact);
assert(artifact.partial === true && artifact.completed === 2, 'Partial artifact should use dynamic counts');
assert(artifact.independentRecall === 1 && artifact.hintedRecall === 1, 'Artifact should preserve evidence types');
assert(!repository.load('task-2'), 'Completed task should be removed from active storage');

engine.handle('task-3', 'context-3', [], '开始复习');
engine.cancel('task-3');
assert(!repository.load('task-3'), 'Cancel should remove the persisted session');

engine.handle('task-4', 'context-4', [], '开始一轮复习');
engine.handle('task-5', 'context-4', [], '再开一轮单词复习');
assert(engine.clearContext('context-4') === 2, 'Context clear should remove every active task in that context');

engine.handle('task-6', 'context-6', [], '开始复习');
engine.handle('task-6', 'context-6', [], '提示');
engine = new ReviewTaskEngine(repository);
result = engine.handle('task-7', 'context-6', [], '恢复复习');
assert(result.restored && result.message.includes('提示 1 / 2'), 'Resume intent should recover the latest task in the context');

result = engine.handle('confusion-1', 'context-7', [], '解释 resilient 和 resistant 的区别');
assert(!result.completed && result.message.includes('先不看解释'), 'Confusion repair should ask for judgment first');
assert(repository.load('confusion-1').mode === 'confusion', 'Confusion mode should be persisted');

result = engine.handle('confusion-1', 'context-7', [], '给我一个提示');
assert(result.message.includes('抵抗外力') && repository.load('confusion-1').hintLevel === 1, 'Confusion hint should persist');
engine = new ReviewTaskEngine(repository);
result = engine.handle('confusion-1', 'context-7', [], '继续');
assert(result.restored && result.message.includes('已使用提示 1 / 1'), 'Confusion task should resume after recreation');

result = engine.handle('confusion-1', 'context-7', [], '我选 resistant');
assert(result.completed && result.artifactType === 'learning.confusion-repair.v1', 'A judgment should complete short QA');
const confusionArtifact = JSON.parse(result.artifact);
assert(confusionArtifact.correct === false && confusionArtifact.hintLevel === 1, 'Confusion artifact should record choice and hint evidence');
assert(!repository.load('confusion-1'), 'Completed confusion task should leave active storage');

result = engine.handle('confusion-2', 'context-8', [], '帮我辨析 resilient 和 resistant 的不同');
result = engine.handle('confusion-2', 'context-8', [], 'resilient');
assert(result.completed && JSON.parse(result.artifact).correct === true, 'Independent correct judgment should complete without a hint');
assert(result.skillId === CONFUSION_SKILL_ID, 'Confusion artifact result should preserve resolved skill ID');

result = engine.handle('confusion-3', 'context-9', [], '开始', CONFUSION_SKILL_ID);
assert(!result.completed && result.message.includes('先不看解释'), 'Explicit confusion skill should route without text heuristics');
engine.cancel('confusion-3');

console.log('REVIEW_ENGINE_SMOKE=PASS');
