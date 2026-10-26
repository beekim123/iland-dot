# Gummy Garden 独立 QA — 2026-10-26

审计对象：`godot/modules/gummy_bomber/`。审计者未修改玩法源码；独立脚本位于 `tools/qa/gummy_bomber/`。引擎：**Godot 4.7.2 stable official ed1daf0bf**，headless。

## 结果

- **309,597 项模拟断言，0 失败**：1,000 个种子的地图/敌人可复现、合法网格、出生退路、敌人距离；破坏全部软墙后每个敌人可达。
- **100 种子 × 600 帧**随机移动/放弹双实例回放：网格、敌人、玩家、生死和分数逐帧一致；玩家不进入墙/糖块，敌人不进入非法格，炸弹数量不超过容量。
- **500 次连续换波**：每轮 143 格、1–6 敌人，炸弹与爆风清空，没有实体数量随波次线性堆积。
- 手工规则断言：糖块挡住后方炸弹、五弹连锁、放弹后离开但不可返回、定时引爆/死亡禁止操作、重开清零、强化上限、敌人碰撞伤害、爆风击杀得分。
- **20 次场景进入/带弹退出/释放**：退出信号只发一次，停止 `_process`、未处理输入、所有音效和音乐；每次释放后的孤儿节点数均为 **0**。释放后再次触发 viewport resize 未出现无效对象调用。
- **实际剥离**：仅复制 `modules/gummy_bomber/` 至全新临时 Godot 项目，生成独立 `project.godot`，执行 import 和 20 次生命周期测试；不复制海岛、宿主 app、全局 autoload 或资源，能够运行。
- 资源引用审查：所有 `res://` 显式依赖都位于 `modules/gummy_bomber/`；无海岛路径、宿主单例、全局 InputMap 依赖。
- 独立运行仅产生模块存档 `user://games/gummy_bomber/score.json`（引擎自身日志另计）；注入存档 API 使用的 game_id 始终为 `gummy_bomber`。

## 发现并复测修复的问题

1. **注入存档服务只写不读**：原版 `_ready()` 在注入服务前读本地文件，随后写服务，导致重进无法恢复服务中的最高分。开发者已改为 `start(context)` 设置服务后加载，并支持 `load_game(game_id)`。独立 `storage.gd` 验证读 777→写 999→新实例读 999，全通过。
2. **重开残留事件队列**：`sim.start()` 原本保留旧 hit/pop/wave。开发者增加 `events.clear()`；插入历史 hit 再重开，仅留下新 wave 事件，复测通过。
3. **拉伸锚点设置 size 引发 UI 警告**：在独立项目中复现，开发者已修复；最终独立项目 import＋20 周期复测无 ERROR/WARNING。

## 音频退出测试的重要说明

快速 headless 循环后立刻 `quit()`，曾出现 WAV/Playback 资源退出告警；孤儿节点仍为 0。最后一次释放后等待 **0.5 秒**让音频服务器完成销毁，告警消失。生命周期脚本保留这一等待，不能把未等待的进程退出日志直接认定为场景节点泄漏，也不能声称已做长时间实际音频听感测试。

## 复现

在仓库根目录执行（将 `$GODOT` 指向 4.7.2 二进制）：

```sh
mkdir -p .runtime/qa/{data,config,cache}
export XDG_DATA_HOME="$PWD/.runtime/qa/data"
export XDG_CONFIG_HOME="$PWD/.runtime/qa/config"
export XDG_CACHE_HOME="$PWD/.runtime/qa/cache"
"$GODOT" --headless --path godot --script ../tools/qa/gummy_bomber/independent.gd
"$GODOT" --headless --path godot --script ../tools/qa/gummy_bomber/storage.gd
"$GODOT" --headless --path godot --script ../tools/qa/gummy_bomber/lifecycle.gd
```

本次临时原始日志在 `.runtime/qa/`（不提交生成缓存与存档）。模拟测试不自动等价于实际玩家能通关：连通性检查允许炸开糖块，非保证任何随机决策都能存活。

## 边界与待宿主验收

本报告是规则、隔离和生命周期 QA，不替代主线程的屏幕实操。传送门实际点击、退出图标命中、返回海岛相机状态、拖动不误点、不同分辨率 HUD、键盘焦点及音频听感仍由宿主集成验收。随机测试有限，非数学证明。无选关、无限波次、死亡重开为本次设计而非 Bug。
