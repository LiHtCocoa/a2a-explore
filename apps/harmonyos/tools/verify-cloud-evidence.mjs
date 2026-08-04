import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const requireAll = args.includes('--require-all');
const inputPath = args.find((arg) => !arg.startsWith('--'));

if (!inputPath) {
  console.error('Usage: node verify-cloud-evidence.mjs <hilog.txt> [--require-all]');
  process.exit(2);
}

const resolvedPath = path.resolve(inputPath);
if (!fs.existsSync(resolvedPath)) {
  console.error(`HiLog file not found: ${resolvedPath}`);
  process.exit(2);
}

const bytes = fs.readFileSync(resolvedPath);
const logText = bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe
  ? bytes.subarray(2).toString('utf16le')
  : bytes.toString('utf8').replace(/^\uFEFF/, '');
const lines = logText.split(/\r?\n/);

const cases = [
  {
    id: 'A1',
    publicIntent: 'START_REVIEW_IN_APP',
    mode: 'APP_HANDOFF',
    continuation: 'COMPLETE_AFTER_HANDOFF',
    artifactType: 'learning.app-handoff.v1'
  },
  {
    id: 'A2',
    publicIntent: 'QUICK_CONFUSION_QA',
    mode: 'SYSTEM_RESULT',
    continuation: 'COMPLETE_AFTER_RESULT',
    artifactType: 'learning.quick-confusion-answer.v1'
  },
  {
    id: 'A3',
    publicIntent: 'PRACTICE_CONFUSION_IN_APP',
    mode: 'APP_HANDOFF',
    continuation: 'COMPLETE_AFTER_HANDOFF',
    artifactType: 'learning.app-handoff.v1'
  }
];

function findRoute(testCase) {
  return lines.find((line) =>
    line.includes(' route ') &&
    line.includes(`publicIntent=${testCase.publicIntent}`) &&
    line.includes(`mode=${testCase.mode}`) &&
    line.includes(`continuation=${testCase.continuation}`) &&
    line.includes('rejected=false')
  );
}

function extractTaskId(line) {
  return line?.match(/\btaskId=([^\s]+)/)?.[1];
}

const results = cases.map((testCase) => {
  const routeLine = findRoute(testCase);
  const taskId = extractTaskId(routeLine);
  const taskLines = taskId ? lines.filter((line) => line.includes(`taskId=${taskId}`)) : [];
  const artifactSeen = taskLines.some((line) =>
    line.includes('artifactId=') &&
    line.includes(`publicIntent=${testCase.publicIntent}`) &&
    line.includes(`artifactType=${testCase.artifactType}`)
  );
  const completedSeen = taskLines.some((line) => line.includes('nextState=3'));
  return {
    id: testCase.id,
    publicIntent: testCase.publicIntent,
    taskId: taskId ?? null,
    routeSeen: Boolean(routeLine),
    artifactSeen,
    completedSeen,
    pass: Boolean(routeLine) && artifactSeen && completedSeen
  };
});

const auxiliary = {
  cancelSeen: lines.some((line) => line.includes('nextState=4')),
  rejectedSeen: lines.some((line) => line.includes('nextState=6')),
  clearContextPreservedAppSessions: lines.some((line) =>
    line.includes('clearContext') && line.includes('appSessionsAffected=0')
  ),
  failedSeen: lines.some((line) => line.includes('nextState=5'))
};

const report = {
  source: resolvedPath,
  lineCount: lines.length,
  requiredCasesPassed: results.every((result) => result.pass),
  cases: results,
  auxiliary,
  note: 'Visible XiaoYi UI, actual app launch, Want parameters and screenshots still require trace.md evidence.'
};

console.log(JSON.stringify(report, null, 2));

if (requireAll && !report.requiredCasesPassed) {
  process.exitCode = 1;
}
