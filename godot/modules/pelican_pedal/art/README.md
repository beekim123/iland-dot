# 鹈鹕顺风车角色与自行车

原创 Q 版薄荷帽鹈鹕快递员，珊瑚色领巾、奶油羽毛、圆润长喙与喙袋、薄荷自行车和开放式水果篮。不使用外部模型或图像贴图。由 AI 辅助编写 Blender 生成器制作，非照片/概念图替代模型。

## 资源与接口
- `models/pelican_rider.glb`：完整骑手，16骨骼、真实Skin、70个多骨骼混合权重顶点。
- `models/first_person_rig.glb`：仅保留翼手、喙、腿脚的独立皮肤，避免相机穿头；共享相同骨架与动作。
- `models/bicycle.glb`：车架、两只独立WheelFront/WheelRear，非透明篮子几何。
- `pelican_bicycle.gd`：Node3D；加入树前设置 `first_person`（默认true）；`set_motion(speed, steering, braking, delta)`驱动实际蒙皮动作和车轮。
- 坐标：Godot Y-up，前方-Z，原点地面。眼点建议(0,1.68,-0.12)，近裁剪0.05，FOV72，默认轻微俯视20度。独立FP喙为防遮挡的专用缩窄下移视图模型，不改变完整骑手外观。第一人称最终可视比例需在完整游戏中再次验收。
- 动作：idle、pedal、steer_left、steer_right、brake，无根运动。转向与刹车使用独立姿态动画，踏频随速度变化。蹬踏按两节腿解析IK烘焙每帧骨骼关键帧；两腿相差半周期；脚踏板跟随实际骨骼脚底锚点，不靠独立时钟造成滑步。

## 制作与验证
使用 Blender 4.3.2 运行 `source/build_pelican.py` 重建全部GLB及源文件；不需要Blender运行游戏。源文件在 .gdignore 目录内，避免Godot直接导入.blend。
`preview.tscn` 为实际Godot模型台；`test_assets.gd` 检查真实Skin、16骨骼、5动作、实际大腿骨变形与两个车轮随速度旋转，以及四个周期采样的脚踝目标误差小于4毫米、踏板脚底接触误差小于0.1毫米。Godot4.7.2独立临时工程通过，未以此冒充完整玩法验收。
