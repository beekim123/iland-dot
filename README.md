# 晴贝小岛 · Sunny Shell

Godot **4.7.2 stable** 的独立 Q 版海岛大厅和模块化小游戏工程。仓库：<https://github.com/beekim123/iland-dot>。不改动 Valley Deck 项目。

## 运行
用 Godot 导入 `godot/project.godot`，资源导入完成后按 F5。运行资源已包含，不需要安装 Blender。Linux 可用 `GODOT_BIN=/path/to/godot tools/run.sh`；云端脚本默认使用同级 tools 目录内的 4.7.2。

岛屿：拖动旋转、滚轮缩放，R 复位，2/3/4 切换观景。点击物体触发声音和反馈，点击开放的粉色传送门直接开始软糖迷宫；未开放门不会启动游戏。小游戏操作与暂停/退出见屏幕提示，退出回岛保留镜头。

## 项目边界
- `godot/app/`：宿主注册表与路由。
- `godot/hub/`：彩色传送门与交互。
- `godot/modules/gummy_bomber/`：自包含软糖炸弹迷宫，美术/音频/规则/测试一起管理。
- `art/`：Blender 源模型、生成器与骨骼审计。
- `docs/project/`：架构、任务板、路线图、素材策略。
- `docs/acceptance/`：实际验收记录，未通过项不会只凭计划标完成。

当前开发版增加双鸟与海豚，保留真实骨骼/蒙皮；海龟和螃蟹缩小约30%。3个未来游戏仅设计、保持锁定。每个游戏存档隔离到 `user://games/<id>/`，海岛预留 `user://hub/`。

## 独立抽离游戏
```bash
python3 tools/extract_game.py gummy_bomber /tmp/gummy-standalone
# 再以 Godot 打开 /tmp/gummy-standalone/project.godot
```
抽离工具拒绝已有目标目录，检查外部 res 依赖；不带走岛屿或其他模块。详细接口见 [架构](docs/project/ARCHITECTURE.md)。

## 验证与复现
```bash
tools/run.sh --import
tools/run.sh --test
tools/test_all.sh        # 隔离测试存档的完整无头测试
tools/run.sh --sync
```
单模块测试与生命周期测试见模块 README 和 docs/acceptance。截图必须由实际图形 Godot 视口采集；无头测试不能替代视觉验收。历史 v4 说明位于 docs/revisions/README-v4.md。字体许可证与资源一起保留；素材/原始建模文件策略见 docs/project/ASSET_POLICY.md。
