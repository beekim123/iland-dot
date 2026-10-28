# 火山岛逃生 · Volcano Escape

独立 Godot **4.7.2** 完整小游戏。明亮黏土小岛、原创骨骼水獭；虚构卡通人工避险设施，**不是现实灾害求生指南**。

## 游玩

直接进入一局；WASD 相机相对移动，E 停步交互、进/出人工亭、求援灯、呼叫/登乘出口。气球持续按住 E 6 秒。即使保持 WASD，按下 E 也由权威规则先停步；保持原方向可持续操作，改变/松开方向或松开 E 会取消锁定。Runtime 传递原始移动意图，不自行吞掉 WASD。E 使用单个有界上升沿缓存，确保同帧按下/松开也能触发一次即时交互；短按不伪装为持续按住，不获得气球/呼叫的持续时间。暂停和新开局清除缓存。Esc 暂停，M 切换公开路况小地图（显示权威节点/道路/出口/亭状态），滚轮正交镜头 14–26（默认18）。暂停冻结权威世界时间、窗口、落石和持续交互；失去焦点自动暂停。成功或救援结算可重试/回岛，不设关卡选择门槛。

12节点/18道路/6人工亭/3出口/3可选灯，330秒上限，3生命。固定三套事件计划：落石至少4秒、封路20秒、亭失效30秒预告。亭不可无限躲赢；灯不是撤离门票。真实路面几何与权威可行走区来自 `data/island.gd`。

## 边界与独立运行

`main.tscn` 根节点 `start(context={})` / `exit_requested`；无宿主类依赖。宿主可以传固定身份 `game_id: volcano_escape, schema_version: 1`、可选 `save_service`（`load_game(id)` / `save_game(id,data)`）和 `quit_handler: Callable`。`save_root` 可省略或精确为 `user://games/volcano_escape/`（生产宿主契约）；它只是固定身份校验，不改变本模块路径。拒绝外来身份、版本或其他 `save_root`，不访问该上下文存档。正常离开恢复宿主鼠标/auto_accept_quit；原生窗口关闭保持 auto_accept_quit=false，直到退出树并完成0.5秒有界音频退休。

固定路径 `user://games/volcano_escape/profile.json`，只存完整成功/救援结果与设置，**不恢复半场灾害**。独立随机运行ID使结果重复提交幂等。未知版本、损坏数据保留原样并进入临时游玩。目录锁串行化合作写入者、加载字节基线检测外部变化、同目录临时文件原子替换、上一份有效数据 `.bak`。保留废弃锁而不擅自删除。宿主服务也进行基线比较；跨进程CAS/持久化原子性由服务实现负责。

相机独立 Environment，不注入全局 WorldEnvironment；单投影正交真实阴影（非默认四级联），默认18米局部跟随视野。渲染读取 sim snapshot；成功登乘只改变角色视觉位置，不修改权威状态。

```sh
GODOT=../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
XDG_DATA_HOME=/tmp/volcano-data XDG_CONFIG_HOME=/tmp/volcano-config XDG_CACHE_HOME=/tmp/volcano-cache \
  "$GODOT" --headless --path godot --editor --import
"$GODOT" --path godot res://modules/volcano_escape/main.tscn
```

首次独立抽离需复制整个模块至新的 `res://modules/volcano_escape/`，并导入资源；新工程主场景设为该 `main.tscn`。保留字体许可与音频来源说明。

## 验证与捕获

测试必须使用全新的隔离 XDG 目录，绝不能指向真实用户档案。

```sh
XDG_DATA_HOME=$(mktemp -d) XDG_CONFIG_HOME=/tmp/volcano-config XDG_CACHE_HOME=/tmp/volcano-cache \
  "$GODOT" --headless --path godot --script res://modules/volcano_escape/tests/test_runtime.gd
XDG_DATA_HOME=$(mktemp -d) XDG_CONFIG_HOME=/tmp/volcano-config XDG_CACHE_HOME=/tmp/volcano-cache \
  "$GODOT" --headless --path godot --script res://modules/volcano_escape/tests/test_storage.gd
```

`test_runtime.gd` 9个剧本×出口组合使用真实普通连续指令，检查每步位移上界，不赋值位置/时间/证人状态。另含输入保持/松开、暂停、新开局、命名空间、宿主离开、关闭幂等/退出树策略；存储测试检查幂等、损坏/未来版本、锁/外部写者、原子备份。

原生窗口捕获参数（`--`之后）：

- `--demo --demo-script=0|1|2 --demo-exit=boat|balloon|airship --demo-speed=1..60`
- `--capture=/absolute/frame.png --capture-after=2 --capture-phase=complete`
- `--record-dir=/absolute/frames --record-after=0 --record-frames=120 --record-fps=12`
- `--trace=/absolute/state.json`：只读快照、FPS、draw calls、存档状态与关闭状态。

Demo 不读取/写入真实存档，不瞬移、不快进权威时钟、不绕开6秒操作；加速只执行更多常规1/60秒步。低帧率保留完整elapsed accumulator，每帧最多240步但不丢弃时间；暂停/恢复清除待处理输入积压。只有原生窗口的 FPS 与截图有效，headless 不作为性能/画面验收。最终原生三出口人工验收与完整聚合由项目负责人按最终冻结版本执行。
