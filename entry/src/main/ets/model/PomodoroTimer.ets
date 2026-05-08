import systemDateTime from '@ohos.systemDateTime'; // 华为鸿蒙获取系统时间的模块

/**
 * 定义时间表单项的数据结构（相当于 Python 中的 dict 约束）
 */
export interface ScheduleItem {
  name: string;
  timeMinutes: number;
}

/**
 * 番茄钟核心逻辑类
 */
export class PomodoroTimer {
  // --- 成员变量 (小驼峰命名) ---
  focusDuration:      number;
  shortBreakDuration: number;
  longBreakDuration:  number;
  focusCycleCount:    number;

  timeSchedule: Array<ScheduleItem>;
  timePointer:  number;

  // 时间戳相关 (单位：毫秒)
  private timerId:          number;   // 定时器ID，用于清除 setInterval
  private startTimestamp:   number;   // 开始时间戳 (毫秒)
  private targetDurationMs: number;   // 目标时间戳差值 (从开始到结束需要的毫秒数)
  private isPaused:         boolean;  // 标记当前是否处于暂停状态


  /**
   * 初始化函数 (构造函数)
   * @param focusDuration 专注时长，单位分钟，默认 25
   * @param shortBreakDuration 短休息时长，单位分钟，默认 5
   * @param longBreakDuration 长休息时长，单位分钟，默认 15
   * @param focusCycleCount 专注时段数目，默认 4
   */
  constructor(
    // focusDuration: number = 25,
    // shortBreakDuration: number = 5,
    // longBreakDuration: number = 15,
    // focusCycleCount: number = 4

    // for test
    focusDuration: number = 2,
    shortBreakDuration: number = 1,
    longBreakDuration: number = 2,
    focusCycleCount: number = 4
  ) {
    this.focusDuration = focusDuration;
    this.shortBreakDuration = shortBreakDuration;
    this.longBreakDuration = longBreakDuration;
    this.focusCycleCount = focusCycleCount;

    this.timeSchedule = [];
    this.timePointer = -1;

    this.timerId = -1;
    this.startTimestamp = 0;
    this.targetDurationMs = 0;
    this.isPaused = true;
  }

  // --- 成员函数 (下划线命名) ---
  /**
   * 9. 格式化时间辅助函数 (展示分和秒)
   */
  format_time_display(ms: number): string {
    const totalSeconds = Math.ceil(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;

    // 使用 padStart 进行前导补零，例如 5 -> "05"
    const mStr = minutes.toString().padStart(2, '0');
    const sStr = seconds.toString().padStart(2, '0');

    return `${mStr}:${sStr}`;
  }

  get currentTitle(): string {
    if (this.timePointer == -1 || this.timeSchedule.length == 0 || this.is_out_of_bounds())  {
      return 'Ready' // 统一改为 Ready 表示未开始
    } else {
      return this.timeSchedule[this.timePointer].name
    }
  }
  /**
   * 1. 生成专注时段函数
   * 根据成员变量生成完整的 番茄钟时间表。
   */
  generate_schedule(): void {
    this.timeSchedule = [];
    for (let i = 0; i < this.focusCycleCount; i++) {
      this.timeSchedule.push({ name: `Focus ${i+1}`, timeMinutes: this.focusDuration });
      this.timeSchedule.push({ name: `Rest ${i+1}`, timeMinutes: this.shortBreakDuration });
    }
    // 将最后一个休息修改为长休息
    if (this.timeSchedule.length > 0) {
      this.timeSchedule[this.timeSchedule.length - 1].timeMinutes = this.longBreakDuration;
    }
  }
  /**
   * 4. 开始/恢复番茄钟
   * 每 500ms 更新一次，通过回调将格式化后的时间传给 UI
   */
  start_timer(on_tick: (displayTime: string) => void, on_finish: () => void): void {
    // 修复：删掉强行 timePointer += 1 的逻辑，未初始化则直接返回，依赖外部先调 next_period
    if (this.timePointer == -1 || this.is_out_of_bounds()) return;
    if (!this.isPaused) return;

    this.isPaused = false;
    this.startTimestamp = Date.now();

    this.timerId = setInterval(() => {
      const currentTime = Date.now();
      const elapsed = currentTime - this.startTimestamp;
      const remainingMs = this.targetDurationMs - elapsed;

      if (remainingMs <= 0) {
        this.clear_interval(); // 使用内部清理方法
        on_tick(this.format_time_display(0));
        on_finish();
      } else {
        on_tick(this.format_time_display(remainingMs));
      }
    }, 500);
  }
  /**
   * 5. 暂停番茄钟函数
   * 计算并保存差值，停止系统的 setInterval
   * 事实上采用了减少目标时间的方法
   */
  pause_timer(): void {
    if (!this.isPaused && this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;

      // 核心逻辑：从目标总时长中扣除已经流逝的时间，保存剩余差值
      const elapsed = Date.now() - this.startTimestamp;
      this.targetDurationMs = this.targetDurationMs - elapsed;

      this.isPaused = true;
    }
  }

  // 新增/修改：将原先的 exit_timer 改名为 clear_interval，明确其仅作为内部工具函数
  private clear_interval(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.isPaused = true;
  }

  // 跳过当前
  skip_period(on_finish: () => void): void {
    this.clear_interval();
    this.targetDurationMs = 0;
    on_finish();
  }

  // 彻底退出的重置
  reset(): void {
    this.clear_interval();
    this.timePointer = -1;
    this.targetDurationMs = 0;
  }
  /**
   * 2. 进入下一个时长
   * 移动时间指针，并为下一个阶段的倒计时做准备
   */
  next_period(): void {
    this.clear_interval(); // 清理可能的旧计时器
    this.timePointer += 1;

    if (!this.is_out_of_bounds()) {
      this.targetDurationMs = this.timeSchedule[this.timePointer].timeMinutes * 60 * 1000;
      this.isPaused = true;
    }
  }

  /**
   * 3. 检查是否超出时间表的函数
   * 用于错误处理和判断一整轮番茄钟是否结束
   * @returns boolean 是否越界
   */
  is_out_of_bounds(): boolean {
    return this.timePointer >= this.timeSchedule.length || this.timePointer < 0;
  }

  /**
   * 5. 倒计时相关函数：暂停/停止倒计时
   */
  stop_countdown(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId); // 清除系统定时器
      this.timerId = -1;
    }
  }

  /**
   * 6. 在整个时间表结束之后继续循环的函数
   * 重置指针，重新开始当前生成的 schedule
   */
  continue_loop(): void {
    this.stop_countdown();
    this.timePointer = -1;
    this.next_period(); // 指针走向 0，并初始化秒数
  }
  /**
   * 8. 获取当前倒计时时间函数 (格式化输出)
   * 供内部调用或 UI 主动拉取使用
   */
  get currentCountdownTime(): string {
    let remainingMs = this.targetDurationMs;
    // 如果正在运行，需要实时计算剩余时间
    if (!this.isPaused) {
      const elapsed = Date.now() - this.startTimestamp;
      remainingMs = this.targetDurationMs - elapsed;
    }
    // 防止出现负数
    return this.format_time_display(Math.max(0, remainingMs));
  }
}