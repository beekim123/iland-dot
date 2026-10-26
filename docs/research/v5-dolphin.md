# V5 海豚：Q 版形体与运动依据

## 已查阅原始机构资料（2026-10-26）
- [NOAA National Ocean Service：Are dolphins fish?](https://oceanservice.noaa.gov/facts/dolphin.html)：海豚是哺乳动物，以肺呼吸；头顶呼吸孔必须定期到水面换气。
- [SeaWorld 动物教育资料：Physical Characteristics](https://seaworld.org/animals/all-about/bottlenose-dolphin/characteristics/)：纺锤体型、短吻与额隆、后弯背鳍、水平分叶尾鳍；胸鳍主要转向；背部和尾柄肌肉驱动尾鳍上下运动。
- [SeaWorld：Adaptations](https://seaworld.org/animals/all-about/bottlenose-dolphin/adaptations/)：跃出再入水是连续的游进过程；不应把跃出表现成静止竖跳。呼吸孔在水下闭合。

## 美术取舍
原创薄荷蓝 Q 版海豚：放大圆润头部与眼睛，缩短吻部，淡色腹面；保留背鳍、胸鳍、尾柄和水平双尾叶的识别结构。不是写实动物，也不是把鱼的左右甩尾动画套在海豚上。眼、嘴、腮红是风格化表达。低采样动图是实际 Blender 骨骼渲染，不是图片摇摆。

## 资产契约
- 生成脚本：`art/v5/dolphin/build_dolphin.py`，无外部素材依赖。
- 编辑文件 / 导入文件：`dolphin_rigged.blend` / `dolphin_rigged.glb`。
- Blender 前向 -Y，Z 上；glTF/Godot 导入前向 +Z，Y 上。根节点位于原点；身体核心接近原点。
- 静止包围盒：X ±0.664；Y -1.119 至 1.186；Z -0.338 至 0.673；全长 2.306m。
- 真骨骼 10 根，23 蒙皮网格；头、脊柱、尾柄、尾叶、胸鳍有实际顶点权重。尾叶骨骼是动画控制器，并非声称尾叶解剖含骨。
- `Swim`：4 秒、源 24fps、97 个含重复端点的采样；头部稳定、躯干轻微俯仰、尾柄与尾叶相位递进上下摆动，胸鳍微调。根运动不包含路线位移，由宿主选择水中路线。
- 无未加权顶点；归一化权重误差 < 1e-7。详细数值见 `rig_qa.json`。
- 本轮优先完整游泳循环，不额外做不可靠的腾空位移动画。接入时应周期性浮到水面，跳跃由路线高度与整体俯仰配合，不要永久深潜。

## 复现
```sh
blender -b -t 2 --python art/v5/dolphin/build_dolphin.py -- --render
ffmpeg -framerate 12 -i art/v5/dolphin/frames/%03d.png -filter_complex '[0:v]split[a][b];[a]palettegen[p];[b][p]paletteuse' art/v5/dolphin/dolphin_swim.gif
```
渲染预览使用 Cycles CPU、480×360、4 samples、2 threads、48 帧 / 12fps。没有把 Eevee 启动失败当作资产失败。

## 实际变形验收
`audit_dolphin.py` 读取编辑文件，比较第 1 / 13 / 97 帧的变形后顶点：最大位移 0.700m，首尾循环误差 0，所有坐标有限。已查看正常体态及尾叶抬高关键帧，形体连接连续。GLB 独立解析：1 skin、10 joints、30 animation channels，所有 mesh primitive 都含 JOINTS_0 与 WEIGHTS_0。导出的时间戳为 1/24 到 97/24 秒（有效动作跨度4秒）；宿主可按4秒范围重设循环，或接受常规约4.04秒 AnimationPlayer 时长。

`dolphin_pose_clean.png` 为32采样实拍静帧；`dolphin_swim.gif` / `.mp4` 为48个实际渲染动画帧。`frames/` 中间图在资产局部 .gitignore 中排除，脚本可重建。未改动宿主、音频或其他动物。
