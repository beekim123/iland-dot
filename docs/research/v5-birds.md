# V5 双海鸟：先参考结构，再保留 Q 版造型

2026-10-26。目标不是写实化；修复旧版翼展小、翼面狭窄、整体像身体两侧挂件的问题。头身、眼睛和干净粘土质感沿用用户已认可的 v3。

## 查阅资料

- Cornell Lab, American Herring Gull identification: https://www.allaboutbirds.org/guide/herring_gull/id — 体长 56–66 cm，宽厚胸部和长翼轮廓。
- Audubon, American Herring Gull: https://www.audubon.org/field-guide/bird/herring-gull — 翼展 120–150 cm；不应把真实飞行翼做成短小装饰。
- Cornell Lab, Common Tern: https://www.allaboutbirds.org/guide/Common_Tern/id — 翼展 75–80 cm，尖长翼及分叉尾。
- Audubon, Common Tern: https://www.audubon.org/field-guide/bird/common-tern — 体长 32–36 cm、翼展 76–89 cm；第二只的黑帽、窄长翼和尾形参考。
- Cornell Bird Academy, Everything You Need To Know About Feathers: https://academy.allaboutbirds.org/feathers-article/ — 初级与次级飞羽是构成翼面、有骨性附着关系的飞行羽；不能只有几根悬空羽毛。
- US Fish & Wildlife Service Feather Atlas glossary: https://wwwcf.fws.gov/lab/featheratlas/glossary.html — 初级飞羽连接手部骨骼；次级飞羽连接前臂尺骨。这支持肩、肘、腕分段驱动，而非整翅硬板旋转。
- University of Waikato Science Learning Hub, How birds fly: https://www.sciencelearn.org.nz/resources/303-how-birds-fly — 翼面、升力与推力，以及扑翼/滑翔的区别。

## 制作取舍（风格化设计，不声称生物力学仿真）

1. 翼展目标约 3.4 个 Blender 单位，全长约 1.5，约 2.3:1；保持可爱大头、不复制真实成年鸟比例。
2. 连续圆润翼面承托身体；下方重叠飞羽提供清楚、少细节的末缘，翼尖较深配色。
3. 真正蒙皮连接 shoulder / elbow / wrist / feather，肘区平滑混合权重。
4. Fly: 4 秒闭环、每秒约 1.5 次扑翼；上臂主扑动、肘部适度回收、腕部错相扭转，身体只轻微响应。
5. Glide: 展翼小幅修正；世界路径上的转弯/侧倾应由 Godot 路径适配器控制，不能将固定方向转弯烘焙进所有实例。
6. 小脚向后收拢；模型前向与速度方向必须一致，否则正确骨骼也会像倒飞。
7. Gull 白头银灰翼，Tern 黑帽蓝灰翼珊瑚嘴与加长两侧尾羽；二者同一动作 ABI，独立文件。

## 导入约定

源码 `art/v5/birds/build_birds.py`。`gull/`、`tern/` 各自提供 `bird_rigged.blend` 和 `bird_rigged.glb`。Blender 前向 -Y、上向 +Z，标准 glTF 导出转换后 Godot 前向 +Z、上向 +Y。根节点导出时单位缩放、零平移；摄影棚位置在导出后才设置。Fly / Glide 两个独立 4 秒循环片段。实际导入长度需按已有 Godot importer 的端点映射归一化，不得把 Blender frame 1 的 1/24 秒机械地加到 Godot 时间。
