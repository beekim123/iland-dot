# 海岛与小游戏模块架构

> 当前源码状态（2026-10-28）：八款游戏均已注册启用；四个推荐传送门与每页六项的全部游戏目录共用模块入口。启用不等于所有平台或视觉验收通过。历史验收按各自源码基线保留；当前检查范围见[当前验证入口](../../tools/qa/current_games/README.md)。

## 目录边界
- `godot/app/`：宿主入口、注册表与场景路由。只有宿主知道游戏清单。
- `godot/scenes/`、`godot/scripts/`、`godot/resources/`：海岛环境、动物、镜头及海岛音频。
- `godot/hub/`：传送门、鼠标、物体点击反馈，与游戏实现解耦。
- `godot/modules/<game_id>/`：每个游戏的场景、脚本、美术、声音、字体许可证与测试。禁止引用其他模块或岛屿。
- `art/v3/`、`art/rigged/`、`art/v5/`：当前可编辑建模源文件、生成器与审计；作者目录导出属于可再生本地输出，海岛运行成品仅在 godot/resources 保留一份。
- `docs/project/`：长期计划、接口、验收与维护记录。

## 每个小游戏独立设计视觉语言

每个新小游戏都须独立设计角色、环境、材质与 UI，不得默认复用海岛或上一小游戏的视觉主题，也不能只换配色后视为新设计。可以共享技术设施与工程方法，但不默认共享视觉主题；技术复用仍须遵守模块边界和独立抽离要求。

## 模块协议 v1
入口 `res://modules/<id>/main.tscn`。节点提供 `signal exit_requested` 与 `start(context: Dictionary = {})`。宿主实例化、连接退出信号、加入场景树，再调用 start；模块独立运行也可自行启动。`context` 中 `game_id`、`save_root`、`schema_version` 是提示，模块必须验证命名空间，不能任意写入宿主或其他游戏路径。

`gummy_bomber` 固定存档位于 `user://games/gummy_bomber/`；`bloom_skirmish` 使用 `user://games/bloom_skirmish/profile.json`（schema v1）；`tide_gulp` 固定为 `user://games/tide_gulp/profile.json`（schema v1，最高进食分/阶段/实际生存时间）；宿主数据预留 `user://hub/`。存档格式独立带版本号，未知新版本不得删除或覆盖；模块迁移只能修改本模块数据。禁止全局 `user://save.json`。独立导出的应用具有不同应用数据目录，此为隔离而非自动同步。

注册表描述 `id/title/enabled/scene_path/color/description/category`。当前八项为 `gummy_bomber`、`bloom_skirmish`、`tide_gulp`、`beach_cleanup`、`volcano_escape`、`pelican_pedal`、`fruit_gummy_snake`、`monkey_vine`。可用性还需加载入口、实例化并检查 `start`/`exit_requested` 接口，不能仅凭 enabled 元数据判定。

宿主从可用游戏中选出最多四个不重复推荐，在四个固定安全位置显示；刷新推荐不会重建海岛。全部游戏目录每页六项，支持筛选和分页。路由暂停海岛输入/动画/音乐，保留镜头与实例；从目录进入则退出后回原目录状态，从岛上进入则回岛。`snake`、`reef_memory`、`cloud_hop` 不再是当前模块入口，不保留跨游戏存档别名。

## 启动

Godot **4.7.2 stable / Compatibility**，仓库根目录执行：

```sh
GODOT_BIN=/path/to/Godot tools/run.sh
# 只启动第二个游戏，不加载海岛：
GODOT_BIN=/path/to/Godot tools/run.sh res://modules/bloom_skirmish/main.tscn
# 只启动第三个游戏：
GODOT_BIN=/path/to/Godot tools/run.sh res://modules/tide_gulp/main.tscn
```

两种方式使用同一个游戏入口与完整玩法；独立启动自动开始，宿主启动通过协议传入上下文，不依赖不同的占位场景。

## 独立抽离
```sh
python3 tools/extract_game.py gummy_bomber /tmp/gummy-standalone
python3 tools/extract_game.py bloom_skirmish /tmp/bloom-standalone
python3 tools/extract_game.py tide_gulp /tmp/tide-standalone
```

再以 Godot 导入对应目录生成的 `project.godot`。工具只复制模块（包括美术、声音、字体、生成记录、测试和许可证），保留 `res://modules/<id>/` 内部路径，不复制海岛、宿主或其他模块。目标目录必须不存在；外部 `res://` 引用、路径穿越和符号链接在复制前拒绝。独立项目名称按模块区分，默认应用数据目录也彼此独立。若游戏开始依赖公共代码，必须把依赖复制进模块并维护许可证，不能依赖宿主全局单例。

## 路由回归与当前验证

`godot/tests/check_app.gd` 覆盖八款游戏48轮实际退出，再逐款验证目录进入及返回；检查同一海岛实例、原镜头、四门位置、HUD和各音轨暂停状态恢复。模块相机使用局部 `Environment`，不覆盖海岛环境。`hub/tests/` 和目录测试另验证四门分配、拖动防误触、暂停恢复、可见性/拾取及每页六项分页。

`tools/test_all.sh --list` 给出当前集成/抽离冒烟矩阵；运行时隔离XDG存档与源副本，逐款生产抽离、精确字节检查、导入及启动/退出接口测试。它不声称执行完整规则长时套件或独立进程关闭；独立运行与抽离细节见[指南](../modules/standalone-guide.md)。

旧三游戏24轮、六款全量、七/八款增量结果只对其各自冻结基线成立，保留在历史验收记录中；不能将旧通过标作当前完整全量。无头测试不能推断主观试听、原生图形/人工输入、WebGL2或用户设备性能通过。

## 新增或单独抽离模块

新游戏继续放在 `godot/modules/<id>/`，独立维护入口、存档版本、素材及许可证；不得引用宿主、其他游戏或共享全局单例。相似基础代码可保留模块内副本以保障自治，不为去重制造宿主依赖。新增时同步注册表、抽离工具及当前验证矩阵，并分别验证独立启动和宿主退出/输入生命周期。抽离保留 `modules/<id>/` 的资源ABI，不等于将目录重命名到项目根；数据目录与宿主隔离，不自动同步或迁移存档。

## 发布规则
小步提交；提交前跑资源导入、模块规则测试和路由生命周期测试。运行截图只取真实 Godot 视口，素材渲染不可标为实机图。远端更新必须为 fast-forward，先查最新 head，再发布；不得 force 覆盖用户提交。
