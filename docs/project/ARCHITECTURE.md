# 海岛与小游戏模块架构

> 当前源码基线：Bloom 最终动物版已验证并发布 [cc7bed6](https://github.com/beekim123/iland-dot/commit/cc7bed614ff010737ca0761c4bd86c960330382d)。第三款 Tide Gulp 正在实现；后续按[开发队列](DEVELOPMENT-QUEUE.md)顺序推进，本文设计安排不代表入口已经开放。

## 目录边界
- `godot/app/`：宿主入口、注册表与场景路由。只有宿主知道游戏清单。
- `godot/scenes/`、`godot/scripts/`、`godot/resources/`：海岛环境、动物、镜头及海岛音频。
- `godot/hub/`：传送门、鼠标、物体点击反馈，与游戏实现解耦。
- `godot/modules/<game_id>/`：每个游戏的场景、脚本、美术、声音、字体许可证与测试。禁止引用其他模块或岛屿。
- `art/v3/`、`art/rigged/`、`art/v5/`：可编辑建模源文件、生成器、导出模型与审计。
- `docs/project/`：长期计划、接口、验收与维护记录。

## 每个小游戏独立设计视觉语言

每个新小游戏都须独立设计角色、环境、材质与 UI，不得默认复用海岛或上一小游戏的视觉主题，也不能只换配色后视为新设计。可以共享技术设施与工程方法，但不默认共享视觉主题；技术复用仍须遵守模块边界和独立抽离要求。

## 模块协议 v1
入口 `res://modules/<id>/main.tscn`。节点提供 `signal exit_requested` 与 `start(context: Dictionary = {})`。宿主实例化、连接退出信号、加入场景树，再调用 start；模块独立运行也可自行启动。`context` 中 `game_id`、`save_root`、`schema_version` 是提示，模块必须验证命名空间，不能任意写入宿主或其他游戏路径。

`gummy_bomber` 固定存档位于 `user://games/gummy_bomber/`；`bloom_skirmish` 使用 `user://games/bloom_skirmish/profile.json`（schema v1）；宿主数据预留 `user://hub/`。存档格式独立带版本号，未知新版本不得删除或覆盖；模块迁移只能修改本模块数据。禁止全局 `user://save.json`。独立导出的应用具有不同应用数据目录，此为隔离而非自动同步。

注册表描述 `id/title/enabled/scene_path/color/description`。已发布 cc7bed6 基线的前三项依次对应粉色 `gummy_bomber`、青色 `bloom_skirmish`、紫色未开放 `reef_memory`；第四个计划 `cloud_hop` 仍禁用且不增加岛上槽位。原 `snake` ID 已退役，不保留别名或跨游戏存档迁移。`enabled` 是开发中的入口开关，不等于用户验收或发布状态；Bloom 动物版有独立验收与源码发布证据，但入口开启本身仍不是验收证明。未开放传送门只能给出锁定提示，不能载入占位游戏。路由保留岛屿镜头与实例，暂停岛屿输入/动画/音乐，进入游戏直接开始，不经过选关。

## 启动

Godot **4.7.2 stable / Compatibility**，仓库根目录执行：

```sh
GODOT_BIN=/path/to/Godot tools/run.sh
# 只启动第二个游戏，不加载海岛：
GODOT_BIN=/path/to/Godot tools/run.sh res://modules/bloom_skirmish/main.tscn
```

两种方式使用同一个游戏入口与完整玩法；独立启动自动开始，宿主启动通过协议传入上下文，不依赖不同的占位场景。

## 独立抽离
```sh
python3 tools/extract_game.py gummy_bomber /tmp/gummy-standalone
python3 tools/extract_game.py bloom_skirmish /tmp/bloom-standalone
```

再以 Godot 导入对应目录生成的 `project.godot`。工具只复制模块（包括美术、声音、字体、生成记录、测试和许可证），保留 `res://modules/<id>/` 内部路径，不复制海岛、宿主或其他模块。目标目录必须不存在；外部 `res://` 引用、路径穿越和符号链接在复制前拒绝。独立项目名称按模块区分，默认应用数据目录也彼此独立。若游戏开始依赖公共代码，必须把依赖复制进模块并维护许可证，不能依赖宿主全局单例。

## 路由回归

`godot/tests/check_app.gd` 交替验证两种游戏共 20 次入退，第二门通过实际 hub 激活路径进入；保存岛屿实例、镜头变换、三门随机位置、HUD 可见性和每个音轨之前的暂停状态。游戏相机使用局部 `Environment`，不覆盖海岛全局环境。`godot/hub/tests/test_hub.gd` 验证两扇已开放门、第三门锁定、拖动防误触、暂停/恢复和有界声音池。抽离与实机验收单独进行，不从无头结果推断图形或浏览器成功。

旧俯视测试仅作历史；最终动物版已完成新的宿主、真正抽离、规则/资源/生命周期及原生自然 180 秒、重开、回岛和关闭验证。发布时测量工具与清单的最小适配另有干净树专项，原完整聚合与发布源差异明确记录。细节见[任务板](TASKBOARD.md)、[独立 QA](../acceptance/bloom-skirmish-independent.md)、[动物原生 QA](../acceptance/bloom-animal-native.md)。主观试听、浏览器 WebGL2 和用户 Mac/GPU 不从这些结果推断。

## 后续模块与入口计划

`tide_gulp` → `pelican_pedal` → `beach_cleanup` → `volcano_escape` 顺序实施；各自固定 `user://games/<id>/`，保存格式独立版本化，遵守相同退出与抽离协议。Tide Gulp 计划替换第三槽 `reef_memory`；Pelican Pedal 计划替换 `cloud_hop`，实际门位在实施时处理。旧占位 ID 不保留存档别名，第五/六款也不借用其他游戏数据。**本次仅提交设计和队列，不改 registry/runtime，也不包含正在开发的鱼游戏源码。** 不允许跨模块运行依赖或把前作视觉主题当成默认模板。

## 发布规则
小步提交；提交前跑资源导入、模块规则测试和路由生命周期测试。运行截图只取真实 Godot 视口，素材渲染不可标为实机图。远端更新必须为 fast-forward，先查最新 head，再发布；不得 force 覆盖用户提交。
