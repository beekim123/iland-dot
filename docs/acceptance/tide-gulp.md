# 逐潮小鱼：第三门、独立模块与最终验收

更新：**2026-10-27 10:42 UTC**。状态：**实现、单次完整聚合、原生主链路和真正抽离验收通过，进入源码发布候选；尚未凭本记录宣称远端已更新或 CI 通过。** 用户最终审美认可、浏览器 WebGL2、用户 Mac/GPU 性能和主观音频试听是不同阶段，不能从本报告推断。

## 唯一最终 clean 基线

- 时间：2026-10-27 **10:29:52Z → 10:42:07Z**，单次完整 `tools/test_all.sh` **exit 0**。
- 从只读（`chmod 444`）入口副本执行；唯一变换是把 `ROOT` 固定为既有仓库，避免运行中编辑脚本改变 Bash 文件偏移。原始入口与副本 SHA 均保留。
- 冻结 **496 个 `godot/` 与 `tools/` 源码/资源文件**；运行前后逐项 SHA256 相同，`changed.json` 为 `{}`。排除生成导入缓存、`.godot`、Python 缓存和未发布 `.blend1` 备份。
- **34 / 34 个必须命名阶段全部执行，无漏项或跳过**，另执行入口中的资源导入与 Python 资源/抽离策略检查。完整结果同时包含既有 Gummy 与 Bloom 回归，不是只跑新鱼模块。
- 原始完整目录：`/tmp/tide-final-clean-aggregate.hqboLU/`；隔离测试数据与各阶段日志：`/tmp/sunny-shell-qa.Mt93Sh/`。
- 仓库内持久证据：[完整 clean 日志](evidence/2026-10-27-tide-final/clean-aggregate.txt)、[结果](evidence/2026-10-27-tide-final/clean-result.txt)、[34阶段清单](evidence/2026-10-27-tide-final/required-stages.json)、[前快照](evidence/2026-10-27-tide-final/before.json)、[后快照](evidence/2026-10-27-tide-final/after.json)、[零差异](evidence/2026-10-27-tide-final/changed.json)、[入口记录](evidence/2026-10-27-tide-final/entrypoint.json)、[证据 SHA256](evidence/2026-10-27-tide-final/evidence-sha256.json)。

### 明确保留：第一轮失败，不计入最终通过

10:07:47Z → 10:17:42Z 的第一轮在执行期间被修改了聚合脚本，Bash 后续读取偏移发生变化，完成 Bloom 抽离后在第44行发生语法错误，**exit 2**。这是测试接线时机错误，不是单次完整通过；当轮还有获准修复 picker 导致的源码变化。其已过阶段不拼接冒充最终单次结果。

[第一轮完整日志](evidence/2026-10-27-tide-final/failed-first-attempt.txt)和[失败结果](evidence/2026-10-27-tide-final/failed-first-result.txt)原样保留。后续修复/冻结后从不可变入口**重新完整执行全部套件**，才得到上述唯一最终基线。

## 覆盖与实际结果

| 检查 | 最终结果 |
|---|---|
| 模块规则 | 3,488 项 / 0失败；80%食物和125%天敌临界、嘴/尾/侧身、同级推开、冲刺无无敌、警告与扑咬、35+5+20潮汐、六成长、连续几何与有界世界 |
| 独立规则与长局 | **6,350 checks PASS**；与模块作者测试分开编写的边界/分数/碰撞/生命周期 oracle |
| 纯合法觅食 | 600秒、7条真实生命、238次进食，最高**阶段3**；仅普通 command/tick 输入，死亡后正常重开，不赠分、不放大、不移鱼、不关天敌 |
| 单生命长局 | 另一条600秒连续合法 steering，留在作者设定的安全出生区；不重开/不修改鱼；最多60鱼、5区块，未主动清空事件队列且仅30条积压。**不是10分钟全海域激进狩猎证明** |
| 作者压力夹具 | 1,800秒受控区块循环、事件/鱼/内存有界；其中使用测试位置调度，明确**不冒充合法生存纪录** |
| Runtime | 八方向及24段转身实际投影嘴对齐回归、XY控制、键鼠切换、显式暂停/失焦、安全恢复、成长镜头与模型池通过 |
| 独立生命周期 | **466 checks PASS**；六次真实实例、合法进食、屏外危险提示钳制/最近两条上限、死亡不再变分变时、再来/回岛幂等、音频/HUD退场、无孤儿增长 |
| 独立保存 | **36 checks PASS**；坏JSON/未来schema/nonfinite数据保留、固定 `user://games/tide_gulp/profile.json`、原子写入、外来context不能改命名空间、Gummy/Bloom/hub存档字节不变 |
| 美术/资源 | 11个实际3D GLB、8骨Skin、可编辑Blender源；9种运行时鱼、6成长×16复合姿态；216个实际中文字符串字符覆盖、8本地音频波形与资源自包含检查通过 |
| UI/音频 | 多尺寸、按钮/点击穿透、焦点/暂停/退出/重开与音频生命周期通过；不由波形验证推断主观试听 |
| 宿主 | 三作交替24次入退，原岛实例/镜头/HUD/音轨暂停状态恢复，重复/跨游戏启动拒绝，孤儿节点不增长 |
| 既有两作 | Gummy独立309,597项及生命周期/保存；Bloom独立41,395,264项、12对完整比赛、透视/液体/HUD/动物/保存/关闭与实际抽离套件全部通过 |

独立测试及夹具边界说明见 [`tools/qa/tide_gulp/README.md`](../../tools/qa/tide_gulp/README.md)。所有磁盘测试采用临时 XDG 目录，不读写玩家实际记录。

## 第三门实机阻断的修复及验证

入口在实际 `ResourceLoader.load`、`PackedScene.instantiate`、自启并构造鱼模型通过后才开放；独立ID为 `tide_gulp`，标题「逐潮小鱼」，实际场景 `res://modules/tide_gulp/main.tscn`。紫色、旧门特效及岛屿美术不换。Hub字体仅给原Noto字面补缺字。第四 `cloud_hop` 仍是禁用占位，未实施鹈鹕游戏。

### 植被空包围盒错误挡住可见门

真实GUI发现可见紫门点不到。真实海岛相机×63候选×5视角×3门内高度的945条射线复现：旧picker有175次被空的植物 AABB 错误遮挡。修复采用AABB宽相 + **静态网格真实三角**窄相；有真实几何在前仍挡门，不做透墙优先级。

- 最新独立picker **3,941项 PASS**：945条真实相机射线，891条可见门真实press/release路由；其余54条为真实静态遮挡或保守动态代理，其中8条为动画代理。
- 骨骼鸟/鱼**不**用静态rest三角代替变形后形状；沿用原保守AABB。无门时所有物体原宽容点击策略不变。
- 单次拾取16384三角预算；本场景测试峰11340，缓存按当前pickables刷新失效。CPU测量不是渲染帧率或用户设备保证。

### 默认视角入口藏在树后／门互相重叠

不新增地形，从原63个带正确ground_patch的候选上验证默认真实camera的中心+4个面内样点，筛出58个可见位置，枚举84个同时满足世界间距与屏幕门框不重叠的三门组合，然后seed随机选择并洗牌三色位置。安全fallback是第一组**已经过几何验证**的组合，不是盲放点。

独立初始布局 **6,393项 PASS**：全部84组合、1000种seed、32次真正hub.setup、1740次真实press/release路由。转动视角后存在真实树叶遮挡属于正常3D遮挡，不保证从任意角度都能透墙点门。

## 真实原生主链路（主任务人工操作）

这些是主任务提供的实际Godot桌面操作/截图确认，不由headless推断；环境为Linux原生 Compatibility / llvmpipe，音频使用Dummy。

1. 独立原生游戏已经完成真实键鼠游动、合法45分、死亡、重开与暂停检查；九鱼真实画廊及最终水彩鱼体/背腹鳍/反向朝向经实机复核。
2. **10:41:01Z** 新截图确认通过新紫门的真实桌面点击已进入「逐潮小鱼」结算：该局0分 / 0:50，个人最佳45。不能把个人最佳45说成本局分数。
3. 原始OS事件trace：真实按下/释放 `event.position=(660.6102,274.6269)` 与viewport鼠标一致、`gui=NONE`、两次均命中第三门；相机投影第三门中心约 `(659.3676,279.8382)`。真实窗口1180×812，逻辑viewport1280×800，不能把物理屏幕像素直接当逻辑输入坐标。
4. **10:41:24Z** 结算页真实点击返回按钮后回到原岛，三门原位置和岛屿正常；trace命中 `TideGulp/.../Button_leave`。主任务确认主链路通过。

[原始native输入trace](evidence/2026-10-27-tide-final/native-hub-input-trace.txt)。本地实机艺术图路径包括 `build/previews/tide-watercolor-v3.png` 与 `build/previews/tide-gallery-final.png`；它们是本地/交付证据，不声称被仓库发布的忽略目录已包含。最终本地 `build/previews/tide-gameplay-final.mp4` / `tide-gameplay-final.gif` 为10秒、300帧固定30fps采样，真实引擎普通合法demo输入（seed42，从4秒录到14秒），不是人工操作、不是硬件实时30FPS证明；音频Dummy静音。主任务复核frame150/299为阶段2，实际分数1589→1749，录像日志无ERROR/leak；它与另一次人工45分分开记。媒体保留在本地/Library交付，不把build媒体加入Git。

## 最新真正独立导出

最终聚合创建的项目：**`/tmp/tide-extraction-qa.n7TtyF/standalone`**。

- 96个模块文件与源逐字节一致，含资源/源文件/许可证；不含app、hub、其他游戏或预导入缓存。
- 独立应用名称 `Tide Gulp Standalone`，保持模块内部res路径，应用数据目录与海岛不同。
- 全新Godot导入后，自启/规则3,488/runtime/保存/art/UI/audio及**同一**独立6,350 / 生命周期466 / 保存36全部通过。
- 复现：`GODOT_BIN=/path/to/Godot tools/qa/tide_gulp/extraction.sh`；焦点套件：`tools/qa/tide_gulp/run.sh`；完整聚合：`tools/test_all.sh`。

## 尚未声称的结果

- 未制作或验收新的鱼Web包、真实浏览器WebGL2或浏览器持久化。
- 未测试用户Mac/GPU、最低配置和真实设备性能；llvmpipe截图与CPU检查不等于这些平台表现。
- Dummy音频环境未做主观试听；音频文件格式、数字峰值/DC偏移/接缝和播放生命周期已验证。
- 技术与原生操作验收不等于用户最终美术认可。
- 本记录写入时源码发布仍由发布负责人处理；须单独核对远端commit/tree与实际CI状态。没有workflow/check不得写“CI通过”。
