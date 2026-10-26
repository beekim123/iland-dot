# 海岛与小游戏模块架构

## 目录边界
- `godot/app/`：宿主入口、注册表与场景路由。只有宿主知道游戏清单。
- `godot/scenes/`、`godot/scripts/`、`godot/resources/`：海岛环境、动物、镜头及海岛音频。
- `godot/hub/`：传送门、鼠标、物体点击反馈，与游戏实现解耦。
- `godot/modules/<game_id>/`：每个游戏的场景、脚本、美术、声音、字体许可证与测试。禁止引用其他模块或岛屿。
- `art/v3/`、`art/rigged/`、`art/v5/`：可编辑建模源文件、生成器、导出模型与审计。
- `docs/project/`：长期计划、接口、验收与维护记录。

## 模块协议 v1
入口 `res://modules/<id>/main.tscn`。节点提供 `signal exit_requested` 与 `start(context: Dictionary = {})`。宿主实例化、连接退出信号、加入场景树，再调用 start；模块独立运行也可自行启动。`context` 中 `game_id`、`save_root`、`schema_version` 是提示，模块必须验证命名空间，不能任意写入宿主或其他游戏路径。

`gummy_bomber` 固定存档位于 `user://games/gummy_bomber/`；宿主数据预留 `user://hub/`。存档格式独立带版本号，未知新版本不得删除或覆盖；模块迁移只能修改本模块数据。禁止全局 `user://save.json`。独立导出的应用具有不同应用数据目录，此为隔离而非自动同步。

注册表描述 `id/title/enabled/scene_path/color/description`。只有已实现且测试通过的项目标记 enabled。未开放传送门只能给出锁定提示，不能载入占位游戏。路由保留岛屿镜头与实例，暂停岛屿输入/动画/音乐，进入游戏直接开始，不经过选关。

## 独立抽离
`python3 tools/extract_game.py gummy_bomber /tmp/gummy-standalone`，再以 Godot 导入生成的 `project.godot`。工具只复制模块，保留 `res://modules/<id>/` 内部路径，不复制海岛、宿主或其他模块。若游戏开始依赖公共代码，必须把依赖复制进模块并维护许可证，不能依赖宿主全局单例。

## 发布规则
小步提交；提交前跑资源导入、模块规则测试和路由生命周期测试。运行截图只取真实 Godot 视口，素材渲染不可标为实机图。远端更新必须为 fast-forward，先查最新 head，再发布；不得 force 覆盖用户提交。
