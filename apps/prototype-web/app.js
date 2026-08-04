const words = [
  {
    word: "resilient",
    phonetic: "/rɪˈzɪliənt/",
    prompt: "不看答案，你会怎样解释它？",
    hints: [
      "它描述的不是抵抗变化，而是经历压力后恢复过来的能力。",
      "想想一根被压弯后还能弹回来的树枝。"
    ],
    answer: "有韧性的；能从困难中恢复的",
    contrast: "易混：resistant 强调抵抗，resilient 强调受压后的恢复。"
  },
  {
    word: "subtle",
    phonetic: "/ˈsʌtl/",
    prompt: "它形容一种怎样的差别或表达？",
    hints: [
      "这种差别不明显，需要仔细感受才能发现。",
      "它和 obvious 几乎站在相反方向。"
    ],
    answer: "微妙的；不易察觉的",
    contrast: "常见搭配：a subtle difference / a subtle hint。"
  },
  {
    word: "compelling",
    phonetic: "/kəmˈpelɪŋ/",
    prompt: "一段论证 compelling，意味着什么？",
    hints: [
      "它不只是 interesting，而是强到让人难以忽视或拒绝。",
      "可以从 compel“迫使”联想它的力量感。"
    ],
    answer: "令人信服的；有强烈吸引力的",
    contrast: "语境决定更接近“有说服力”还是“引人入胜”。"
  }
];

const deepQuestions = [
  {
    prompt: "“她经历挫折后，很快恢复了状态。”",
    answer: "resilient",
    title: "这里是 resilient",
    copy: "resistant 是抵抗影响，resilient 是受过冲击后还能恢复。"
  },
  {
    prompt: "“这种涂层不容易被水侵蚀。”",
    answer: "resistant",
    title: "这里是 resistant",
    copy: "这里强调材料抵抗水的影响，用 water-resistant；受损后恢复才更接近 resilient。"
  }
];

const scenarioContent = {
  handoff: {
    utterance: "陪我复习今天到期的单词",
    replyLabel: "识别到应用入口意图",
    reply: "我可以把“复习今日到期词”的目标交给回声词伴。进入应用后，由应用内 Agent 选择内容和教学方式。",
    intent: "START_REVIEW_IN_APP",
    mode: "APP_HANDOFF",
    continuation: "交接后结束 A2A",
    connection: "READY_TO_HANDOFF",
    primary: "打开回声词伴",
    secondary: "取消"
  },
  quick: {
    utterance: "resilient 和 resistant 有什么区别？",
    replyLabel: "识别到系统侧快速问答",
    reply: "这个问题可以先在小艺侧得到最小解释，不必启动完整学习流程。需要真正练会时，再进入应用。",
    intent: "QUICK_CONFUSION_QA",
    mode: "SYSTEM_RESULT",
    continuation: "返回结果后结束 A2A",
    connection: "READY_TO_EXECUTE",
    primary: "查看简短解释",
    secondary: "先不用"
  },
  schedule: {
    utterance: "每天晚上九点提醒我复习",
    replyLabel: "识别到系统能力委托",
    reply: "提醒属于系统能力。应用可以提供复习范围和建议时间，但确认、授权与计划执行应由小艺系统侧完成。",
    intent: "SCHEDULE_REVIEW_WITH_SYSTEM",
    mode: "SYSTEM_CAPABILITY",
    continuation: "等待系统确认或失败",
    connection: "NEEDS_PLATFORM_CAPABILITY",
    primary: "查看待验证流程",
    secondary: "返回应用"
  },
  companion: {
    utterance: "离开应用后继续在小艺显示进度",
    replyLabel: "识别到显式系统伴随",
    reply: "只有这个场景需要保持最小进度投影。应用内 Agent 仍拥有学习状态，小艺只显示进度和系统入口。",
    intent: "ENABLE_SYSTEM_COMPANION",
    mode: "MINIMAL_PROJECTION",
    continuation: "用户明确要求时维持 A2A",
    connection: "READY_TO_ENABLE",
    primary: "开启系统伴随",
    secondary: "取消"
  }
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

const state = {
  scenario: "handoff",
  view: "landing",
  current: 0,
  hintLevel: 0,
  answers: [],
  answerRecorded: false,
  quickResultShown: false,
  companionEnabled: false,
  deepCompleted: false,
  deepRound: 0
};

const landingView = $("#landingView");
const studyView = $("#studyView");
const deepView = $("#deepView");
const summaryView = $("#summaryView");
const confidenceActions = $("#confidenceActions");
const hintOutcomeActions = $("#hintOutcomeActions");
const nextWordButton = $("#nextWord");

function setView(view) {
  state.view = view;
  landingView.hidden = view !== "landing";
  studyView.hidden = view !== "study";
  deepView.hidden = view !== "deep";
  summaryView.hidden = view !== "summary";
  $("#backButton").style.visibility = view === "landing" ? "hidden" : "visible";
}

function setBridge({ intent, mode, continuation, connection, status, active = false }) {
  $("#publicIntent").textContent = intent;
  $("#interactionMode").textContent = mode;
  $("#continuationPolicy").textContent = continuation;
  $("#connectionState").textContent = connection;
  $("#bridgeStatus").textContent = status;
  $("#railPulse").classList.toggle("is-active", active);
}

function updateScenarioTabs() {
  $$(".scenario-tab").forEach((button) => {
    const active = button.dataset.scenario === state.scenario;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
}

function resetSystemPanels() {
  $("#quickResult").hidden = true;
  $("#schedulePending").hidden = true;
  $("#companionProjection").hidden = true;
  $("#systemPrimary").disabled = false;
}

function renderScenario({ preserveApp = false } = {}) {
  const content = scenarioContent[state.scenario];
  resetSystemPanels();
  state.quickResultShown = false;
  if (!preserveApp) {
    setView("landing");
    $("#entryNotice").hidden = true;
    $("#appAgentState").textContent = "App Agent · 等待本地会话";
  }
  $("#userUtterance").textContent = content.utterance;
  $("#systemReplyLabel").textContent = content.replyLabel;
  $("#systemReply").textContent = content.reply;
  $("#systemPrimary").textContent = content.primary;
  $("#systemSecondary").textContent = content.secondary;
  setBridge({
    intent: content.intent,
    mode: content.mode,
    continuation: content.continuation,
    connection: content.connection,
    status: "等待用户动作"
  });
}

function selectScenario(scenario, options = {}) {
  state.scenario = scenario;
  if (scenario !== "companion") state.companionEnabled = false;
  updateScenarioTabs();
  renderScenario(options);
}

function completeHandoff(route) {
  setBridge({
    intent: route === "deep" ? "PRACTICE_CONFUSION_IN_APP" : "START_REVIEW_IN_APP",
    mode: "APP_HANDOFF",
    continuation: "交接完成，A2A 不再承载教学",
    connection: "CLOSED_AFTER_HANDOFF",
    status: "系统交接完成"
  });
  $("#systemReplyLabel").textContent = "小艺已完成应用交接";
  $("#systemReply").textContent = "后续教学由回声词伴 App Agent 独立运行；小艺不会逐词同步提示和答案。";
  $("#systemPrimary").textContent = "已打开应用";
  $("#systemPrimary").disabled = true;
  $("#systemSecondary").textContent = "A2A 已结束";

  if (route === "deep") {
    startDeep();
    $("#appAgentState").textContent = "App Agent · 深度辨析会话";
    return;
  }
  setView("landing");
  $("#entryNotice").hidden = false;
  $("#entryIntentText").textContent = "复习今日到期词 · 数量 6";
  $("#appAgentState").textContent = "App Agent · 已接收公开意图";
}

function showQuickResult() {
  state.quickResultShown = true;
  $("#quickResult").hidden = false;
  $("#systemPrimary").textContent = "去应用练习";
  $("#systemSecondary").textContent = "结果够用了";
  setBridge({
    intent: "QUICK_CONFUSION_QA",
    mode: "SYSTEM_RESULT",
    continuation: "短结果已返回，A2A 完成",
    connection: "COMPLETED",
    status: "系统 UI 可展示语义结果"
  });
}

function showScheduleBoundary() {
  $("#schedulePending").hidden = false;
  $("#systemPrimary").textContent = "等待云机验证";
  $("#systemPrimary").disabled = true;
  setBridge({
    intent: "SCHEDULE_REVIEW_WITH_SYSTEM",
    mode: "SYSTEM_CAPABILITY",
    continuation: "需要系统确认、授权与回执",
    connection: "PLATFORM_VALIDATION_PENDING",
    status: "未伪造计划成功"
  });
}

function enableCompanion() {
  state.companionEnabled = true;
  $("#companionProjection").hidden = false;
  $("#systemPrimary").textContent = "伴随已开启";
  $("#systemPrimary").disabled = true;
  $("#systemSecondary").textContent = "停止系统伴随";
  setBridge({
    intent: "ENABLE_SYSTEM_COMPANION",
    mode: "MINIMAL_PROJECTION",
    continuation: "只同步进度，不同步教学内容",
    connection: "ACTIVE",
    status: "A2A 最小投影保持中",
    active: true
  });
  startStudy(0);
  updateProjection();
}

function stopCompanion() {
  state.companionEnabled = false;
  $("#companionProjection").hidden = true;
  $("#systemPrimary").textContent = "重新开启系统伴随";
  $("#systemPrimary").disabled = false;
  $("#systemSecondary").textContent = "已停止";
  setBridge({
    intent: "ENABLE_SYSTEM_COMPANION",
    mode: "MINIMAL_PROJECTION",
    continuation: "App session 继续独立运行",
    connection: "CLOSED",
    status: "系统投影已停止"
  });
}

function updateProjection() {
  if (!state.companionEnabled) return;
  const completed = state.answers.length;
  $("#projectionProgress").textContent = `${completed} / ${words.length}`;
  $("#projectionBar").style.width = `${(completed / words.length) * 100}%`;
  $("#projectionCopy").textContent = completed >= words.length
    ? "应用内学习已完成；小艺只收到完成进度，复盘仍保存在应用内。"
    : `应用内正在处理第 ${Math.min(state.current + 1, words.length)} 个词；提示与答案不会同步到系统 UI。`;
}

function renderWord() {
  const word = words[state.current];
  state.hintLevel = 0;
  state.answerRecorded = false;
  $("#studyStep").textContent = `第 ${state.current + 1} 个，共 ${words.length} 个`;
  $("#studyProgressBar").style.width = `${(state.answers.length / words.length) * 100}%`;
  $("#wordText").textContent = word.word;
  $("#phoneticText").textContent = word.phonetic;
  $("#promptText").textContent = word.prompt;
  $("#hintArea").hidden = true;
  $("#answerReveal").hidden = true;
  confidenceActions.hidden = false;
  hintOutcomeActions.hidden = true;
  nextWordButton.hidden = true;
  nextWordButton.textContent = state.current === words.length - 1 ? "查看本轮复盘" : "下一词";
  $("#recallLabel").textContent = "先回忆，再求助";
  $("#appAgentState").textContent = `App Agent · 本地学习 ${state.answers.length} / ${words.length}`;
  updateProjection();
}

function startStudy(index = 0) {
  state.current = index;
  state.answers = [];
  $("#appBarCaption").textContent = state.companionEnabled ? "App Agent · 系统投影开启" : "App Agent · 独立本地会话";
  $("#appBarTitle").textContent = "先回忆，再理解";
  setView("study");
  renderWord();
}

function showHint(level) {
  const word = words[state.current];
  state.hintLevel = Math.min(2, Math.max(1, level));
  $("#hintArea").hidden = false;
  $("#hintText").textContent = word.hints[state.hintLevel - 1];
  $("#hintTitle").textContent = `提示 ${state.hintLevel} · ${state.hintLevel === 1 ? "方向" : "联想"}`;
  $("#hintCounter").textContent = `${state.hintLevel} / 2`;
  $("#nextHint").hidden = state.hintLevel >= 2;
  $("#hintStillStuck").textContent = state.hintLevel >= 2 ? "查看答案" : "还是没想起";
  confidenceActions.hidden = true;
  hintOutcomeActions.hidden = false;
  $("#recallLabel").textContent = "App Agent 已介入 · 再主动回忆一次";
}

function recordAnswer(outcome) {
  if (state.answerRecorded) return;
  state.answerRecorded = true;
  const word = words[state.current];
  const hintLevel = outcome === "know" ? 0 : state.hintLevel;
  state.answers.push({ word: word.word, outcome, hintLevel });
  $("#answerText").textContent = word.answer;
  $("#contrastText").textContent = word.contrast;
  $("#answerReveal").hidden = false;
  confidenceActions.hidden = true;
  hintOutcomeActions.hidden = true;
  nextWordButton.hidden = false;
  $("#recallLabel").textContent = outcome === "know"
    ? "App Agent 已记录 · 独立想起"
    : outcome === "fuzzy"
      ? `App Agent 已记录 · 提示 ${hintLevel} 后想起`
      : `App Agent 已记录 · 提示 ${hintLevel} 后仍需巩固`;
  $("#studyProgressBar").style.width = `${(state.answers.length / words.length) * 100}%`;
  $("#appAgentState").textContent = `App Agent · 本地学习 ${state.answers.length} / ${words.length}`;
  updateProjection();
}

function showSummary() {
  const counts = state.answers.reduce((acc, answer) => {
    acc[answer.outcome] = (acc[answer.outcome] || 0) + 1;
    return acc;
  }, {});
  $("#summaryKnow").textContent = counts.know || 0;
  $("#summaryHint").textContent = counts.fuzzy || 0;
  $("#summaryMiss").textContent = counts.miss || 0;
  $("#summaryCopy").textContent = `${words.length} 个词里，${counts.know || 0} 个独立想起，${counts.fuzzy || 0} 个提示后想起，${counts.miss || 0} 个需要重新学习。`;
  const weak = state.answers.find((answer) => answer.outcome !== "know");
  $("#nextReviewText").textContent = weak
    ? `明晚优先复习 ${weak.word}，先检查能否减少提示`
    : `三天后复测 ${words[0].word}，确认记忆仍然稳定`;
  $("#appBarCaption").textContent = "App Agent · 本地 Artifact";
  $("#appBarTitle").textContent = "本轮复盘";
  $("#appAgentState").textContent = "App Agent · 本地 session 已完成";
  setView("summary");
  updateProjection();
}

function startDeep() {
  state.deepCompleted = false;
  const question = deepQuestions[state.deepRound];
  $("#appBarCaption").textContent = "App Agent · 深度练习";
  $("#appBarTitle").textContent = "把差别用出来";
  $("#deepPrompt").textContent = question.prompt;
  $("#deepFeedback").hidden = true;
  $("#deepRetry").hidden = true;
  $$("[data-deep-choice]").forEach((button) => { button.disabled = false; });
  setView("deep");
}

function completeDeep(choice) {
  if (state.deepCompleted) return;
  state.deepCompleted = true;
  const question = deepQuestions[state.deepRound];
  const correct = choice === question.answer;
  $$("[data-deep-choice]").forEach((button) => { button.disabled = true; });
  $("#deepFeedbackLabel").textContent = correct ? "判断正确" : "这次仍有混淆";
  $("#deepFeedbackTitle").textContent = question.title;
  $("#deepFeedbackCopy").textContent = question.copy;
  $("#deepFeedback").hidden = false;
  $("#deepRetry").hidden = false;
  $("#appAgentState").textContent = "App Agent · 已形成辨析证据";
}

$("#systemPrimary").addEventListener("click", () => {
  if (state.scenario === "handoff") completeHandoff("review");
  else if (state.scenario === "quick") {
    if (state.quickResultShown) completeHandoff("deep");
    else showQuickResult();
  } else if (state.scenario === "schedule") showScheduleBoundary();
  else if (!state.companionEnabled) enableCompanion();
});

$("#systemSecondary").addEventListener("click", () => {
  if (state.scenario === "companion" && state.companionEnabled) {
    stopCompanion();
    return;
  }
  if (state.scenario === "schedule") {
    $("#systemReplyLabel").textContent = "系统计划未创建";
    $("#systemReply").textContent = "用户可以继续在应用内学习；没有系统回执时，不记录提醒已成功。";
    return;
  }
  setBridge({
    intent: scenarioContent[state.scenario].intent,
    mode: scenarioContent[state.scenario].mode,
    continuation: "用户取消本次系统协作",
    connection: "CANCELED",
    status: "App 本地状态未受影响"
  });
});

$("#startSession").addEventListener("click", () => startStudy(0));
$("#backButton").addEventListener("click", () => setView("landing"));
$("#whyButton").addEventListener("click", () => { $("#whySheet").hidden = false; });
$("#closeWhy").addEventListener("click", () => { $("#whySheet").hidden = true; });

$$("[data-confidence]").forEach((button) => {
  button.addEventListener("click", () => {
    if (button.dataset.confidence === "know") recordAnswer("know");
    else showHint(1);
  });
});

$("#nextHint").addEventListener("click", () => showHint(2));
$("#hintRecovered").addEventListener("click", () => recordAnswer("fuzzy"));
$("#hintStillStuck").addEventListener("click", () => {
  if (state.hintLevel < 2) showHint(2);
  else recordAnswer("miss");
});

nextWordButton.addEventListener("click", () => {
  if (state.current >= words.length - 1) {
    showSummary();
    return;
  }
  state.current += 1;
  renderWord();
});

$$("[data-deep-choice]").forEach((button) => {
  button.addEventListener("click", () => completeDeep(button.dataset.deepChoice));
});

$("#deepRetry").addEventListener("click", () => {
  state.deepRound = (state.deepRound + 1) % deepQuestions.length;
  startDeep();
});

$("#restartSession").addEventListener("click", () => startStudy(0));
$("#requestReminder").addEventListener("click", () => selectScenario("schedule", { preserveApp: true }));

$$(".scenario-tab").forEach((button) => {
  button.addEventListener("click", () => selectScenario(button.dataset.scenario));
});

updateScenarioTabs();
renderScenario();
