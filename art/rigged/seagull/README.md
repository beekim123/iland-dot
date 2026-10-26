# 海鸥：真实骨骼、蒙皮与动作

保持 `art/v3/animals.blend` 中已认可的海鸥几何与材质。没有将模型拉长或重新塑形；原来沿身体折叠的翅膀通过骨骼展开。

## 成品
- `seagull_rigged.blend`：可编辑模型、17 骨 Armature、蒙皮、Fly / Glide 两个 Action，以及预览灯光和摄影机。
- `seagull_rigged.glb`：独立带骨骼模型，包含一个 skin、17 个 joints、两条真实动画；每条动画 51 个通道。
- `seagull_pose.png`：真实 Cycles 单帧，640×480 / 8 samples。
- `seagull_fly_preview.gif` / `.mp4`：4 秒真实 Blender 动画预览；480×360，12 fps。源动作是 24 fps，预览每隔一帧取样，未改变动作速度。GIF 无限循环；视频无声音。
- `seagull_motion_contact.png`：一个振翅周期的四个关键时点。

## 蒙皮和动作
主干、颈部和头部有平滑过渡权重。双翼使用肩、肘、腕、羽端四级骨骼与连续过渡权重，不是仅旋转整体物件或空节点。眼睛与喙刚性跟随头骨；脚部以腿/足骨收拢；尾羽跟随尾骨。每个渲染网格都有 Armature 修改器和归一化权重，无未赋权顶点。

Fly 为 1.5 Hz 的协调振翅，翼肘、腕和羽端有相位延迟，躯干起伏、头部轻微稳定。Glide 保持展开翼形，只有轻微姿态修正。两条动作都是 1–97 帧（24 fps，末帧与首帧循环对应），预览渲染 1–96 帧。姿态展示是原地飞行动作循环，不宣称带导航、物理气动或 IK。

## 复现
从项目根目录运行：

```bash
blender -b -t 2 --python art/rigged/seagull/rig_seagull.py
blender -b -t 2 --python art/rigged/seagull/render_quick.py
art/rigged/seagull/encode_preview.sh
```

源 Blender 版本 4.3.2。Eevee 无头测试遇到 EGL_BAD_MATCH，已停止该尝试；预览使用 Cycles CPU、2 线程、4 samples，以尽快展示动作，因此有可见采样颗粒。未使用静态图片伪造运动。未改动 Godot 或原始 v3 文件。

导出前所有 NLA 轨道均静音，采用 ACTIONS 导出 Fly / Glide，避免 NLA 和当前 Action 重复叠加。场景预览使用主动 Fly Action；当前 NLA 轨道静音。

技术检查见 `rig_report.json` 与 `preview_qa.json`；独立审查结果由总体审核代理提供。
