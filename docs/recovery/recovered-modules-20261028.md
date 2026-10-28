# 沙滩与火山独立模块恢复发布（2026-10-28）

本次仅恢复两个自包含模块，不修改海岛宿主、注册表、传送门、主工程设置或现有三个游戏，不包含尚未恢复的鹈鹕模块。海岛仍保持原有入口；这两个新入口需要后续接入与验收，不能将源码提交称为六门大厅发布。

## 来源与字节验证

- 沙滩：`beach-cleanup-godot-20261027.zip`，SHA256 `5c0317443fd23cd51287a055e7af32a322c133de42a9e774addccb43bbbe46a6`，内部96个源文件逐项匹配清单；其中95个模块文件恢复至 `godot/modules/beach_cleanup/`。
- 火山：`volcano-escape-godot-20261027.zip`，SHA256 `dc75ff6f3b10c1d3f97a5268f82ad3c686829abaf8a9e49a9a43e7a3c765418a`，内部75个源文件逐项匹配清单；其中74个模块文件恢复至 `godot/modules/volcano_escape/`。
- 两包各自的独立 `project.godot` 不覆盖仓库主工程。保留源模型、音频、字体许可证、测试和制作脚本，不上传 `.godot` 缓存或导入产物。
- 检查 GDScript、场景、资源与shader中的68个显式 `res://` 路径，均限定各自模块，无对宿主或其他模块的依赖。

## 独立运行

使用 Godot 4.7.2 打开仓库 `godot/project.godot`，在文件系统中打开以下场景并运行当前场景（F6）：

- `res://modules/beach_cleanup/main.tscn`
- `res://modules/volcano_escape/main.tscn`

也可复制整个模块到独立工程同路径，设置该场景为主场景并采用 Compatibility 渲染器、1280×800窗口。完整操作、存档规则与测试命令见模块README。两者存档分别隔离至 `user://games/beach_cleanup/`、`user://games/volcano_escape/`。

## 验证范围

2026-10-27 的交付记录报告原六游戏728源冻结全套、六fresh抽离与真实原生验收通过；它是历史交付证据，不代表当前恢复工作区重新运行了相同测试。

本次重新验证包SHA256、每个源文件清单、路径安全及模块内资源引用，且提交时保留远端原有文件。当前工作区只有Godot4.6.3，未用旧版本冒充4.7.2导入或玩法回归；本轮未重跑引擎测试。GPU、Web性能和主观音响试听仍未完成。这是源代码提交，不是Web包。
