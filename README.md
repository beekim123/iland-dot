# 晴贝小岛 · Sunny Shell

Godot **4.7.2 stable** 的独立 Q 版海岛大厅和模块化小游戏工程。仓库：<https://github.com/beekim123/iland-dot>。不改动 Valley Deck 项目。

> **绒芽争园正在重新设计独立美术/UI风格，尚未完成或发布。** 第三人称与液体功能已建立测试证据，但用户再次否定当前美术/UI，要求每个新项目独立设计；当前运行画面和Web包不得当作最终交付。 用户已否定原俯视镜头；旧 VISUAL_REV3、旧 Web ZIP 和 05:56 UTC 的通过记录仅保留为历史证据，不代表当前修订完成。最新目标见[修订研究](docs/research/bloom-third-person-liquid.md)和[任务板](docs/project/TASKBOARD.md)。

## 运行
用 Godot 导入 `godot/project.godot`，资源导入完成后按 F5。运行资源已包含，不需要安装 Blender。Linux 可用 `GODOT_BIN=/path/to/godot tools/run.sh`；云端脚本默认使用同级 tools 目录内的 4.7.2。

岛屿：拖动旋转、滚轮缩放，R 复位，2/3/4 切换观景。点击物体触发声音和反馈，点击粉色传送门开始软糖迷宫，第二扇青色门进入「绒芽争园」2 对 2 三分钟花园争地；第三扇门仍未开放。小游戏操作与暂停/退出见屏幕提示，退出回岛保留镜头。

### 直接运行绒芽争园
```bash
GODOT_BIN=/path/to/Godot tools/run.sh res://modules/bloom_skirmish/main.tscn
```
开发目标为第三人称肩后追随、鼠标环视/中心准星、相机相对移动与粘稠花露喷射。按键与鼠标捕获正在调整，最终以模块 README 和屏幕提示为准；旧俯视操作说明不是本次最终合同。直接启动与海岛第二扇青色门使用同一模块。

## 项目边界
- `godot/app/`：宿主注册表与路由。
- `godot/hub/`：彩色传送门与交互。
- `godot/modules/gummy_bomber/`：自包含软糖炸弹迷宫，美术/音频/规则/测试一起管理。
- `godot/modules/bloom_skirmish/`：自包含「绒芽争园」，玩家与机器人争地；第三人称与液体表现修订中，仍须保留完整单局、结果、重开、回岛，非联网对战。
- `art/`：Blender 源模型、生成器与骨骼审计。
- `docs/project/`：架构、任务板、路线图、素材策略。
- `docs/acceptance/`：实际验收记录，未通过项不会只凭计划标完成。

当前开发版增加双鸟与海豚，保留真实骨骼/蒙皮；海龟和螃蟹缩小约30%。第二门原贪吃蛇计划由用户批准的[绒芽争园完整玩法](docs/design/bloom-skirmish.md)替代；其余未来游戏仍锁定。旧俯视实现曾通过无头套件与 Linux 原生流程检查，但用户随后否定其镜头/喷射表现；新第三人称版本必须重新验收，当前不得标完成。声音试听、浏览器和用户 Mac 等限制见[任务板](docs/project/TASKBOARD.md)。每个游戏存档隔离到 `user://games/<id>/`，海岛预留 `user://hub/`。

## 独立抽离游戏
```bash
python3 tools/extract_game.py gummy_bomber /tmp/gummy-standalone
python3 tools/extract_game.py bloom_skirmish /tmp/bloom-standalone
# 再以 Godot 打开对应目录内的 project.godot
```
抽离工具拒绝已有目标目录、符号链接和模块外 res 依赖（含路径穿越），保留模块内素材、制作记录与许可证；不带走岛屿或其他模块。详细接口见 [架构](docs/project/ARCHITECTURE.md)。

## 验证与复现
```bash
tools/run.sh --import
tools/run.sh --test
tools/test_all.sh        # 隔离测试存档的完整无头测试
tools/run.sh --sync
```
单模块测试与生命周期测试见模块 README 和 docs/acceptance。截图必须由实际图形 Godot 视口采集；无头测试不能替代视觉验收。历史 v4 说明位于 docs/revisions/README-v4.md。字体许可证与资源一起保留；素材/原始建模文件策略见 docs/project/ASSET_POLICY.md。
