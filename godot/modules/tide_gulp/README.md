# 逐潮小鱼 · Tide Gulp

独立 Godot 4.7 模块：真实三维骨骼鱼与水彩海景，玩法锁在 XY 平面的侧视生存吞食。海岛只需要实例化 `main.tscn`、调用 `start(context)`，监听无参数 `exit_requested`。直接运行 `main.tscn` 会自动开始；没有角色大厅或教学确认门槛。

## 玩一局

- 鼠标指向游动，左键冲刺；WASD / 方向键与空格是等效备选。
- 最后一次明确输入决定设备；按住方向键时鼠标移动不抢输入，微小鼠标抖动也不抢。
- 鼠标始终可见，不做 FPS 捕获。Esc 或暂停按钮暂停；窗口失焦也暂停，需主动恢复。
- 从小月鱼开始，吃掉体长不超过自己 80% 的鱼；相近体型只能推开，大鱼需要用嘴在有预警的扑咬中捕获玩家。
- 六阶段连续成长，成年后继续高分生存；极小食物不奖励分数，挂机没有分数。
- 沿同一片海探索浅礁、海流带和深蓝裂谷。35 秒平潮、5 秒预告、20 秒流潮；顺流更快，逆流仍能游动。
- 结算可直接再来或回岛。主动返回、重开、关闭窗口均保存本局已经获得的纪录，不伪装死亡。

## 模块边界

`sim.gd` 与 `data/catalog.gd` 独立实现固定步长模拟；`game.gd` 仅转换合法输入、渲染真实状态和管理生命周期。不得引用 host、hub 或其他小游戏代码。主流程为 `start(seed)` → `command` → `tick(1/60)` → `drain_events` / `snapshot`。渲染鱼按稳定 ID 复用模型，非活动鱼进入种属池（最多 80 + 玩家），环境只保留模拟的 5 个活动区块。吞食、成长和死亡使用固定 24 节点低透明度气泡池，单次最多 8 个短寿命气泡。

艺术接口：`art/tide_art_factory.gd.new()`，`make_fish(species_id, stage_zero_based)`，鱼节点 `set_motion(speed, turn, mouth, hit, dash)` / `tick_pose(delta,time)` / `set_stage(stage)`。根位置、朝向和有效体长由 runtime 控制；根前方 +X，上方 +Y，镜头 +Z。环境 `make_environment(biome_int, bounds_rect, obstacle_rects)` 必须与模拟障碍一致。

UI 与音频分别位于 `ui/`、`audio/`，不继承前两作主题。HUD 读取实时分数、阶段、成长比例、冷却、海域、潮汐和投影危险提示。音频暂停和离场会同步停止，不建立全局输入或音频单例。

## 保存

固定为 `user://games/tide_gulp/profile.json`：

```json
{"schema_version":1,"best_score":0,"max_stage":1,"best_time":0.0}
```

只保存最高进食分、最高阶段、最长实际生存时间，不保存永久强化或设置。只接受可验证的 schema 1 和有限合法数值。未来版本、损坏 JSON、非法字段会保留原文件并禁用当前会话自动写入。通过同目录临时文件、flush 和原子 rename 写入；`context.save_root` 与其他模块路径一律忽略。测试可注入 `save_service.load_game(id)` / `save_game(id,data)`，ID 永远为 `tide_gulp`。

## 本地验证

所有测试必须使用隔离的 `XDG_DATA_HOME` / `XDG_CONFIG_HOME` / `XDG_CACHE_HOME`，不触碰玩家存档：

```sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
QA=$(mktemp -d)
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
"$GODOT" --headless --path godot --editor --import --quit
"$GODOT" --headless --path godot --script res://modules/tide_gulp/tests/test_sim.gd
"$GODOT" --headless --path godot --script res://modules/tide_gulp/tests/test_runtime.gd
"$GODOT" --headless --path godot --script res://modules/tide_gulp/tests/test_storage.gd
```

真实图形 QA 和 WebGL 性能必须单独运行，headless 通过不等于视觉验收。

## 可复现截图（显式开启，不影响正常游玩）

```sh
"$GODOT" --path godot res://modules/tide_gulp/main.tscn -- \
  --tide-demo --tide-seed=42 --tide-capture=/tmp/tide.png --tide-capture-after=8
"$GODOT" --path godot res://modules/tide_gulp/main.tscn -- \
  --tide-demo --tide-seed=42 --tide-record-dir=/tmp/tide-frames --tide-record-fps=12 \
  --tide-record-after=4 --tide-record-frames=96
```

`--tide-demo` 仅自动发出普通游动/冲刺输入，不传送、不送分、不禁用天敌、不修改体型。录制采用给定固定采样时长，帧数完成后走正常关闭清理。正常运行不自动移动、不录制。窗口关闭由模块先记分停声再调用可选 `context.quit_handler`；独立启动则自行安全关闭。
