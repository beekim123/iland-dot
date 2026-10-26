# Gummy Garden / 软糖花园

独立、原创 Q 版糖果主题的无限炸弹迷宫。镜头采用约 70° 的正向 3D 俯视正交视角，保留立体模型、厚度和阴影，不是平面 2D。不是《炸弹人》的角色、美术或品牌复刻；保留网格移动、定时炸弹、十字爆风、可破坏方块、连锁爆炸及强化道具等经典玩法。

## 启动

Godot 4.7.2 Compatibility，项目根目录为仓库 `godot/`：

```sh
Godot --path godot res://modules/gummy_bomber/main.tscn
Godot --headless --path godot --script modules/gummy_bomber/tests/test_sim.gd
Godot --headless --path godot --script modules/gummy_bomber/tests/test_runtime.gd
```

WASD / 方向键移动，Space 放置糖果炸弹。ESC 或右上角按钮暂停；`↗ 返回海岛` 退出。死亡 3 秒后自动重开，也可 R 立即重开。消灭本轮敌人后自动生成下一轮，无选关界面。

## 规则

- 13 × 11 网格；外围和偶数坐标交叉点为永久障碍。
- 炸弹 2.4 秒引爆、爆风保留 0.55 秒。可以离开刚放的炸弹，不能重新穿过它。
- 爆风向四个方向延伸。永久墙挡住爆风；可破坏糖块受击后销毁并阻止该次爆风继续传播。炸弹相遇立即连锁。
- 随机强化：爆风距离上限 6，炸弹容量上限 5，移动速度上限 ×1.65。
- 破坏糖块有概率掉落道具；刚生成道具不被同一次爆炸消灭，后续爆风会摧毁它。
- 起点有两个安全退路，敌人远离起点；出生短暂无敌。每轮至多 6 敌，速度有下限，避免无限模式不断堆积实体。
- 每糖块 10 分、敌人 100 分、拾取 25 分、清轮奖励 250 分。

## 模块边界

入口 `main.tscn` 根节点公开：

```gdscript
signal exit_requested
func start(context: Dictionary = {}) -> void
```

宿主实例化后连接信号、`add_child()`，再调用 `start(context)`；单独启动则延迟到下一次空闲帧自动开始，不会重复初始化。退出时停止游戏逻辑、输入及所有音频，发出信号；宿主负责释放实例和恢复自己的视角。没有 Autoload、岛屿脚本、全局输入映射依赖。

可选 context：`seed: int` 控制可复现地图；`save_service: Object` 可注入实现 `load_game(game_id) -> Dictionary` 和 `save_game(game_id, data)` 的存储适配器。未注入时仅写 `user://games/gummy_bomber/score.json`。目录外不保存小游戏数据。

- `sim.gd`：纯确定性规则模拟，不依赖场景和美术。
- `game.gd`：渲染、输入、HUD、存储适配及音频。
- `art/candy_factory.gd`：原创圆润糖果网格美术生成器。
- `audio/`：本模块专用原创合成音乐及音效与生成记录。
- `tests/`：独立 headless 回归用例。

整体复制到新 Godot 项目的 `modules/gummy_bomber/` 即可；保留这一模块资源路径、将 `main.tscn` 设为启动场景。不会引用海岛或其他小游戏。自动拆分工具由仓库级工具提供。

## 已知设计取舍

这是首个可玩原型：敌人采用四方向随机巡游 + 概率追击，不是复杂路径搜索；中文 HUD 字体子集及 OFL 许可证随模块打包，不依赖外部字体。使用可复现伪随机生成，地图可通过炸开方块逐步通路。后续可扩展敌人种类、触屏按钮及手柄，但不改变独立数据边界。

## 性能与计时

静态棋盘按共享网格/材质合成 MultiMesh；种子 42 的棋盘为 7 个静态绘制批，而不是数百独立子物件。动态演员缓存重用，圆角块保留倒角支撑边并减少几何。游戏逻辑使用单调墙钟驱动的 1/60 秒固定步，不随软件渲染 FPS 减慢。`test_runtime.gd` 人为制造每帧 300 ms 的停顿并传入错误引擎 delta，验证炸弹仍按真实 2.4 秒引爆。超过 5 秒的应用挂起自动暂停，防止恢复后突然死亡。

启动时追加 `-- --gummy-profile`，每 5 秒记录 FPS、绘制调用及物件计数。Headless 生命周期测试释放场景后需等 0.5 秒让音频线程清理，再退出进程。

软件渲染适配：检测到 llvmpipe / softpipe / SwiftShader 时，模块临时关闭项目的 MSAA，并将 3D 渲染比例降至 0.75（HUD 仍为原生分辨率）；退出及释放场景时恢复之前的 Viewport 配置。动态软糖演员同材质网格合并、方向阴影使用单个正交级联。云端软件 GPU 的 FPS 不代表真实显卡性能，性能采样需注明适配器、分辨率与配置。

存档格式为 `{ "schema_version": 1, "highscore": ... }`。不含版本的历史数据按 v1 读取，并在下次写入时迁移；未知版本（尤其未来版本 >1）或无法解析的内容保留原样，当前实例禁用自动写入并警告，不以旧程序覆盖新格式。注入存储适配器同样遵守此规则，见 `tests/test_save_schema.gd`。
