# 晴贝小岛 · Sunny Shell

独立 Q 版海岛工程，当前版本已接入用户验收的新地形、植物与模型，以及真实骨骼/蒙皮动画。海龟游泳、海鸥飞行、螃蟹横行、16条小丑鱼游动，搭配动态海水、原创音乐与海浪。未改动《一副山谷》。

## 打开运行
使用 **Godot 4.7.2 stable** 导入 `godot/project.godot`，等待资源导入后按 **F5**。运行资源已包含在工程内，无需安装 Blender。

本次云端环境也可从本目录执行：
```bash
tools/run.sh             # 图形运行
tools/run.sh --shots     # 五张真实实机图，包括骨骼动作近景
tools/run.sh --gif       # 120张真实视口源帧，10秒固定时间展示
tools/encode_gif.sh      # 生成新v4动图
tools/encode_video.sh    # 同一画面的MP4，带原创音乐与海浪
tools/run.sh --test      # 无头资源、骨架、材质适配与控制检查
```
`run.sh` 默认指向本云端 `../tools/godot-4.7.2/`。其他 Linux 机器请设置 `GODOT_BIN=/你的/Godot可执行文件`；Windows/macOS直接打开工程。截图和动图采集需要真实图形桌面，无头模式不生成伪造实机图。

## 操作
拖动旋转、滚轮缩放；R复位，2海岸，3游泳近景，4飞行近景；M静音，空格暂停动画，H隐藏帮助。底部按钮和音量滑块也可操作。

## 当前交付
- `art/previews/runtime/sunny_shell_island_motion_v4.gif`：10秒，640×400，无声循环动图。
- `art/previews/runtime/sunny_shell_island_motion_v4.mp4`：10秒，960×600，含原创音乐与海浪。
- `art/previews/runtime/v4_*.png`：真实图形窗口截图。
- `art/previews/runtime/gif_frames_v4/`：最终120张实际视口源帧。
- v1/v2已交付预览仍保留，未覆盖。

## 源文件与复现
- `art/v3/`：已验收的新模型、地形契约与组装主场景。
- `art/rigged/`：真实Armature/蒙皮与动作源、对应GLB。
- `audio/source/`、`audio/export/`：原创音乐源及WAV。
- `godot/`：独立可运行工程。
- `docs/active_asset_manifest.json`：唯一当前资源同步清单；`tools/sync_resources.py` 不再扫描旧导出目录。
- `backups/godot_v2_before_rigged_v4.tar.gz`：接入前可回退快照，建议先解压到独立目录验证。
- `docs/revisions/godot-approved-rigged-v4.md`：接入记录、实际验证与限制。
- `docs/godot-rigging-qa.md`：独立Godot骨骼、蒙皮、动作与颜色诊断。

## 验证与许可
Godot 4.7.2无头检查通过；19个真实Skeleton3D与五个骨骼动作通过独立检查。实际云端窗口验证了已验收模型配色、海水、游泳和飞行动作近景。音频流可解码且非静音，不声称主观试听。近景镜头有意只突出部分动物，不保证所有对象同时入镜。

界面字体是Noto Sans CJK字形子集，按SIL Open Font License 1.1分发；来源与完整许可在 `godot/resources/fonts/SOURCE.txt`、`OFL.txt`。
