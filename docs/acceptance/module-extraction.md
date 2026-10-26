# 仓库抽离工具验收

2026-10-26，Godot 4.7.2.stable.official.ed1daf0bf。

- `python3 tools/extract_game.py gummy_bomber /tmp/gummy-extraction-verify`：成功，工具扫描 `.gd/.tscn/.tres` 未发现模块外 `res://` 依赖。
- 仅生成模块目录和最小 `project.godot`，没有岛屿/app/hub 文件。
- 独立工程 headless editor import：完成。
- 显式可写 XDG 数据/缓存/配置路径下 headless 运行120帧并退出：日志只有版本头，无 ERROR/WARNING。
- 初次未指定 XDG 时环境沙箱无法写入默认 `/home/agent/.local/share`；这是运行环境路径限制，改为 `/tmp/gummy-xdg/` 后复测通过，没有扩大权限。

工具拒绝非法 ID、缺少入口及已经存在的目标目录。更多规则、20轮生命周期和存档注入审计见 `gummy-bomber-independent.md`。本记录不替代图形界面美术验收。
