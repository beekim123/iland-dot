# 晴贝小岛 · Sunny Shell

Godot **4.7.2 stable** 的 Q 版海岛大厅和八款可独立抽离的小游戏工程。仓库：<https://github.com/beekim123/iland-dot>。不改动 Valley Deck 项目。

## 当前入口

导入 `godot/project.godot`，完成资源导入后按 F5。运行资源已包含，无需安装 Blender。

```bash
GODOT_BIN=/path/to/Godot tools/run.sh
```

大厅保留四个固定安全传送门位置，从八款游戏中选择推荐；可刷新推荐，或打开分页的全部游戏目录。回岛恢复原镜头与入口页面。拖动旋转、滚轮缩放，R 复位，2/3/4 切换观景。

| 游戏 | 模块 ID |
| --- | --- |
| 软糖爆爆岛 | `gummy_bomber` |
| 绒芽争园（动物版） | `bloom_skirmish` |
| 逐潮小鱼 | `tide_gulp` |
| 拾光海滩 | `beach_cleanup` |
| 火山岛逃生 | `volcano_escape` |
| 鹈鹕顺风车 | `pelican_pedal` |
| 海底软糖水蛇 | `fruit_gummy_snake` |
| 猴子荡荡 | `monkey_vine` |

操作以各模块说明及游戏内提示为准。当前八款已在注册表启用，不等于所有平台、视觉、性能均已验收；历史六/七/八款验收有各自源码基线和范围，不可互相替代。

## 直接运行与独立抽离

```bash
GODOT_BIN=/path/to/Godot tools/run.sh res://modules/monkey_vine/main.tscn
python3 tools/extract_game.py monkey_vine /tmp/monkey-standalone
# 用 Godot 打开 /tmp/monkey-standalone/project.godot
```

将 ID 替换为表中任意一项即可。抽离保留模块目录结构、素材、制作记录和许可证，不带宿主或其他游戏；拒绝已有目标目录、符号链接和模块外资源依赖。详见[独立抽离指南](docs/modules/standalone-guide.md)。

模块使用 `start(context)` / `exit_requested` 接口，存档位于各自 `user://games/<id>/`；抽离工程另有独立应用名，不会自动迁移大厅存档。无需把相似的存档、UI、音频代码强行合并为宿主依赖。

## 验证与复现

```bash
tools/run.sh --import
tools/test_all.sh --list  # 先查看准确覆盖
tools/test_all.sh         # 当前八款集成/抽离冒烟，不是完整规则全量
tools/run.sh --test       # 海岛场景检查；不是八款验收
tools/run.sh --sync       # 根据 active_asset_manifest 同步已批准素材
```

`test_all.sh` 使用准确的 Godot 4.7.2、临时项目副本和隔离 XDG 存档：检查当前八款覆盖，运行宿主生命周期/传送门/目录测试，逐款真实抽离、导入、调用启动/退出接口并比对源码。日志与 `RESULT.json` 写入打印出的临时目录；不依赖未发布的历史日志。范围及限制见[当前验证入口](tools/qa/current_games/README.md)。

完整规则、长时模拟、真正独立进程退出、图形/人工输入、主观音频、Web 和用户设备性能是不同检查，不以此次冒烟代替。六款全量及七/八款增量历史脚本与证据保留在 `tools/qa/`；六款旧脚本排除水蛇，不能用于当前八款宿主。

## 项目边界与保留策略

- `godot/app/`：注册表、宿主生命周期与路由。
- `godot/hub/`：传送门、交互和游戏目录。`portal_v2/` 是当前运行依赖，不是待删旧版。
- `godot/modules/<id>/`：每款游戏的入口、规则、美术、音频、UI、测试与制作资料。
- `art/`、`audio/`：海岛素材源、生成器和审计记录；批准清单维护运行资源副本。
- `docs/project/`：架构和管理；`docs/acceptance/`：按源码基线保留的历史验收。

字体许可证、动态加载资源、源模型/生成器与复现证据不能仅因“未搜到静态引用”删除。旧人类版绒芽与旧 Web 构建不是当前交付；历史结论保留，不冒充当前版本。详见[架构](docs/project/ARCHITECTURE.md)与[素材策略](docs/project/ASSET_POLICY.md)。
