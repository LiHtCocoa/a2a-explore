export interface ReviewWordContent {
  word: string;
  phonetic: string;
  prompt: string;
  hints: string[];
  answer: string;
  contrast: string;
  acceptedTokens: string[];
}

export interface ConfusionScenario {
  situation: string;
  question: string;
  answer: string;
  explanation: string;
}

export const REVIEW_WORDS: ReviewWordContent[] = [
  {
    word: 'resilient',
    phonetic: '/rɪˈzɪliənt/',
    prompt: '不看答案：resilient 更接近“抵抗变化”，还是“受压后恢复”？',
    hints: [
      '提示 1 / 2：它强调经历压力之后的变化。',
      '提示 2 / 2：想想被压弯后还能弹回来的树枝。'
    ],
    answer: '有韧性的；能从困难中恢复的',
    contrast: 'resistant 强调抵抗；resilient 强调受压后的恢复。',
    acceptedTokens: ['恢复', '韧', '弹回', 'recover', 'bounce']
  },
  {
    word: 'subtle',
    phonetic: '/ˈsʌtl/',
    prompt: '不看答案：subtle 形容一种怎样的差别或表达？',
    hints: [
      '提示 1 / 2：这种差别通常不明显，需要仔细感受。',
      '提示 2 / 2：它和 obvious 几乎站在相反方向。'
    ],
    answer: '微妙的；不易察觉的',
    contrast: '常见搭配：a subtle difference / a subtle hint。',
    acceptedTokens: ['微妙', '细微', '不明显', '不易察觉', 'subtle']
  },
  {
    word: 'compelling',
    phonetic: '/kəmˈpelɪŋ/',
    prompt: '不看答案：一段论证 compelling，意味着什么？',
    hints: [
      '提示 1 / 2：它不只是 interesting，而是让人很难忽视。',
      '提示 2 / 2：可以从 compel“迫使”联想它的力量感。'
    ],
    answer: '令人信服的；有强烈吸引力的',
    contrast: '语境决定更接近“有说服力”还是“引人入胜”。',
    acceptedTokens: ['信服', '说服', '吸引', 'convinc', 'persuasive']
  }
];

export const CONFUSION_PAIR: string[] = ['resilient', 'resistant'];

export const CONFUSION_SCENARIOS: ConfusionScenario[] = [
  {
    situation: '“她经历挫折后，很快恢复了状态。”',
    question: '先不看解释：描述“经历挫折后很快恢复”，更准确的是 resilient 还是 resistant？',
    answer: 'resilient',
    explanation: 'resistant 强调抵抗或不受影响；resilient 强调经历冲击后仍能恢复。'
  },
  {
    situation: '“这种涂层不容易被水侵蚀。”',
    question: '先不看解释：描述“不容易受水侵蚀”，更准确的是 resilient 还是 resistant？',
    answer: 'resistant',
    explanation: 'water-resistant 强调抵抗水的影响；若强调受损后恢复原状，才更接近 resilient。'
  }
];

export const CONFUSION_HINT = '提示：一个词强调抵抗外力，另一个词强调受压后的恢复。请再判断。';
