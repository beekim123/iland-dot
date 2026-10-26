# Q 版螃蟹：真实骨骼、蒙皮与侧行循环

保留已认可的 v3 螃蟹轮廓、比例、材质；没有改动 `art/v3/` 或 Godot 工程。

## 文件
- `crab_rigged.blend`：可编辑骨架、蒙皮、关键帧和 IK 控制目标。
- `crab_rigged.glb`：可移植骨骼蒙皮与烘焙动作。
- `crab_pose.png`：实际 Blender 姿势渲染。
- `crab_scuttle.mp4` / `.gif`：实际渲染帧编码；4 秒，静音。
- `rig_crab.py`：从批准模型重新构造骨架、权重和动画。
- `rig_qa.json`：模型及动作数值检查。

## 骨骼与权重
26 根骨骼：根、身体、8 条两段式腿、左右钳臂/手掌/活动钳指、两根眼柄。32 个网格全部有实际 Armature modifier、骨骼顶点组和归一化蒙皮；腿膝与钳臂过渡区域混合权重，其余硬壳/眼睛按身体结构刚性蒙皮。不是 EMPTY 枢轴假扮骨骼。

## 动作
`Crab_Scuttle_Loop`，24 fps，1–97 帧含闭环重复端点。脚掌支撑期使用世界空间固定 IK 目标；回摆期抬脚并平滑落地。左右交错腿组轮换，身体轻微侧移/起伏，钳子保持平衡。

这是可循环的短步姿态动作，用于检查关节与落地，不是长距离世界移动演示。将来接入引擎时可把路径移动与步态速度匹配；本轮未做 Godot 接入。

## 复现
在项目根目录运行 `/usr/bin/blender -b -t 2 --python art/rigged/crab/rig_crab.py`；完成后运行 `art/rigged/crab/encode.sh`。`--skip-render` 只生成骨架/导出/验证，不生成动画帧。

静态预览为 Cycles CPU 640×480/16 samples；动画为 480×360/6 samples，96 张真实帧，MP4 24 fps，GIF 12 fps。低采样预览可见轻微颗粒，未用静态图像伪造动作。
