# 晴贝小岛 · Sunny Shell

Godot **4.7.2 stable** 海岛大厅与十四款可独立运行的小游戏。此目录仅保留游戏代码、实际运行素材、配置、许可证及必要测试，不包含原画/Blender 制作源、制作过程归档或预览视频。

## 运行

用 Godot 导入 `godot/project.godot`，完成导入后按 F5；不需要 Blender。

```bash
GODOT_BIN=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/run.sh
```

海岛最多四扇不同游戏推荐门，可刷新推荐；全部游戏目录每页六款，共三页（6 / 6 / 2）。由目录进入后退出会恢复页码与选中。

| 游戏 | 模块 ID |
|---|---|
| 软糖爆爆岛 | `gummy_bomber` |
| 绒芽争园 | `bloom_skirmish` |
| 逐潮小鱼 | `tide_gulp` |
| 拾光海滩 | `beach_cleanup` |
| 火山岛逃生 | `volcano_escape` |
| 鹈鹕顺风车 | `pelican_pedal` |
| 海底软糖水蛇 | `fruit_gummy_snake` |
| 猴子荡荡 | `monkey_vine` |
| 晨曦之剑 | `dawn_sword` |
| 见习小妖王 | `apprentice_yokai_king` |
| 林间牌局 | `woodland_duel` |
| 灯塔净潮 | `tide_lantern` |
| 月影邮差 | `moon_post` |
| 云鲸便当铺 | `whale_bento` |

新 demo 使用原创海岛题材与绘制：灯塔净潮是精准数值净化，月影邮差是同步移动解谜，云鲸便当铺是食材空间组合经营。第二页末尾与第三页可找到三款新作。

操作以游戏内提示为准。各模块独立保存至 `user://games/<id>/`，不共享档案。晨曦之剑仍有动画/视觉润色事项；设计通关时长不是玩家实测承诺。

## 独立抽离

```bash
python3 tools/extract_game.py woodland_duel /absolute/new/standalone
# 用 Godot 打开生成的 project.godot；可换用表中任意 ID。
```

提取器拒绝覆盖已有目录、符号链接和模块外资源引用；保留运行目录结构与许可证，不复制海岛或其他模块。独立项目名称不同，不自动迁移大厅存档。

## 测试

```bash
# 日志和临时副本放工程外；TMPDIR 应有足够空间。
TMPDIR=/absolute/external/qa GODOT_BIN=/absolute/path/to/Godot tools/test_all.sh
python3 tools/qa/test_standalone_games.py --godot /absolute/path/to/Godot --lifecycle-only
```

`tools/test_all.sh --list` 列出准确范围：当前十四款宿主/目录/传送门、抽离及公共启动退出接口。独立进程退出另测；均不等于完整玩法、原生输入、主观视觉/声音或所有设备性能验收。模块规则测试仍在各 `tests/` 下。
