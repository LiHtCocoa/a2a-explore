import fs from 'node:fs';
import vm from 'node:vm';

class FakeClassList {
  constructor(initial = '') {
    this.values = new Set(initial.split(/\s+/).filter(Boolean));
  }

  add(...names) {
    names.forEach((name) => this.values.add(name));
  }

  remove(...names) {
    names.forEach((name) => this.values.delete(name));
  }

  toggle(name, force) {
    if (force === true) this.values.add(name);
    else if (force === false) this.values.delete(name);
    else if (this.values.has(name)) this.values.delete(name);
    else this.values.add(name);
    return this.values.has(name);
  }

  contains(name) {
    return this.values.has(name);
  }
}

class FakeElement {
  constructor({ id = '', classes = '', dataset = {}, hidden = false } = {}) {
    this.id = id;
    this.dataset = dataset;
    this.hidden = hidden;
    this.disabled = false;
    this.textContent = '';
    this.style = {};
    this.attributes = new Map();
    this.classList = new FakeClassList(classes);
    this.listeners = new Map();
  }

  addEventListener(type, listener) {
    this.listeners.set(type, listener);
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  click() {
    if (!this.disabled) this.listeners.get('click')?.({ currentTarget: this });
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const html = fs.readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const source = fs.readFileSync(new URL('./app.js', import.meta.url), 'utf8');
const elements = new Map();

for (const match of html.matchAll(/<[^>]+\bid="([^"]+)"[^>]*>/g)) {
  const tag = match[0];
  elements.set(match[1], new FakeElement({
    id: match[1],
    classes: tag.match(/\bclass="([^"]+)"/)?.[1] || '',
    hidden: /\shidden(?:\s|>|=)/.test(tag)
  }));
}

const scenarioTabs = [...html.matchAll(/<button class="([^"]*scenario-tab[^"]*)"[^>]*data-scenario="([^"]+)"[^>]*>/g)]
  .map((match) => new FakeElement({ classes: match[1], dataset: { scenario: match[2] } }));
const confidenceButtons = [...html.matchAll(/<button[^>]*data-confidence="([^"]+)"[^>]*>/g)]
  .map((match) => new FakeElement({ dataset: { confidence: match[1] } }));
const deepChoiceButtons = [...html.matchAll(/<button[^>]*data-deep-choice="([^"]+)"[^>]*>/g)]
  .map((match) => new FakeElement({ dataset: { deepChoice: match[1] } }));

const selectorLists = new Map([
  ['.scenario-tab', scenarioTabs],
  ['[data-confidence]', confidenceButtons],
  ['[data-deep-choice]', deepChoiceButtons]
]);

const document = {
  querySelector(selector) {
    if (selector.startsWith('#')) return elements.get(selector.slice(1)) || null;
    return selectorLists.get(selector)?.[0] || null;
  },
  querySelectorAll(selector) {
    return selectorLists.get(selector) || [];
  }
};

vm.runInContext(source, vm.createContext({ document, console }));

const byId = (id) => elements.get(id);
const scenario = (name) => scenarioTabs.find((button) => button.dataset.scenario === name);
const confidence = (name) => confidenceButtons.find((button) => button.dataset.confidence === name);
const deepChoice = (name) => deepChoiceButtons.find((button) => button.dataset.deepChoice === name);

assert(!byId('landingView').hidden, 'App landing should be visible initially');
assert(byId('entryNotice').hidden, 'The app should not pretend a handoff happened before the system action');
assert(byId('connectionState').textContent === 'READY_TO_HANDOFF', 'Initial A2A purpose should be an app handoff');

byId('systemPrimary').click();
assert(!byId('entryNotice').hidden, 'System handoff should deliver a public intent to the app');
assert(byId('connectionState').textContent === 'CLOSED_AFTER_HANDOFF', 'Default handoff should close A2A');

byId('startSession').click();
assert(!byId('studyView').hidden, 'Study view should open');
assert(byId('connectionState').textContent === 'CLOSED_AFTER_HANDOFF', 'App learning should not silently reopen A2A');

confidence('fuzzy').click();
assert(!byId('hintArea').hidden, 'A hint should appear after requesting help');
assert(byId('answerReveal').hidden, 'A hint must not reveal the full answer');
assert(!byId('hintOutcomeActions').hidden, 'The learner should answer again after a hint');

byId('nextHint').click();
assert(byId('hintCounter').textContent === '2 / 2', 'Second hint level should be reachable');
assert(byId('answerReveal').hidden, 'Second hint must still preserve recall');
byId('hintStillStuck').click();
assert(!byId('answerReveal').hidden, 'Full answer should appear only after both hints fail');
assert(byId('appAgentState').textContent.includes('1 / 3'), 'The app agent should own the learning progress');

scenario('quick').click();
assert(byId('connectionState').textContent === 'READY_TO_EXECUTE', 'Quick QA should start as a system-side result intent');
byId('systemPrimary').click();
assert(!byId('quickResult').hidden, 'Quick QA should return a minimal system-side result');
assert(byId('connectionState').textContent === 'COMPLETED', 'Quick QA should complete after returning the result');
assert(byId('deepView').hidden, 'Quick QA should not automatically launch deep practice');

byId('systemPrimary').click();
assert(!byId('deepView').hidden, 'Deep-understanding view should open');
assert(byId('deepFeedback').hidden, 'Explanation must remain hidden before judgment');
assert(byId('connectionState').textContent === 'CLOSED_AFTER_HANDOFF', 'Deep practice should run in the app after handoff');
deepChoice('resilient').click();
assert(!byId('deepFeedback').hidden, 'Feedback should appear after judgment');
assert(byId('appAgentState').textContent.includes('辨析证据'), 'The app agent should record deep-practice evidence');

byId('deepRetry').click();
assert(byId('deepPrompt').textContent.includes('涂层'), 'Retry should use a different context');

scenario('schedule').click();
byId('systemPrimary').click();
assert(!byId('schedulePending').hidden, 'System scheduling should expose its platform-validation boundary');
assert(byId('connectionState').textContent === 'PLATFORM_VALIDATION_PENDING', 'The prototype must not fake a system plan success');

scenario('companion').click();
byId('systemPrimary').click();
assert(!byId('companionProjection').hidden, 'Explicit companion mode should create a minimal system projection');
assert(byId('connectionState').textContent === 'ACTIVE', 'A2A should remain active only after explicit companion enablement');
assert(!byId('studyView').hidden, 'The app session should run alongside the system projection');
confidence('know').click();
assert(byId('projectionProgress').textContent === '1 / 3', 'Only minimal progress should be projected to the system side');
byId('systemSecondary').click();
assert(byId('connectionState').textContent === 'CLOSED', 'Stopping companion should close the projection');
assert(!byId('studyView').hidden, 'Closing A2A must not terminate the app learning session');

console.log('INTERACTION_SMOKE=PASS');
