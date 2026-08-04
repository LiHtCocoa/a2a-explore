import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const defaultTypeScript = 'E:\\DevEnviorment\\DevEco Studio\\tools\\hvigor\\hvigor\\node_modules\\typescript\\lib\\typescript.js';
const typeScriptPath = process.env.DEVECO_TYPESCRIPT || defaultTypeScript;
const typeScriptModule = await import(pathToFileURL(typeScriptPath).href);
const ts = typeScriptModule.default || typeScriptModule;

function compile(sourceUrl, fileName) {
  return ts.transpileModule(fs.readFileSync(sourceUrl, 'utf8'), {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.ES2022
    },
    fileName
  }).outputText;
}

function moduleUrl(source) {
  return `data:text/javascript;base64,${Buffer.from(source).toString('base64')}#${Date.now()}-${Math.random()}`;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const contentUrl = moduleUrl(compile(
  new URL('../entry/src/main/ets/domain/LearningContent.ets', import.meta.url),
  'LearningContent.ets'
));
const routerUrl = moduleUrl(compile(
  new URL('../entry/src/main/ets/domain/PublicIntentRouter.ets', import.meta.url),
  'PublicIntentRouter.ets'
));
const engineSource = compile(
  new URL('../entry/src/main/ets/domain/PublicIntentEngine.ets', import.meta.url),
  'PublicIntentEngine.ets'
)
  .replace(/from ['"]\.\/LearningContent['"];/, `from '${contentUrl}';`)
  .replace(/from ['"]\.\/PublicIntentRouter['"];/, `from '${routerUrl}';`);
const { PublicIntentEngine } = await import(moduleUrl(engineSource));
const engine = new PublicIntentEngine();

let result = engine.handle('陪我复习今天到期的单词');
assert(result.completed && result.publicIntent === 'START_REVIEW_IN_APP', 'Review wording should hand off to the app');
assert(result.interactionMode === 'APP_HANDOFF', 'Review intent should use APP_HANDOFF');
let artifact = JSON.parse(result.artifact);
assert(artifact.type === 'learning.app-handoff.v1', 'Review should emit an app handoff artifact');
assert(artifact.appRoute === 'review/start', 'Review handoff should target the review route');
assert(artifact.handoffStatus === 'REQUESTED_NOT_OBSERVED', 'Handoff must not claim an observed app launch');
assert(result.continuation === 'COMPLETE_AFTER_HANDOFF', 'A2A should complete after handoff by default');

result = engine.handle('resilient 和 resistant 有什么区别');
assert(result.completed && result.publicIntent === 'QUICK_CONFUSION_QA', 'Difference wording should return a system-side answer');
assert(result.interactionMode === 'SYSTEM_RESULT', 'Quick QA should use SYSTEM_RESULT');
artifact = JSON.parse(result.artifact);
assert(artifact.type === 'learning.quick-confusion-answer.v1', 'Quick QA should emit its own artifact type');
assert(artifact.appContinuation.publicIntent === 'PRACTICE_CONFUSION_IN_APP', 'Quick QA should offer app practice as an explicit continuation');

result = engine.handle('用一个情境帮我区分 resilient 和 resistant');
assert(result.completed && result.publicIntent === 'PRACTICE_CONFUSION_IN_APP', 'Practice wording should hand off to deep practice');
artifact = JSON.parse(result.artifact);
assert(artifact.appRoute === 'confusion/practice', 'Practice handoff should target the confusion route');

result = engine.handle('开始', 'quick_word_confusion_qa');
assert(result.completed && result.publicIntent === 'QUICK_CONFUSION_QA', 'Explicit public Skill metadata should override generic text');

result = engine.handle('每天晚上提醒我复习');
assert(result.rejected && result.rejectionReason === 'system_capability_not_verified', 'Unverified scheduling must be rejected');
assert(!result.artifact, 'Rejected scheduling must not fabricate a system plan artifact');

result = engine.handle('退出应用后继续在小艺显示进度');
assert(result.rejected && result.rejectionReason === 'system_companion_not_verified', 'Unverified companion mode must be rejected');

result = engine.handle('开始', 'SCHEDULE_REVIEW_WITH_SYSTEM');
assert(result.rejected && result.rejectionReason === 'system_capability_not_verified', 'Explicit unverified system intent must preserve its pending reason');

result = engine.handle('帮我写一封邮件');
assert(result.rejected && result.rejectionReason === 'unsupported_intent', 'Unrelated input should remain unsupported');

console.log('PUBLIC_INTENT_SMOKE=PASS');
