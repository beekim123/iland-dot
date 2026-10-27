# 晴贝小岛 · Sunny Shell

Godot **4.7.2 stable** 的独立 Q 版海岛大厅和模块化小游戏工程。仓库：<https://github.com/beekim123/iland-dot>。不改动 Valley Deck 项目。

> **绒芽争园动物版源码已发布**：[cc7bed6](https://github.com/beekim123/iland-dot/commit/cc7bed614ff010737ca0761c4bd86c960330382d)，完整原生回合、宿主与真正抽离验证通过；新动物 Web 包、用户设备性能及整场环境美术改版不冒称完成。当前开发第三款「逐潮小鱼」，之后按 [开发队列](docs/project/DEVELOPMENT-QUEUE.md) 依次制作鹈鹕急送、拾光海滩、火山岛逃生。旧俯视/人类版和旧 Web 包仅作历史，不继续交付。

## 运行
用 Godot 导入 `godot/project.godot`，资源导入完成后按 F5。运行资源已包含，不需要安装 Blender。Linux 可用 `GODOT_BIN=/path/to/godot tools/run.sh`；云端脚本默认使用同级 tools 目录内的 4.7.2。

岛屿：拖动旋转、滚轮缩放，R 复位，2/3/4 切换观景。点击物体触发声音和反馈，点击粉色传送门开始软糖迷宫，第二扇青色门进入「绒芽争园」2 对 2 三分钟花园争地；第三扇门仍未开放。小游戏操作与暂停/退出见屏幕提示，退出回岛保留镜头。

### 直接运行绒芽争园
```bash
GODOT_BIN=/path/to/Godot tools/run.sh res://modules/bloom_skirmish/main.tscn
```
当前动物版为第三人称肩后追随、鼠标环视/中心准星、相机相对移动与粘稠花露喷射。准确按键与鼠标捕获以模块 README 和屏幕提示为准；旧俯视操作说明已失效。直接启动与海岛第二扇青色门使用同一模块。

## 项目边界
- `godot/app/`：宿主注册表与路由。
- `godot/hub/`：彩色传送门与交互。
- `godot/modules/gummy_bomber/`：自包含软糖炸弹迷宫，美术/音频/规则/测试一起管理。
- `godot/modules/bloom_skirmish/`：自包含「绒芽争园」，玩家与机器人争地；动物版第三人称完整单局、结果、重开、回岛已验证，非联网对战。
- `art/`：Blender 源模型、生成器与骨骼审计。
- `docs/project/`：架构、任务板、路线图、素材策略。
- `docs/acceptance/`：实际验收记录，未通过项不会只凭计划标完成。

当前开发版增加双鸟与海豚，保留真实骨骼/蒙皮；海龟和螃蟹缩小约30%。第二门原贪吃蛇计划由用户批准的[绒芽争园完整玩法](docs/design/bloom-skirmish.md)替代；后续四款见[开发队列](docs/project/DEVELOPMENT-QUEUE.md)，当前仅第三款在制作。最新动物版验收见[原生记录](docs/acceptance/bloom-animal-native.md)与[独立 QA](docs/acceptance/bloom-skirmish-independent.md)，旧俯视通过记录不能替代当前结果。声音试听、浏览器和用户 Mac 等限制见[任务板](docs/project/TASKBOARD.md)。每个游戏存档隔离到 `user://games/<id>/`，海岛预留 `user://hub/`。

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
