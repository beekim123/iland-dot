# v4 骨骼动画接入 Godot：独立技术验收

检查环境：Godot **4.7.2 stable**，2026-10-26。使用独立脚本 `tools/godot_rig_audit.gd`；未修改已验收 Blender 模型，也未编辑集成实现。

## 结果

**无头技术检查通过，0 项失败。** 此结论不是图形画面验收，不代替实际窗口的材质、遮挡、接地、相机与动画观感检查。

| 动物 | Skeleton3D 骨骼数 | 带 Skin 的网格 | 导入后混合权重顶点 | 动作 |
|---|---:|---:|---:|---|
| 海龟 | 15 | 42 | 3632 | Turtle_Swim_Loop_4s |
| 小鱼 | 11 | 23 | 10218 | Swim |
| 海鸥 | 17 | 36 | 7516 | Fly、Glide |
| 螃蟹 | 26 | 32 | 2720 | Crab_Scuttle |

导入后的顶点数量可能因法线、UV 和接缝拆分不同于 Blender 基础网格。

- 四种模型均有真实 `Skeleton3D`、`AnimationPlayer`、非空 Skin 绑定与骨骼/权重顶点数组。
- 每个带 Skin 网格的 skeleton 路径均指向正确骨架，顶点权重总和通过归一化检查。
- 五个动作的骨骼轨道均存在；不仅检查轨道数，还实际调用 `AnimationPlayer.seek` 读取骨骼姿态。
- 实际 `bone_actor.gd` 适配器推进 1/24 秒时，海龟 15、小鱼 11、海鸥 Fly 13 / Glide 11、螃蟹 25 根骨骼改变姿态。
- 五个动作在运行时 0、1、2、3 秒的相邻采样姿态均不同，0 秒与 4 秒的全部骨骼姿态差为 **0**。
- 循环接缝两侧（4 秒 ± 0.0001 秒）最大姿态差小于 **0.00083**，未出现循环瞬移。
- 实际 `island.tscn` 初始化后有 **19 套骨架**（海龟、螃蟹、海鸥及 16 条鱼）；场景时钟推进 1/24 秒后 **19 套全部改变骨骼姿态**。
- 实际场景中旧 `MotionJoint` / `TailPivot` / `FinPivot` 节点数为 **0**。检查当前 wildlife/fish 脚本，仅程序化改变完整动物的世界路径与朝向，不再改动单独的翼、鳍、腿网格。

## 重要：导入时间轴修正

原始 GLB 时间戳约为 0.041667→4.041667，原始动作跨度为 4 秒。但 Godot 导入/重采样后，从 **0→4.041667** 的首尾姿态才一致。不能仅根据原始 GLB 时间戳推断 Godot 播放偏移。

独立姿态测试发现：给 Godot 采样时间直接加 1/24 秒，会在循环边界产生非零差异；这一早期建议已经撤回。最终集成采用并已验证：

```gdscript
player.seek(fposmod(time, 4.0) / 4.0 * animation.length, true)
```

即把完整导入片段归一化到四秒，并显式开启循环、手动推进。螃蟹导入时动作名由源文件的 `_Loop` 后缀形式变为 `Crab_Scuttle`，集成已使用实际名称。

Godot 播放的是导出后的独立动作资源；适配器手动采样单个 AnimationPlayer。此前 Blender 最终 GLB 已在全部 NLA track 静音后导出并检查。此次未发现多个播放器或旧网格关节逻辑叠加，但无头检查不等价于对所有图形效果作出保证。

## 复现

从 `chibi-island/` 执行（也可将可执行文件替换为自己的 Godot 4.7.2）：

```bash
../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path godot --script ../tools/godot_rig_audit.gd
```

结果写入 `docs/godot-rigging-audit.json`；本次日志为 `docs/godot-rigging-audit.log`。本脚本验证导入绑定及骨骼姿态，不对 GPU 蒙皮后的屏幕像素进行无头“视觉”断言。此前 Blender 的实际非刚性顶点变形证据见 `docs/rigging-qa.md`。

## 附：地形颜色的独立诊断

实际窗口曾显示深绿草地与橙黄沙滩，明显不同于已验收的 `art/v3/island_v3_overview.png`。检查原始数据发现：

- Blender `build_landscape.py` 使用 `FLOAT_COLOR`、`color` 写入线性空间颜色，并直接接入地形 Base Color。
- GLB 地形 `COLOR_0` 为 FLOAT/VEC3；原始第一个颜色为 `(0.0914163, 0.3533680, 0.0836097)`，材质没有额外 `baseColorFactor`，即默认白色。
- Godot 导入后的地形 albedo 仍为白色；抽样颜色为 `(0.0824, 0.3412, 0.0824)`，不是重复乘了绿色材质。
- `vertex_color_is_srgb` 在 Compatibility 不执行转换，因此仅开关该选项不能修复。官方 [BaseMaterial3D 文档](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb) 明确限定该选项只对 Forward+/Mobile 有效；[官方材质实现](https://github.com/godotengine/godot/blob/master/scene/resources/material.cpp) 也在 `!OUTPUT_IS_SRGB` 条件内进行相应转换。

建议集成端对 Compatibility 地形运行时网格副本进行一次 **linear_to_srgb**，或在该材质 shader 内按 `OUTPUT_IS_SRGB` 条件作等效转换；不得改动源 GLB 或擅自调整已验收配色。例如上述 Godot 颜色转换后约为 `(0.3178, 0.6190, 0.3178)`。不能使用反方向的 `srgb_to_linear`，也不要再次转换其他已由导入器正确处理的材质颜色。实际修复及最终截图由集成人员负责；本段记录诊断依据，不将预期结果当作已完成的视觉验收。
