import { CONFUSION_PAIR, CONFUSION_SCENARIOS, REVIEW_WORDS } from '../domain/LearningContent';

@Entry
@Component
struct Index {
  @State private scenario: string = 'review';
  @State private view: string = 'home';
  @State private sessionState: string = 'READY';
  @State private appAgentMessage: string = '今天有 6 个词到期，其中 2 个上次依赖提示才想起。';
  @State private currentIndex: number = 0;
  @State private completedCount: number = 0;
  @State private hintLevel: number = 0;
  @State private attemptRecorded: boolean = false;
  @State private lastOutcome: string = '';
  @State private independentRecall: number = 0;
  @State private hintedRecall: number = 0;
  @State private missed: number = 0;
  @State private deepRound: number = 0;
  @State private deepChoice: string = '';
  @State private deepCompleted: boolean = false;

  private selectScenario(next: string): void {
    this.scenario = next;
    this.deepChoice = '';
    this.deepCompleted = false;
    if (next === 'deep') {
      this.view = 'deep';
      this.sessionState = 'WAITING_FOR_JUDGMENT';
      this.appAgentMessage = '应用 Agent 已创建新的辨析练习。先做情境判断，再解释关键差别。';
      return;
    }
    if (next === 'resume') {
      this.view = 'study';
      this.sessionState = 'IN_PROGRESS';
      this.currentIndex = 1;
      this.completedCount = 1;
      this.independentRecall = 1;
      this.hintedRecall = 0;
      this.missed = 0;
      this.hintLevel = 1;
      this.attemptRecorded = false;
      this.lastOutcome = '';
      this.appAgentMessage = '应用 Agent 已从本地学习记录恢复到第 2 个词：完成 1 / 3，提示 1 / 2 已保留。';
      return;
    }
    this.resetReview();
  }

  private resetReview(): void {
    this.scenario = 'review';
    this.view = 'home';
    this.sessionState = 'READY';
    this.currentIndex = 0;
    this.completedCount = 0;
    this.hintLevel = 0;
    this.attemptRecorded = false;
    this.lastOutcome = '';
    this.independentRecall = 0;
    this.hintedRecall = 0;
    this.missed = 0;
    this.appAgentMessage = '今天有 6 个词到期，其中 2 个上次依赖提示才想起。';
  }

  private startReview(): void {
    this.view = 'study';
    this.sessionState = 'IN_PROGRESS';
    this.appAgentMessage = '本地学习会话已开始。先主动回忆，需要时再请求提示。';
  }

  private requestHint(): void {
    if (this.hintLevel < 2) {
      this.hintLevel += 1;
    }
    this.sessionState = 'IN_PROGRESS';
    this.appAgentMessage = `当前停在 ${REVIEW_WORDS[this.currentIndex].word}，已使用提示 ${this.hintLevel} / 2。`;
  }

  private recordAttempt(outcome: string): void {
    if (this.attemptRecorded) return;
    this.attemptRecorded = true;
    this.lastOutcome = outcome;
    this.completedCount += 1;
    if (outcome === 'know') this.independentRecall += 1;
    else if (outcome === 'hinted') this.hintedRecall += 1;
    else this.missed += 1;
    this.sessionState = 'EVIDENCE_RECORDED';
    this.appAgentMessage = `应用 Agent 已记录 ${this.completedCount} / ${REVIEW_WORDS.length}，请确认答案后继续。`;
  }

  private advanceReview(): void {
    if (this.currentIndex >= REVIEW_WORDS.length - 1) {
      this.view = 'summary';
      this.sessionState = 'COMPLETED';
      this.appAgentMessage = '本地学习会话已完成，复盘与下一次应用内复测建议已经生成。';
      return;
    }
    this.currentIndex += 1;
    this.hintLevel = 0;
    this.attemptRecorded = false;
    this.lastOutcome = '';
    this.sessionState = 'IN_PROGRESS';
    this.appAgentMessage = `继续第 ${this.currentIndex + 1} 个词，已完成 ${this.completedCount} / ${REVIEW_WORDS.length}。`;
  }

  private pauseSession(): void {
    this.scenario = 'review';
    this.view = 'home';
    this.sessionState = 'PAUSED';
    this.appAgentMessage = `本地会话已暂停；已完成 ${this.completedCount} / ${REVIEW_WORDS.length}，学习记录仍归应用 Agent 所有。`;
  }

  private chooseDeep(choice: string): void {
    this.deepChoice = choice;
    this.deepCompleted = true;
    this.sessionState = 'COMPLETED';
    this.appAgentMessage = '辨析已完成，应用 Agent 已保存判断证据和 24 小时后的复测建议。';
  }

  private retryDeep(): void {
    this.deepRound = this.deepRound === 0 ? 1 : 0;
    this.deepChoice = '';
    this.deepCompleted = false;
    this.sessionState = 'WAITING_FOR_JUDGMENT';
    this.appAgentMessage = '应用 Agent 已生成一个不同情境，请先判断，再查看解释。';
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text('回声词伴')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#17211D')
            Text('先让你想起来，再让 AI 帮你理解')
              .fontSize(13)
              .fontColor('#5D665F')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('App Agent · 0.4.0')
            .fontSize(11)
            .fontColor('#245E4B')
            .backgroundColor('#D9E9DF')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(16)
        }
        .width('100%')

        Row({ space: 8 }) {
          Button('今日抽背')
            .fontSize(12)
            .fontColor(this.scenario === 'review' ? '#FFFDF8' : '#5D665F')
            .backgroundColor(this.scenario === 'review' ? '#245E4B' : '#E7E1D5')
            .onClick(() => this.selectScenario('review'))
          Button('深度理解')
            .fontSize(12)
            .fontColor(this.scenario === 'deep' ? '#FFFDF8' : '#5D665F')
            .backgroundColor(this.scenario === 'deep' ? '#245E4B' : '#E7E1D5')
            .onClick(() => this.selectScenario('deep'))
          Button('本地恢复')
            .fontSize(12)
            .fontColor(this.scenario === 'resume' ? '#FFFDF8' : '#5D665F')
            .backgroundColor(this.scenario === 'resume' ? '#245E4B' : '#E7E1D5')
            .onClick(() => this.selectScenario('resume'))
        }
        .width('100%')
        .margin({ top: 22 })

        Column() {
          Row() {
            Text('来自小艺的公开意图')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#245E4B')
            Blank()
            Text('CLOSED_AFTER_HANDOFF')
              .fontSize(10)
              .fontColor('#245E4B')
              .backgroundColor('#D9E9DF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(12)
          }
          .width('100%')
          Text(this.scenario === 'deep' ? 'PRACTICE_CONFUSION_IN_APP' : 'START_REVIEW_IN_APP')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#17211D')
            .margin({ top: 10 })
          Text('小艺完成系统入口与应用交接后，默认结束本次 A2A 协作；应用内学习不依赖连接继续存在。')
            .fontSize(13)
            .fontColor('#5D665F')
            .lineHeight(20)
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .margin({ top: 14 })
        .backgroundColor('#D9E9DF')
        .borderRadius(20)

        Column() {
          Row() {
            Text('应用 Agent · 本地学习会话')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#245E4B')
            Blank()
            Text(this.sessionState)
              .fontSize(10)
              .fontColor('#245E4B')
              .backgroundColor('#D9E9DF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(12)
          }
          .width('100%')
          Text(this.appAgentMessage)
            .fontSize(14)
            .fontColor('#17211D')
            .lineHeight(21)
            .margin({ top: 10 })
          Row({ space: 10 }) {
            Button(this.sessionState === 'COMPLETED' ? '打开复盘' : this.sessionState === 'PAUSED' ? '会话已暂停' : '继续学习')
              .layoutWeight(1)
              .fontColor('#FFFDF8')
              .backgroundColor('#245E4B')
              .enabled(this.sessionState !== 'PAUSED')
              .onClick(() => {
                if (this.sessionState === 'COMPLETED') {
                  if (this.scenario === 'deep') this.view = 'deep';
                  else this.view = 'summary';
                } else if (this.scenario === 'deep') {
                  this.view = 'deep';
                } else if (this.sessionState === 'READY') {
                  this.startReview();
                } else if (this.sessionState !== 'PAUSED') {
                  this.view = 'study';
                }
              })
            if (this.sessionState !== 'COMPLETED' && this.sessionState !== 'PAUSED') {
              Button('暂停')
                .fontColor('#8B4538')
                .backgroundColor('#FFE1D8')
                .onClick(() => this.pauseSession())
            }
          }
          .width('100%')
          .margin({ top: 14 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .margin({ top: 14 })
        .backgroundColor('#FFFDF8')
        .borderRadius(20)

        if (this.view === 'home') {
          Column() {
            Text(this.sessionState === 'PAUSED' ? '本地会话已暂停，随时可以重开' : '6 个词正在等你想起')
              .fontSize(31)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFDF8')
            Text(this.sessionState === 'PAUSED'
              ? '已完成部分仍保存在应用内；重新开始时由应用 Agent 创建一轮清晰的新会话。'
              : '3 个今天到期，2 个上次依赖提示，1 个与近义词反复混淆。')
              .fontSize(14)
              .fontColor('#D9E9DF')
              .lineHeight(22)
              .margin({ top: 12 })
            Button(this.sessionState === 'PAUSED' ? '重新开始' : '开始抽背')
              .fontColor('#17211D')
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#D9EF8D')
              .margin({ top: 28 })
              .onClick(() => {
                if (this.sessionState === 'PAUSED') this.resetReview();
                this.startReview();
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(26)
          .margin({ top: 18 })
          .backgroundColor('#245E4B')
          .borderRadius(26)

          Row() {
            Column() {
              Text('72%').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#17211D')
              Text('近 7 天独立想起').fontSize(12).fontColor('#5D665F').margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Column() {
              Text('19%').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#17211D')
              Text('提示后想起').fontSize(12).fontColor('#5D665F').margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 24 })
          .padding({ left: 8, right: 8 })

          Column() {
            Text('需要系统能力时，再回到小艺')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#245E4B')
            Text('系统提醒和退出应用后的系统伴随不属于应用内 Agent。目标设备能力尚未验证，因此这里不显示“已创建”或“已开启”。')
              .fontSize(13)
              .fontColor('#5D665F')
              .lineHeight(20)
              .margin({ top: 8 })
            Row({ space: 8 }) {
              Button('让小艺处理提醒 · 待验证')
                .layoutWeight(1)
                .fontSize(11)
                .fontColor('#5D665F')
                .backgroundColor('#E7E1D5')
                .enabled(false)
              Button('开启系统伴随 · 待验证')
                .layoutWeight(1)
                .fontSize(11)
                .fontColor('#5D665F')
                .backgroundColor('#E7E1D5')
                .enabled(false)
            }
            .width('100%')
            .margin({ top: 14 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .margin({ top: 22 })
          .backgroundColor('#FFFDF8')
          .borderRadius(20)
        } else if (this.view === 'study') {
          if (this.scenario === 'resume') {
            Text('已恢复：第 2 个词 · 提示 1 / 2 · 完成 1 / 3')
              .fontSize(12)
              .fontColor('#245E4B')
              .backgroundColor('#D9E9DF')
              .padding(12)
              .borderRadius(14)
              .width('100%')
              .margin({ top: 18 })
          }

          Row() {
            Text(`第 ${this.currentIndex + 1} 个，共 ${REVIEW_WORDS.length} 个`).fontSize(12).fontColor('#5D665F')
            Blank()
            Text(this.attemptRecorded ? '已记录，等待继续' : '等待你的回忆').fontSize(12).fontColor('#5D665F')
          }
          .width('100%')
          .margin({ top: 22 })

          Progress({ value: this.completedCount, total: REVIEW_WORDS.length, type: ProgressType.Linear })
            .color('#EF765F')
            .backgroundColor('#E7E1D5')
            .width('100%')
            .margin({ top: 10 })

          Column() {
            Text('先回忆，再求助')
              .fontSize(12)
              .fontColor('#5D665F')
            Text(REVIEW_WORDS[this.currentIndex].word)
              .fontSize(44)
              .fontWeight(FontWeight.Medium)
              .fontColor('#17211D')
              .margin({ top: 22 })
            Text(REVIEW_WORDS[this.currentIndex].phonetic)
              .fontSize(15)
              .fontColor('#5D665F')
              .margin({ top: 4 })
            Text(REVIEW_WORDS[this.currentIndex].prompt)
              .fontSize(16)
              .fontColor('#5D665F')
              .lineHeight(24)
              .margin({ top: 22 })
          }
          .width('100%')
          .margin({ top: 26 })

          if (this.hintLevel > 0 && !this.attemptRecorded) {
            Column() {
              Text(`提示 ${this.hintLevel} / 2`)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#245E4B')
              Text(REVIEW_WORDS[this.currentIndex].hints[this.hintLevel - 1])
                .fontSize(14)
                .fontColor('#17211D')
                .lineHeight(22)
                .margin({ top: 8 })
              Text('答案仍然隐藏。请再主动回忆一次。')
                .fontSize(12)
                .fontColor('#5D665F')
                .margin({ top: 10 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(18)
            .margin({ top: 22 })
            .backgroundColor('#D9E9DF')
            .borderRadius(18)
          }

          if (this.attemptRecorded) {
            Column() {
              Text(this.lastOutcome === 'know' ? '独立想起' : this.lastOutcome === 'hinted' ? `提示 ${this.hintLevel} 后想起` : '两层提示后仍未想起')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8B4538')
              Text(REVIEW_WORDS[this.currentIndex].answer)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#17211D')
                .margin({ top: 8 })
              Text(REVIEW_WORDS[this.currentIndex].contrast)
                .fontSize(13)
                .fontColor('#5D665F')
                .lineHeight(20)
                .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(18)
            .margin({ top: 18 })
            .backgroundColor('#FFE1D8')
            .borderRadius(18)

            Button(this.currentIndex === REVIEW_WORDS.length - 1 ? '生成复盘' : '下一词')
              .width('100%')
              .fontColor('#FFFDF8')
              .backgroundColor('#245E4B')
              .margin({ top: 16 })
              .onClick(() => this.advanceReview())
          } else if (this.hintLevel === 0) {
            Row({ space: 8 }) {
              Button('我会')
                .layoutWeight(1)
                .backgroundColor('#245E4B')
                .onClick(() => this.recordAttempt('know'))
              Button('有点模糊')
                .layoutWeight(1)
                .fontColor('#17211D')
                .backgroundColor('#D9EF8D')
                .onClick(() => this.requestHint())
              Button('不会')
                .layoutWeight(1)
                .fontColor('#17211D')
                .backgroundColor('#E7E1D5')
                .onClick(() => this.requestHint())
            }
            .width('100%')
            .margin({ top: 24 })
          } else {
            Row({ space: 8 }) {
              Button('提示后想起')
                .layoutWeight(1)
                .backgroundColor('#245E4B')
                .onClick(() => this.recordAttempt('hinted'))
              if (this.hintLevel < 2) {
                Button('再给一层')
                  .layoutWeight(1)
                  .fontColor('#17211D')
                  .backgroundColor('#D9EF8D')
                  .onClick(() => this.requestHint())
              } else {
                Button('仍没想起')
                  .layoutWeight(1)
                  .fontColor('#17211D')
                  .backgroundColor('#E7E1D5')
                  .onClick(() => this.recordAttempt('miss'))
              }
            }
            .width('100%')
            .margin({ top: 18 })
          }
        } else if (this.view === 'deep') {
          Column() {
            Text('深度理解 · 先判断，后解释')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#245E4B')
            Text(CONFUSION_SCENARIOS[this.deepRound].situation)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#17211D')
              .lineHeight(31)
              .margin({ top: 20 })
            Text(`这里更准确的是 ${CONFUSION_PAIR[0]} 还是 ${CONFUSION_PAIR[1]}？`)
              .fontSize(14)
              .fontColor('#5D665F')
              .margin({ top: 12 })
            if (!this.deepCompleted) {
              Row({ space: 10 }) {
                Button(CONFUSION_PAIR[0])
                  .layoutWeight(1)
                  .backgroundColor('#245E4B')
                  .onClick(() => this.chooseDeep(CONFUSION_PAIR[0]))
                Button(CONFUSION_PAIR[1])
                  .layoutWeight(1)
                  .fontColor('#17211D')
                  .backgroundColor('#D9EF8D')
                  .onClick(() => this.chooseDeep(CONFUSION_PAIR[1]))
              }
              .width('100%')
              .margin({ top: 24 })
              Text('解释在你作出判断后才会出现。')
                .fontSize(12)
                .fontColor('#5D665F')
                .margin({ top: 12 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(22)
          .margin({ top: 18 })
          .backgroundColor('#FFFDF8')
          .borderRadius(22)

          if (this.deepCompleted) {
            Column() {
              Text(this.deepChoice === CONFUSION_SCENARIOS[this.deepRound].answer ? '判断正确' : '这次仍有混淆')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8B4538')
              Text(CONFUSION_SCENARIOS[this.deepRound].explanation)
                .fontSize(15)
                .fontColor('#17211D')
                .lineHeight(23)
                .margin({ top: 8 })
              Text('学习产物 · 24 小时后用新情境复测')
                .fontSize(12)
                .fontColor('#245E4B')
                .backgroundColor('#D9E9DF')
                .padding(10)
                .borderRadius(12)
                .margin({ top: 14 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(18)
            .margin({ top: 14 })
            .backgroundColor('#FFE1D8')
            .borderRadius(18)

            Button('换一个情境再判断')
              .width('100%')
              .fontColor('#FFFDF8')
              .backgroundColor('#245E4B')
              .margin({ top: 16 })
              .onClick(() => this.retryDeep())
          }
        } else {
          Column() {
            Text('本轮复盘')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#245E4B')
            Text(`${this.completedCount} / ${REVIEW_WORDS.length} 个词已形成学习证据`)
              .fontSize(27)
              .fontWeight(FontWeight.Bold)
              .fontColor('#17211D')
              .lineHeight(36)
              .margin({ top: 12 })
            Row() {
              Column() {
                Text(`${this.independentRecall}`).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#17211D')
                Text('独立想起').fontSize(12).fontColor('#5D665F')
              }
              .layoutWeight(1)
              Column() {
                Text(`${this.hintedRecall}`).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#17211D')
                Text('提示后想起').fontSize(12).fontColor('#5D665F')
              }
              .layoutWeight(1)
              Column() {
                Text(`${this.missed}`).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#17211D')
                Text('仍未想起').fontSize(12).fontColor('#5D665F')
              }
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 24 })
            Text('下一步：优先复测依赖提示或未想起的词；系统入口会返回本复盘，不会重建任务。')
              .fontSize(14)
              .fontColor('#5D665F')
              .lineHeight(22)
              .margin({ top: 22 })
            Button('开始新一轮')
              .width('100%')
              .fontColor('#FFFDF8')
              .backgroundColor('#245E4B')
              .margin({ top: 22 })
              .onClick(() => this.resetReview())
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(24)
          .margin({ top: 18 })
          .backgroundColor('#FFFDF8')
          .borderRadius(24)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 26, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F0E8')
  }
}
