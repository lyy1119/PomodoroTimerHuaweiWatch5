// entry/src/main/ets/pages/SettingPickerView.ets

@Component
export struct SettingPickerView {
  // --- 传入的属性与回调 ---
  @Prop title: string = "设置项";      // 设置项标题
  @State currentValue: number = 0;   // 当前选中的值

  // 确定按钮的回调函数 (下划线命名法)
  on_confirm: (value: number) => void = () => {};

  // --- 内部数据 ---
  // 生成 0 到 99 的字符串数组
  private rangeOptions: string[] = new Array(100).fill(0).map((_: number, i: number) => (i + 1).toString());

  build() {
    Column() {
      // 1. 顶部标题
      Text(this.title)
        .fontSize(20)
        .fontColor(Color.White)
        .margin({ top: 20, bottom: 10 })

      // 2. 中央的滚动菜单 (核心组件)
      TextPicker({ range: this.rangeOptions, selected: this.currentValue })
        .onChange((value, index) => {
          // 由于 index 从 0 开始，且正好对应 0-99，直接使用 index 即可
          this.currentValue = index as number;
        })
        .height('50%') // 占据屏幕一半高度
        .width('100%')

      // 3. 底部中间的确定按钮
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.checkmark')) // 替换为原生的 ✔ 符号
          .fontSize(24)
          .fontColor([Color.White])
      }
      .width(50).height(50)
      .backgroundColor('#44FF44')
      .margin({ top: 10 })
      .onClick(() => {
        // 调用传入的回调函数，将修改后的值传回主页面
        this.on_confirm(this.currentValue);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000') // 覆盖全屏的黑色背景
    .justifyContent(FlexAlign.Center)
  }
}