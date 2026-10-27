# 绒芽争园 · Bloom Skirmish

独立、原创的 **3D 第三人称越肩 2v2 花毯争地射击游戏**：玩家与一位布偶园丁机器人，对抗两位机器人。喷壶播种、绕过花盆掩体、护住延时花苞，在三分钟内把漂浮苗圃开成自己的颜色。不是联网游戏；没有局外数值成长、抽卡或原作角色素材。

## 直接运行

Godot **4.7.2 Compatibility**，项目根目录是仓库的 `godot/`：

```sh
Godot --path godot res://modules/bloom_skirmish/main.tscn
Godot --headless --path godot --script modules/bloom_skirmish/tests/test_sim.gd
Godot --headless --path godot --script modules/bloom_skirmish/tests/test_runtime.gd
Godot --headless --path godot --script modules/bloom_skirmish/tests/test_storage.gd
```

从海岛第二传送门进入，点击游戏画面锁定鼠标后倒数开局。独立抽离：

```sh
python3 tools/extract_game.py bloom_skirmish /tmp/bloom-standalone
Godot --path /tmp/bloom-standalone
```

## 一局完整玩法

- **WASD / 方向键**相对镜头移动，鼠标左右转向/上下瞄准；画面中央准星对应实际三维射线目标。**左键**持续喷洒有重力弧线的花蜜。花蜜命中角色造成伤害，溅落地面改种花毯，掩体会阻拦弹道。
- 喷壶共 100 水量，每股消耗 2.5；**松开左键** 0.45 秒后以每秒 30 补水，不能一直按住空壶自动射击。
- **SPACE** 向移动方向冲刺；静止时向瞄准方向冲刺。持续 0.18 秒，冷却 3 秒，不穿墙、不附带无敌。
- **右键**在自己花毯上种下花苞；每人同时只存在一颗。3 秒后开花，把半径 3.2 的区域改种；12 秒冷却。花苞有 45 生命，敌人可用四股花蜜拆掉花苞，花苞不是自动扩张炮塔。
- 园丁 100 生命，每股花蜜伤害 12.5；击倒后等待 **4 秒**在己方苗圃复活。己方苗圃受保护，敌人不能进入或伤害里面的园丁。
- 3 秒开场倒数后进行 **180 秒**正式比赛。只计算可种植地面，固定掩体和两侧出生苗圃不计分；尚未种植的区域留在比分条中。倒计时归零，以同一份覆盖网格计算胜负。
- 结算提供**再来一局**与**返回海岛**。右上角保留声音、暂停和返回图标；ESC 释放鼠标并暂停；点击继续或 ESC 恢复鼠标锁定。Web 版必须由真实点击/按键取得指针锁，取得锁定的那次点击不会开火。失去焦点、后台挂起自动暂停，恢复需主动继续，防止意外死亡。

机器人使用网格寻路、争夺未种植/敌方土地、补水、遭遇射击、换线以及附近花苞目标选择；它们并非只跟随玩家。队伍用青叶/珊花颜色、园丁帽形与出生区叶片/花瓣标志区分。花蜜覆盖面保持连续湿润材质，不使用调试棋盘或每格花朵贴纸。

## 独立模块协议

根节点 `main.tscn` 提供：

```gdscript
signal exit_requested
func start(context: Dictionary = {}) -> void
```

宿主实例化 → 连接 `exit_requested` → 加入树 → `start(context)`。独立启动会延迟自动开始，不会重复初始化。`leave_game()` 先停止逻辑、所有输入与音频，清除按键状态，再发出退出信号；宿主负责销毁模块并恢复自己的相机。没有 Autoload、宿主输入映射、海岛脚本、其他游戏或外部字体依赖。

可选 context：

- `seed: int`：可复现模拟种子；重开时递增。
- `save_service: Object`：提供 `load_game("bloom_skirmish") -> Variant` 与 `save_game("bloom_skirmish", data: Dictionary)` 的注入存储器。
- `quit_handler: Callable`：可选宿主正常关窗回调。模块单独运行则自行停止音频/输入、释放场景并等待 0.5 秒音频线程清理后退出。
- `game_id / save_root / schema_version` 是宿主提示，**不会允许改写其他命名空间**。

### 独立存档

固定路径：`user://games/bloom_skirmish/profile.json`。

```json
{"schema_version":1,"best_coverage":0.0,"wins":0,"matches":0,"audio_enabled":true}
```

只在完整结束时统计对局/获胜/最佳覆盖；中途返回不会伪造结果。声音设置也保存在本模块目录。版本缺省按 v1 迁移；未知/未来/非整数版本、损坏 JSON 和非法数值均保留原数据并禁用写入，不覆盖未来版本。合法 v1 扩展字段保留。磁盘使用同目录临时文件 + rename 提交；不会写入 `user://hub/`、其他小游戏或用户传入的任意路径。

## 技术与性能边界

- `sim.gd` 是纯确定性、渲染无关的固定步模拟；格子、障碍、碰撞、覆盖统计、机器人和比赛状态都在这里。
- `game.gd` 以单调墙钟驱动 1/60 秒固定步；低渲染 FPS 不会拉长比赛、复活或花苞时间。真实挂起超过 5 秒时暂停，而不是高速补算玩家死亡。
- 地面仅 **一个 PlaneMesh + 一张 384×288 ownership 纹理（32×24 米场地，每格 1/12 米）**。比分与视觉读取同一网格；模拟增量维护 RGB8 上传字节，只在网格版本变化时原生复制/上传，不逐帧遍历 11 万格调用 set_pixel。不为每格/每朵花创建节点。
- 花蜜落点以连续有机轮廓写入细网格。表面高光/法线不改变覆盖边界，不把装饰颜色扩到未拥有的计分格。
- 静态场景按共享顶点色材质合并；动态角色只有四个；花朵瞬时反馈最多 24 组。不是无界粒子或每帧重新构建场景。
- 手动输入使用事件与显式释放，切入、暂停、失焦、死亡、重开和退出均清空；按住旧按钮不会在重新进入时延续攻击。
- 相机是真实透视追随越肩视角，不是降低角度的俯视镜头。鼠标 yaw/pitch、肩偏移、动态跟随和镜头碰撞使用相同掩体高度；准星优先取最近地面/掩体/角色三维命中，无命中时保留向天空发射方向。实际喷口到目标的重力补偿弹道、喷口前遮挡与液体轨迹共用模拟数据。
- 相机拥有自己的 Environment。软件渲染时临时关闭 MSAA、将 3D 比例设为 0.8，HUD 保持原分辨率，退出恢复宿主配置。

调试参数（放在 `--` 后）：`--bloom-profile` 每 5 秒输出性能计数；`--bloom-capture=/absolute/path.png` 在 90 个实渲染帧后保存真实视口；`--bloom-capture-after=15` 可延后到开局 15 秒拍摄；`--bloom-demo` **仅用于可视化拍摄**，显式开启才会自动操作玩家，正常游戏默认关闭。`--bloom-record-dir=/absolute/frames --bloom-record-frames=96 --bloom-record-after=3.2` 可录制 12fps 固定模拟时钟下 96 张真实视口帧，完成后正常清理退出；仅显式录像模式使用这一时钟，正常游戏仍使用墙钟固定步。Headless 不能生成有效实机截图。

美术源与原创记录见 `art/README.md` / `art_manifest.json`；原创音乐、音效与可复现生成器见 `audio/`；独立中文子集字体与 OFL 许可证位于 `ui/`。`effects/nectar_effects.gd` 以有上限的网格/实例池渲染液柱、断裂液滴和接触飞溅，不改动覆盖或碰撞规则。`tests/` 包含确定性规则、低 FPS 计时、输入中断、暂停/重开/退出与存档保护回归。仓库 `tools/qa/bloom_skirmish/` 另有独立生命周期、存储隔离、抽离与依赖审查。
