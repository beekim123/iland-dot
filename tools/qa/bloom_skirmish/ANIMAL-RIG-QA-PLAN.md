# 动物真实骨骼与蒙皮验收

2026-10-27 08:03 UTC：仅动物建模、真实骨骼/蒙皮/新动画及直接入游戏范围获批。环境重做、发布和完整 aggregate 仍未获本轮执行放行；等待 root 冻结。旧人类、刚性动物、水獭试点、完整八动物是不同阶段，不混写为完成。

## 已确认事实

- 07:53 独立读取旧四物种×两队 8 个 GLB：全部 `skins=0 / animations=0 / weighted primitives=0`，不是骨骼版。
- `skin_assets.py --pilot` 已对旧刚性水獭做负例，正确以 `NO SKIN` 拒绝。
- 第一只工作版蓝水獭 `models/animals/rigged/otter/otter_blue_rigged.glb` 的独立资产检查：1 skin、24 joints、19383 个加权导出顶点、4475 个多骨混合顶点、23 个真实受权重/动画影响的关节，初版 6 条非恒定骨动画。其余动作与角色仍在制作，非最终集合通过。
- 08:02 把水獭 GLB 和当时 art 脚本复制进独立临时工程、重新导入后，`skin_runtime.gd` 单模型 **19456 项、0 失败**。实际 Godot `Skeleton3D`/`Skin`/逆绑定矩阵和权重计算显示：转动 Spine 后 1697 个顶点改变，最大位移 0.22685，点对距离变化 0.14366（不是整件刚体移动）；实际 run 骨动画也改变加权顶点，骨恢复无漂移。日志 `/tmp/bloom-otter-skin-isolated.6z5QPp/pilot.log`。
- Dummy/headless 的 `bake_mesh_from_current_skeleton_pose()` 在正确的合成双骨夹具上也拒绝无渲染 RID。因此上述是 **实际导入骨架的独立 CPU 蒙皮证明**，不单凭 headless 结果声称 GPU/实机渲染验收。
- **08:06 root 原生试点返回通过**：root 经 CUA 在隔离 `build/native-skin-pilot` 中启动非 headless Godot，`native-probe.log` 为 **19458 项、0 失败、native_bake=true**。Spine 实际 Godot bake 产生 changed=1697、max=0.2268538、shape=0.1436646，与独立 CPU 结果相符。试点模型 SHA-256 为 `c8d1ffd0d395b1d91f53b2289b275aa2f3c33be7d963211c9e91414e16a52214`，与独立临时工程测过的蓝水獭一致；root 留存 `snapshot.json`。这是 root 提供的**单只原生渲染形变证明**，不是 8 角色冻结、最终动作/视觉接受或用户硬件性能证明。最终资产完成后仍需全 8 重测。
- 08:22 独立检查指定短接地 run 试点，仅蓝水獭 SHA `e5ce863e4f833bebcc4128cb36f6ced74e38f3b1676aa430ab1b093b69849eeb`，隔离复制并默认重导入，经真实工厂实例化：**19790 项、0 失败**，9 个 clip × 13 个非整帧时刻；掌心 `Hand.R` 到 `GunGrip` 最大误差 **2.275mm**（未加游戏 1.3 倍缩放的模型空间，idle 1.538462s），不能把 authored 关键帧的微米级数字扩展到所有 Godot 插值时刻。日志 `/tmp/bloom-otter-contact-pilot.fF8Vgu/pilot-detailed.log`。实际材料色保留，重挂 Weapon 的 owner warning 已修复。其他角色当时仍在修改，不能据此写全 8 通过。

## 自动化门槛

1. `skin_assets.py` 默认必须找齐兔/狐/水獭/浣熊 × 蓝橙 8 个唯一 `*_rigged.glb`，不能因缺文件自动降为试点。
2. 真正的 glTF skin、有效 joints、逆绑定矩阵、与 POSITION 匹配的 JOINTS/WEIGHTS、有限且归一化权重、多骨混合区域；至少 12 个独立关节、10 个实际受权重关节、16 个多骨混合顶点，拒绝只给旧摆件套空骨架。
3. 所有动画轨道必须实际指向 joint，时间单调、数值有限且非恒定；完整集要求 idle/run/spray/dash/hit/pod/respawn/celebration/defeat。试点模式明确打印 PILOT，不出 FULL CAST。
4. `skin_runtime.gd` 默认经真实 `Art.make_animal` 工厂实例化 8 组合，要求请求物种/队伍不被 fallback 替换，实际 Skeleton3D、Skin、加权数组；旋转非根骨骼产生局部非刚性变形而非 Node3D 位移，并能恢复；实际 run clip 必须驱动网格。
5. `lifecycle.gd` 已新增：实机 4 角色均有真 Skeleton3D，物种集合齐全；暂停后跨实际帧等待，骨 pose 和 AnimationPlayer 时钟均不推进。既有 20 次重开/退出/音频/液体/无孤儿/保存隔离门槛保留。
6. `perspective.gd` 保留 1920 个实际 `Weapon/Muzzle.global_position` 对物理发射点的姿态探针；新增头部 25% 俯仰、同帧重复不累积、回零恢复原骨 pose，同时 Grip/Muzzle 不变。真实权重不能改变枪口弹道、相机碰撞或权威涂层。
7. 完整资产、Godot 蒙皮以及真正提取工程的重复检查已接入 aggregate，但 **尚未执行整轮**。缺失或刚性模型必须失败，不能删测试换通过。
8. `animal_runtime.gd` 已准备并解析通过：实际游戏的 9 动作选择、命中后真实骨 pose 变化、花苞 `owner_id` 不是对象 `id`、真正 4 秒复活、暂停跨帧冻结全部骨/动作/时钟/握点/喷口、结算只推进视觉时钟而比赛数据冻结、重开清理反应和退出停用 AnimationPlayer。额外测实际移动速度下的 120 帧接地足骨位移，避免只检查“播放倍率”而漏掉游戏步幅滑移。完整角色动作稳定后才执行这项全局 probe。

### 正确性适配与已知边界

- 动物可使用材料色或顶点色；水獭使用实际 PBR 材料色，不能沿用“必须含 ARRAY_COLOR”的旧造型假设。颜色检查现要求真实可见材质、实际多色调板或有效顶点色，不允许纯白 fallback；有顶点色时仍要求启用 albedo 使用。
- `skin_runtime.gd` 的掌心检查使用实际 Hand.R 骨 head，不只验证 GunGrip 标记自身静止；后者单独不构成握持证明。
- 现抽离器会排除 `.import`，试点正是默认重新导入的结果。若最终修复依赖定制导入设置，必须同步持久化模块导入契约和抽离策略，再以真正提取工程重测；只修宿主缓存不算完成。
- 最终未依赖定制导入参数；8 个模型 SHA 与 `final_asset_manifest.json` 一致，原始 8 份建模 `.blend` SHA 也独立确认未变。全 8 隔离默认重导入后的工厂/骨/颜色/握持检查为 **149332 项、0 失败**，最坏掌心误差 2.705mm（模型空间），日志 `/tmp/bloom-animals-focused.WIxrxs/skin.log`。
- 新增 `skin_palette.py` 按三角形**世界面积**对比狐狸原 `COLOR_0` 与 rigged PBR 色块（排除获批改造的武器与透明玻璃）。两队各 32616 个不透明非武器三角，面积比 0.9999999954，各色面积占比最大差 2.90×10⁻⁹；不会被“材质数相同但面分配错了”骗过。最终 aggregate 与提取工程均重跑。
- 08:32 新接地探针曾误把 `Foot` 骨 head 的全周期最低 Y + 2mm 当作接地条件，只给兔计入 3 个样本。读取 trace 和绑定契约后确认该点是踝而非鞋底：踝在短 stance 中可有毫米级插值凹陷。没有改任何实现或删掉门槛，改为用已知 0.6s clip 的左脚 0–0.2s、右脚 0.3–0.5s 相位识别接地，**从真实 Skin 的 Foot 权重=1 顶点提取鞋底底面中心与最低点**，测实际变形后的鞋底，而非任意 marker。原连续样本 ≥20、水平位移 <4mm/frame 保留；新增真实鞋底不得穿地或离地超范围的检查。四动物各有 64 个接地样本，最坏鞋底残差 1.269mm/frame；鞋底 Y 0.03798–0.04001、地板 Y 0.025，13–15mm 的既有美术 root 净距明确保留，不虚称精确贴合。该增强后实际游戏 **1088 项、0 失败**，日志 `/tmp/bloom-final-animal-game.ZaVIBg/actual-sole.log`。

## 原生实际蒙皮证明（root 执行）

先用当前 Godot 执行编辑器导入，再在正常非 headless 窗口中运行：

```sh
Godot --path godot --script "$PWD/tools/qa/bloom_skirmish/skin_runtime.gd" -- \
  --native-skin-probe \
  --raw-model=res://modules/bloom_skirmish/art/models/animals/rigged/otter/otter_blue_rigged.glb
```

该模式等待实际渲染帧，通过 Godot 原生 skeleton bake 比较旋转前后的实际网格顶点与非刚性点距；只有真成功才打印 `NATIVE_SKIN_DEFORMATION` 和零失败。`--raw-model` 只证明该导入资产，不证明工厂或完整游戏。工厂就绪后可用 `--only-species=otter` 测两队，最终不带范围参数测全 8 组合。

## 仍须观察的运行证据

- 游戏中确实是 4 种动物，不是人类 fallback；材质/顶点色保留，蓝橙队色及物种特征可读。
- 真实行走/喷射/冲刺/受击/放苞/复活/胜负动画，骨骼驱动有机网格，不能只看到武器或独立部件摆动。
- 暂停/失焦不换成 idle 或推进骨动画；结果可只推进视觉胜负动画，但比赛数据/计时必须冻结。
- 实际枪口与喷流连接，手部握持不游离；复活无残留姿态，重开/退出停止所有 AnimationPlayer。
- 原生实际操作、近景与后视检查仍由 root/用户确认。几何/节点/CPU 蒙皮测试不是审美接受，软件渲染证据也不是用户硬件或 Web 性能通过。
