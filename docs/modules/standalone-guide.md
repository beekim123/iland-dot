# 单独抽离某款游戏

可以：当前八款游戏均以 `godot/modules/<game_id>/main.tscn` 为独立入口，不需要把海岛、注册表、宿主 Autoload 或其他游戏一起搬走。抽离保留 `res://modules/<game_id>/` 路径，不需要批量重写资源引用。

## 直接使用

在仓库根目录执行（Python 3.10+、Godot **4.7.2 stable**）：

```sh
export GODOT_BIN=/绝对路径/Godot_v4.7.2-stable_linux.x86_64
python3 tools/extract_game.py gummy_bomber /tmp/my-gummy
"$GODOT_BIN" --path /tmp/my-gummy --editor --import --quit
"$GODOT_BIN" --path /tmp/my-gummy
```

目标必须不存在。也可以在 Godot 项目管理器导入 `/tmp/my-gummy/project.godot`。可用 ID：

| ID | 游戏 |
| --- | --- |
| `gummy_bomber` | 软糖炸弹 |
| `bloom_skirmish` | 花园对战 |
| `tide_gulp` | 吞食鱼 |
| `beach_cleanup` | 海滩清理 |
| `volcano_escape` | 火山逃生 |
| `pelican_pedal` | 鹈鹕配送 |
| `fruit_gummy_snake` | 水下软糖蛇（保留原 ID） |
| `monkey_vine` | 猴子藤蔓 |

## 自动复验

```sh
python3 tools/qa/test_extract_game.py
python3 tools/qa/test_standalone_games.py \
  --godot "$GODOT_BIN" --jobs 2 \
  --output /tmp/iland-standalone-check-new
```

`--output` 必须是仓库外的新目录；省略时自动建临时目录。每款各自执行全新抽离、fresh import、120 帧自动启动及正常退出、规则/生命周期/存档等模块测试。每项测试都有独立 XDG 数据、配置、缓存目录，不触碰真实存档。输出包含 `matrix.json`、每步日志和可复验的独立项目。超时、非零退出及脚本错误/资源泄漏均视为失败。猴子 `test_rules_route` 在断言路线及回放成功后会写入**抽离副本**的路线见证，不会写原模块；`test_rules_bonus` 验证既有奖励见证。搜索生成器 `test_rules_bonus_search` 不作为验收测试运行，也不计为通过。

不要把 `--quit-after 120` 等价于正常退出验收：它强制结束进程，不走游戏退出流程；本次在八款均观察到 ObjectDB 残留告警，部分还有资源残留。正常退出探针则等待模块自行关闭，不用强停来伪造通过。

## 边界和存档

- 模块协议仍是 `start(context={})` 和无参数 `exit_requested`。宿主连接退出信号后，由宿主负责移除模块；独立运行则关闭自己的进程，不尝试加载海岛。
- 独立项目只包含最小 `project.godot` 和该模块。不依赖宿主 Autoload、全局输入映射或 `/root/` 宿主对象；原始模块目录不改名。
- 存档固定在 `user://games/<game_id>/` 内；Gummy 为 `score.json`，通常其他游戏为 `profile.json`；水下蛇使用 `underwater_v2/profile.json`，不能拿旧平面蛇档覆盖。
- 不同 `config/name` 对应不同 Godot 应用数据目录，所以抽离后默认是新存档。要迁移时，先退出两个程序、分别备份，然后只复制同一游戏的对应子目录到新项目的 `user://`。不要改 namespace，不要拷贝整个海岛用户目录，也不要把未来版本/损坏存档强转覆盖。
- 工具拒绝跨模块 `res://`、路径穿越、符号链接及常见字面量相对 `load/preload`、scene path、shader include 越界。静态扫描不是完整 GDScript 解释器，动态拼接路径、UID 和二进制资源依赖仍需 fresh import 与运行测试验证。

## 开发资料与发布包分开

默认抽离是**完整模块开发副本**：保留测试、生成脚本、可编辑源素材、来源记录、`.gdignore` 和许可证；去掉 `.godot`、`*.import`、`__pycache__` 缓存。不自动删除“看起来没用”的 JSON、字体或源素材。

发布给玩家时，建议在抽离项目里配置 Godot 导出预设，选择运行场景及依赖、核对动态加载的声音/资源和许可证，然后生成发行包；不要把整个开发副本直接当发行包。当前没有高风险的按扩展名裁剪 `--runtime-only` 开关：部分 JSON 属于运行数据，脚本也会动态加载资源，盲删容易造成运行时缺失。

仓库顶层 `tools/qa/`、`docs/` 和模块外的制作资料不会随模块复制。模块内某些旧 `tests/run.sh` 或素材重建脚本仍假设海岛仓库布局；在独立项目中优先使用 `godot --path <独立项目> --script res://modules/<id>/tests/<test>.gd`，不能宣称所有制作脚本都可原样运行。若要独立持续开发，应按需另迁设计说明/来源档案，并调整这些开发脚本的路径。

## 后续独立维护步骤

1. 抽离至新目录并完成上述全新导入/测试。
2. 将整个抽离结果纳入独立仓库；保留原模块 ID、资源路径、许可证和来源记录，忽略导入缓存。
3. 自定义产品名、图标、窗口与导出预设；产品名变化会改变默认用户数据位置，应明确迁移策略。
4. 按目标平台补真实窗口操作、鼠标/键盘、声音试听和退出；Web、Mac/GPU、性能、完整游玩需分别验收，不能用 headless 结果代替。
5. 保留模块内测试，并在新仓库设置对应 Godot 版本的 CI；后续若引入公共代码，复制到模块内部而非反向依赖海岛。

## 2026-10-28 抽离复验结果

引擎 `4.7.2.stable.official.ed1daf0bf`，Linux headless；以下每行均在只有该模块的新项目、全新 import、隔离 XDG 下实测。Gummy 正常独立退出已修复，同时验证宿主仍只收到一次退出信号且进程保持运行。

| 模块 | 全新导入 | 自动启动/正常自退出 | 额外通过的模块检查 |
| --- | --- | --- | --- |
| gummy_bomber | 通过 | 通过 | runtime、sim、save_schema、host exit、standalone exit |
| bloom_skirmish | 通过 | 通过 | runtime、storage、sim |
| tide_gulp | 通过 | 通过 | runtime、storage、sim |
| beach_cleanup | 通过 | 通过 | runtime、storage、sim |
| volcano_escape | 通过 | 通过 | runtime、storage、sim |
| pelican_pedal | 通过 | 通过 | runtime、storage、sim、standalone exit |
| fruit_gummy_snake | 通过 | 通过 | runtime、storage、xyz、camera、interface、detach |
| monkey_vine | 通过 | 通过 | rules_route、rules_bonus、rules_invariants |

共 46 项引擎检查通过，另有 10 项抽离工具单元测试通过。正常流程无脚本错误、资源错误或 ObjectDB 泄漏；不包含图形、美术、声音主观验收，也不等价于所有模块完整测试集。猴子本轮额外检查主要是规则测试，不宣称覆盖与其他游戏相同的存档破坏/恢复场景。
