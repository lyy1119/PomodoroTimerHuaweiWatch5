// entry/src/main/ets/pages/Index.ets

// 假设你的逻辑类放在 ../model/PomodoroTimer.ets
import { PomodoroTimer } from '../model/PomodoroTimer';
import vibrator from '@ohos.vibrator';
import { SettingPickerView } from './SettingPickerView';

@Entry
@Component
struct Index {
  // 触发震动
  triggerVibration() {
    try {
      // 鸿蒙提供的时间震动接口，duration 单位为毫秒，5000即为5秒
      vibrator.startVibration({
        type: 'time',
        duration: 5000,
      }, {
        id: 0,
        usage: 'alarm' // 使用闹钟级别的震动策略
      });
    } catch (error) {
      console.error('Vibration failed:', error);
    }
  }

  // 手动停止震动 (可绑定到弹窗的关闭按钮或主界面的停止按钮上)
  stopVibration() {
    try {
      vibrator.stopVibration(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME);
    } catch (error) {
      console.error('Stop vibration failed:', error);
    }
  }
  // 在 struct Index 内部，build() 方法之外添加：

  handleTimeUp() {
    // 1. 触发震动（最长5秒）
    this.triggerVibration();

    // 2. 检查是否开启了自动进入下一阶段
    if (this.autoStart) {
      this.timer.next_period(); // 逻辑层进入下一时段

      // 检查整个番茄钟循环是否已经结束（例如已经完成了4个专注+休息）
      if (this.timer.is_out_of_bounds()) {
        this.isRunning = false;
        this.currentTitle = "All Done!";
        this.displayTime = "00:00";
        // TODO: 可以弹出对话框询问是否重新开始一轮
      } else {
        // 同步 UI 并自动无缝开始下一个倒计时
        this.currentTitle = this.timer.currentTitle;
        this.displayTime = this.timer.currentCountdownTime;

        // 递归调用 start_timer
        this.timer.start_timer(
          (timeString: string) => {
            this.currentTitle = this.timer.currentTitle; // 关键修复：确保自动进入下一阶段时标题能刷新
            this.displayTime = timeString;
          },
          () => { this.handleTimeUp(); }
        );
      }
    } else {
      // 如果没有开启自动开始，则停留在等待状态
      this.isRunning = false;
      this.timer.next_period(); // 逻辑推到下一时段，但不 start

      if (!this.timer.is_out_of_bounds()) {
        this.currentTitle = this.timer.currentTitle;
        this.displayTime = this.timer.currentCountdownTime;
      } else {
        this.currentTitle = "All Done!";
      }
      // TODO: 弹出包含“✔”和“×”的 CustomDialog 对话框等待用户点击
    }
  }
  // --- 状态变量 (用于驱动 UI 更新) ---
  timer: PomodoroTimer = new PomodoroTimer();

  @State currentTitle: string = this.timer.currentTitle;      // 对应你的 timer.currentTitle
  @State displayTime: string = this.timer.currentCountdownTime;       // 倒计时显示文本
  @State isRunning: boolean = false;          // 控制播放/暂停按钮状态

  // 设置界面的状态变量
  @State autoStart: boolean = true;
  @State focusDuration: number = this.timer.focusDuration;
  @State shortBreakDuration: number = this.timer.shortBreakDuration;
  @State longBreakDuration: number = this.timer.longBreakDuration;
  @State focusCycleCount: number = this.timer.focusCycleCount;

  @State activeSettingTarget: string = '';

  // 保存设置并同步到底层逻辑类
  save_setting(target: string, value: number): void {
    switch (target) {
      case 'focus':
        this.focusDuration = value;
        this.timer.focusDuration = value;
        break;
      case 'shortBreak':
        this.shortBreakDuration = value;
        this.timer.shortBreakDuration = value;
        break;
      case 'longBreak':
        this.longBreakDuration = value;
        this.timer.longBreakDuration = value;
        break;
      case 'cycle':
        this.focusCycleCount = value;
        this.timer.focusCycleCount = value;
        break;
    }
    // 关闭选择器界面
    this.activeSettingTarget = '';

    // 如果当前没有在运行，且被彻底重置过，重新生成一下初始状态以防用户立刻点击开始
    if (!this.isRunning && this.timer.timePointer === -1) {
      // TODO: 更新UI显示的默认时间（比如用户把25分改成了30分，立刻更新倒计时文字）
      // this.timer.targetDurationMs = this.timer.focusDuration * 60 * 1000;
      this.displayTime = this.timer.currentCountdownTime;
    }
  }

  build() {
    // Swiper 组件实现左右滑动
    Swiper() {
      // ==========================================
      // 第一页：主界面 (倒计时界面)
      // ==========================================
      Column() {
        // 1. 标题
        Text(this.currentTitle)
          .fontSize(20)
          .fontColor(Color.Gray)
          .margin({ top: 15, bottom: 10 })

        // 2. 倒计时 (分秒)
        Text(this.displayTime)
          .fontSize(60)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 15 })

        // 3. 控制按钮
        Row() {
          // 退出按钮
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark')) // 替换 ×
              .fontSize(24)
              .fontColor([Color.White])
            }
            .width(50).height(50)
            .backgroundColor('#FF4444')
            .onClick(() => {
              // TODO: 调用 timer.exit_timer() 和重置 UI 逻辑
              this.timer.reset()
              this.currentTitle = this.timer.currentTitle;
              this.displayTime = this.timer.currentCountdownTime;
              this.isRunning = false; // update pause/continue button state
            })

          // 暂停/继续按钮
          Button({ type: ButtonType.Circle }) {
            // 根据状态切换 暂停 或 播放 图标
            SymbolGlyph(this.isRunning ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(24)
              .fontColor([Color.White])
            }
            .width(50).height(50)
            .backgroundColor('#4488FF')
            .onClick(() => {
              this.isRunning = !this.isRunning;

              if (this.isRunning) {
                // initial
                if (this.timer.timePointer === -1) { // need init
                  this.timer.generate_schedule();
                  this.timer.next_period();
                }
                // 调用 timer.start_timer(...)
                this.timer.start_timer((timeString: string) => {
                  this.currentTitle = this.timer.currentTitle;
                  this.displayTime = timeString
                }, () => {
                  // 震动、弹窗、重置功能按键
                  // 时间结束的回调
                  this.handleTimeUp(); // 提取成一个专门的方法，方便处理震动和自动下一阶段
                })

              } else {
                // TODO: 调用 timer.pause_timer()
                this.timer.pause_timer()
              }
            })

          // 跳过按钮
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.checkmark')) // 替换 ✔
              .fontSize(24)
              .fontColor([Color.White])
            }
            .width(50).height(50)
            .backgroundColor('#44FF44')
            .onClick(() => {
              // TODO: 调用 timer.skip_period(...)
              this.timer.skip_period(() => {
                this.handleTimeUp(); // 关键修复：填入回调，通知系统时间到了
              })
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly) // 按钮水平均匀分布
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000') // 手表背景通常为纯黑以省电
      .justifyContent(FlexAlign.Center)

      // ==========================================
      // 第二页：设置界面
      // ==========================================
      Column() {
        if (this.activeSettingTarget === 'focus') {
          SettingPickerView({ title: "专注时长", currentValue: this.focusDuration, on_confirm: (val) => this.save_setting('focus', val) })
        } else if (this.activeSettingTarget === 'shortBreak') {
          SettingPickerView({ title: "短休息时长", currentValue: this.shortBreakDuration, on_confirm: (val) => this.save_setting('shortBreak', val) })
        } else if (this.activeSettingTarget === 'longBreak') {
          SettingPickerView({ title: "长休息时长", currentValue: this.longBreakDuration, on_confirm: (val) => this.save_setting('longBreak', val) })
        } else if (this.activeSettingTarget === 'cycle') {
          SettingPickerView({ title: "专注时段数目", currentValue: this.focusCycleCount, on_confirm: (val) => this.save_setting('cycle', val) })
        } else {
          Text("设置")
            .fontSize(20)
            .fontColor(Color.White)
            .margin({ top: 30, bottom: 10 })

          // 滚动列表
          List({ space: 10 }) {
            // 1. 专注时长
            ListItem() {
              this.SettingItemText("专注时长", `${this.focusDuration} 分钟 >`)
            }.onClick(() => { this.activeSettingTarget = 'focus'; })

            // 2. 短休息时长
            ListItem() {
              this.SettingItemText("短休息时长", `${this.shortBreakDuration} 分钟 >`)
            }.onClick(() => { this.activeSettingTarget = 'shortBreak'; })

            // 3. 长休息时长
            ListItem() {
              this.SettingItemText("长休息时长", `${this.longBreakDuration} 分钟 >`)
            }.onClick(() => { this.activeSettingTarget = 'longBreak'; })

            // 4. 自动开始开关
            ListItem() {
              Row() {
                Text("自动开始时段").fontSize(16).fontColor(Color.White)
                Toggle({ type: ToggleType.Switch, isOn: this.autoStart })
                  .onChange((isOn: boolean) => {
                    this.autoStart = isOn;
                  })
              }
              .width('100%')
              .padding({
                left: 20,
                right: 20,
                top: 15,
                bottom: 15
              })
              .justifyContent(FlexAlign.SpaceBetween)
              .backgroundColor('#222222')
              .borderRadius(10)
            }

            // 5. 专注时段数目
            ListItem() {
              this.SettingItemText("专注时段数目", `${this.focusCycleCount} 个 >`)
            }.onClick(() => { this.activeSettingTarget = 'cycle'; })

            // 底部留白，方便滚动到底部
            ListItem() {
              Column() {
                Text("Pomodoro V1.0")
                  .fontSize(12)
                  .fontColor(Color.Gray)
                  .margin({ top: 10 })
                Text("Developer: Lycarus")
                  .fontSize(12)
                  .fontColor(Color.Gray)
                  .margin({ top: 5, bottom: 90 }) // 底部加大的 margin 是为了适应原型表盘的弧度
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            }
          }
          .width('90%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
    }
    .indicator(false) // 隐藏 Swiper 底部的轮播小圆点
    .loop(false)      // 禁用循环滑动（滑到设置页后不能再往左滑回主页）
  }

  // 辅助构建函数：用于复用设置项的普通文本 UI
  @Builder SettingItemText(title: string, value: string) {
    Row() {
      Text(title).fontSize(16).fontColor(Color.White)
      Text(value).fontSize(16).fontColor(Color.Gray)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 15, bottom: 15 })
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor('#222222')
    .borderRadius(10)
  }
}