# 海龟真实骨骼 / 蒙皮 / Swim 动作

基于用户认可的 `art/v3/animals.blend`，不改变模型造型、颜色或比例，不修改 Godot。

- `turtle_rigged.blend`：可编辑真实 Armature 与 42 个蒙皮网格，15 根骨骼。
- `turtle_rigged.glb`：含 skin、JOINTS_0、WEIGHTS_0 与 `Turtle_Swim_Loop_4s` 动作的独立模型。
- `rig_turtle.py`：复现骨骼、连续蒙皮、动作与验证。
- `rig_qa.json`：归一化权重、无漏权重顶点、多个动作时点边界与 GLB 结构验证。
- `turtle_swim_pose.png`：实际 Blender 变形姿态预览。
- `render_draft.py`：实际 Blender Cycles 快速运动预览（48 帧、12 fps、4 秒）。

骨骼：root、body、neck、head、tail，左右各三节前鳍、两节后鳍。甲壳与躯干刚性跟随 body；颈部、鳍肢根部和关节区域使用连续混合权重，眼睛跟随 head。鳍肢各节存在延迟推进/恢复动作，不是只有整只模型的位置变动。

原始动作帧率 24 fps，循环端点为第 97 帧，播放第 1–96 帧。快速预览每隔一帧采样，按 12 fps 播放，仍为真实 4 秒速度，不加速或慢放。

复现：

    blender -b -t 2 --python art/rigged/turtle/rig_turtle.py
    blender -b -t 2 --python art/rigged/turtle/render_draft.py

快速预览采用低采样保证及时可视化，存在渲染颗粒；这不代表几何缺陷。尚未进入 Godot。

最终交付预览：`turtle_swim_preview.gif` / `.mp4`，480×360、4 秒、12 fps、无声。二者来自 48 张真实 Cycles 渲染图，仅进行轻量视频降噪，没有插帧或伪造运动；原始帧在 `draft_frames/`。编码脚本为 `encode_preview.sh`。

GLB 时间戳保留 Blender 第 1 帧起点 1/24 秒，最后循环关键帧为 97/24 秒，差值精确 4 秒。归一化权重和真实非刚性变形另经独立审查通过；不是 EMPTY 枢轴伪装骨骼。当前未启动高清重渲染，不改已认可的 v3 源模型。
