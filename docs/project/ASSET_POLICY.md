# 素材与仓库策略

运行需要的 GLB/WAV/字体/许可证直接入库；无需 Blender 即可运行 Godot。保留源 `.blend` 与 Python 制作脚本，以及 glTF/骨架/循环审计 JSON。已交付艺术是 Q 风格，未授权的风格替换不属于常规整理。

不提交 `.godot/`、`.runtime/`、逐帧渲染、编辑器临时备份、旧工程压缩备份、生成日志、引擎安装包。截图仅选择验收代表图。大源文件不使用假的 LFS 指针；当前普通 Git 单文件保持低于 GitHub 限额，未来大型纹理/录屏另行约定存储策略。

`docs/active_asset_manifest.json` 是资源同步唯一清单，`tools/sync_resources.py` 仅复制显式条目并产出 SHA-256。禁止通配旧目录覆盖已审批新模型。独立游戏素材必须留在模块内，来源和许可证同目录可追溯。

最大 v3 汇总 .blend 在仓库副本使用 Blender 原生 compress=True 保存（15.1MB→2.97MB），非网格简化；重开场景对象/网格/材质计数与几何拓扑变换摘要一致。原工作区未压缩源保留。见 docs/acceptance/blend-container-compression.json。
