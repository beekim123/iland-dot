# 晴贝小岛 · 原创动物模型

全部由 `art/scripts/build_animals.py` 在 Blender 4.3.2 生成真实网格；没有外部图片、贴图或素材。源场景：`art/blender/animals.blend`。三个独立可导入模型：`art/export/turtle.glb`、`crab.glb`、`seagull.glb`。工作室实渲染：`art/previews/animals_studio.png`。

设计：抹茶色海龟带七块六边形背甲、奶油腹部、亮眼与微笑；珊瑚橙螃蟹带八条腿、两只双指钳和高眼柄；奶油白海鸥带灰青羽翼、金黄色鸟喙与脚掌。低面数圆润玩具风，粗糙度 0.8。

## 接入约定

- 单位米。Blender Z 向上，正面 -Y；glTF 导出自动转为 Y 向上。每份 GLB 只含该动物与其子节点，不含地板、摄影机或灯光。
- 动物中心地面为原点；导出前按求值后的实际最低点校准为 Z=0。
- 海龟：`turtle_head`、`flipper_front_L`、`flipper_front_R`、`flipper_rear_L`、`flipper_rear_R` 可轻缓转动。
- 螃蟹：`claw_L`、`claw_R`；`leg_L_0` … `leg_L_3` 和 `leg_R_0` … `leg_R_3`。
- 海鸥：`wing_L`、`wing_R`、`seagull_head`。羽片是翼节点子物体。
- 子节点保留自身局部中心；建议轻微旋转而非强烈骨骼动画。海龟眼睛为头部子物体，随头运动。
- 精确包围盒、求值后顶点数、材质与全部节点名见 `docs/animals_metrics.json`。

## 复现

```sh
/usr/bin/blender -b -t 4 --python art/scripts/build_animals.py
```

CPU Cycles 1280×720、24 samples；当前 Blender 未编译 OpenImageDenoise，因此显式关闭降噪以保证无外部依赖复现。
