# 逐潮小鱼 · 纸海 UI

原创绘本式纸片/铅笔线 UI，不依赖宿主或其他小游戏。三块主要 HUD：

1. 左上：六阶成长、吞食进度、小分数，海域/潮汐方向与倒计时合并在同一纸片。
2. 右下：冲刺冷却环，以及当前鼠标/键盘控制方式。
3. 右上：暂停与回岛。

初入立即能游动，不设开始页门槛。13 秒基础指引之后接收 runtime 的上下文提示，runtime 在 45 秒内完成渐进教学并使提示消失。成长反馈与潮汐预告为短暂居中手写标题。最多 5 个近身关系形状、2 个天敌警告，不显示鱼群姓名墙；张嘴形状=可吃、双横线=同级、三角尖角=天敌，不只依赖红绿色。

## 接口

`tide_hud.gd.new()` 是 CanvasLayer；亦可实例化 `tide_hud.tscn`。

- 信号（全部无参数）：`pause_requested` / `resume_requested` / `restart_requested` / `exit_requested` / `audio_requested`。
- `update_state(Dictionary)`：`score`, `survival_time`, `stage`(1..6), `stage_name`, `stage_progress`(0..1), `dash_ready`, `dash_cooldown_ratio`(剩余比例0..1), `best_score`, `controls_hint_visible`, `controls_hint`, `input_mode`, `audio`, `paused`, `finished`, `biome`, `tide_phase`(`calm`/`warning`/`flow`), `tide_remaining`, `tide_direction`, `current_warning`, `screen_tags`, `warnings`, `save_status`。
- `screen_tags`: `{pos:屏幕像素Vector2, relation:"food"|"peer"|"danger", warning:bool}`。
- `show_intro()` 为非阻塞重置；`show_pause()` / `hide_modal()` / `show_result(Dictionary)` / `show_growth(stage,name)` / `show_current_warning(text)`。
- 结果字段：`score`, `survival_time`, **本局** `stage`, `best_score`, `reason`（可读中文）, `save_status`。
- `request_exit_confirm()` 在活跃游戏先请求暂停，确认才退出；取消恢复原状态。已结束结果页直接回岛，无冗余确认。
- runtime 处理 Esc 时先调用 `handle_escape()`，返回 true 表示确认/玩法页已消费，否则由 runtime 处理暂停。
- 游戏面 `MOUSE_FILTER_IGNORE`；只在按钮与模态遮罩拦截输入。重开/离场设动作闩锁，避免连击重复信号。隐藏模态释放键盘焦点。

## 字体与复现

`tide-book.otf` 为 **Noto Serif CJK SC Regular v2.003** 的本地子集，生成衍生字体名 `Tide Book UI`。保留原作者信息及 `OFL.txt`。源自 `NotoSerifCJK-Regular.ttc` 的 face 2，官方上游 <https://github.com/notofonts/noto-cjk/tree/main/Serif>。完整来源散列与覆盖情况见 `font_manifest.json`。

```sh
python3 godot/modules/tide_gulp/ui/subset_font.py --source /path/to/NotoSerifCJK-Regular.ttc
tools/run.sh --import
tools/run.sh --headless --script res://modules/tide_gulp/ui/test_ui_audio.gd
```

生成器扫描本模块所有 GDScript 与显式字符表，缺字即失败；新增中文后需重新生成。字体 import 已关闭 system fallback，运行和导出不需要用户机器安装字体。fontTools 仅为构建依赖。

## 已验证与边界

无头测试覆盖 1280×800 / 920×540 / 640×360 / 1920×1080，真实 `Viewport.push_input` 点击海面穿透、暂停按钮不泄漏冲刺、模态遮罩吞点击、焦点释放、暂停与退出取消、连续重开/退出以及复用 HUD。没有默认 ProgressBar 最小高度风险：进度与冷却由定制绘制。字体覆盖/音频释放也独立检测。

无头测试不是视觉验收。真实 Godot 截图与连续游玩由主任务集中采集；此目录不伪造截图，不宣称完成主观试听。
