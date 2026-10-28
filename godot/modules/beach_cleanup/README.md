# 拾光海滩 · Beach Cleanup

独立斜俯视 3D 沙雕微缩清理游戏。首次直接进入当前海滩，无关卡大厅。

## 操作与完整循环

- 镜头：16 米正交斜俯视平滑跟车，滚轮缩放 12–24 米；结算前后图另用固定全景相机。
- WASD：沿相机屏幕方向驾驶；按住鼠标左键：夹取车身前方扇形内的垃圾；锁定目标后车辆短暂停稳完成夹取，随后自动继续当前方向驾驶，松开鼠标立即取消停车。
- E：在卸货站卸下全部车载垃圾。12 格车厢，小件占 1 格、箱/网占 3 格；容量不足不吞物品。
- Esc：暂停/返回；暂停菜单提供继续、明确确认后的重玩与保存回岛。
- “找残留”：8 秒世界空间箭头标记真实最近残留，不指向已经装车或卸货的物品。
- 3 张独立布局，24/30/36 件，6 种外观，3/3/4 个生态分区；终图双卸货站。清理大件可打开捷径。
- 全部拾取且完成最后卸货才结算。明信片使用同一实际 3D 视口、相机和地图的前后截图，不是预画的完成图。下一海滩直接开局；重玩使用 3 个受约束变体。

## 入口、宿主隔离

`main.tscn` → `game.gd`，`start(context = {})`，`exit_requested`。

可接受宿主 `game_id`, `schema_version`, `save_service`, `quit_handler`；`save_root` 可省略，或必须精确为宿主规范值 `user://games/beach_cleanup/`。该字段仅用于核验，不参与拼接或覆盖存档路径。模块标识永远为 `beach_cleanup`，版本永远为 1，拒绝外来 namespace 与其他 save_root（包括缺少末尾斜杠、跨目录及非字符串值）。没有 autoload、宿主资源依赖或共享音频总线改动。全局鼠标模式与 native-close 策略在正常退出恢复；窗口关闭请求保持 `auto_accept_quit=false` 至真正退出，即使游戏节点已移除。音频以固定声部播放，退出时转移到树根，在有界淡出后自行回收。独立运行等待 0.5 秒音频退役后退出；注入的宿主 quit_handler 必须承担对应的最终 drain 等待。

`sim.gd` 唯一拥有运动、夹取、遮挡、容量、物品身份、卸货与分区规则；展示层不直接改动结果集合。夹取动画的临时克隆只用于举起/入篮视觉，不参与拾取与计数。

## 存档

固定 `user://games/beach_cleanup/profile.json`，临时文件 flush 后原子 rename，上一份合法内容留在 `profile.json.bak`。同局唯一 serial + 物品 ID 集合防止重载重复垃圾/结算。运动每两秒保存，拾取/卸货/恢复/完成/暂停/退出立即保存。

未来版本、损坏结构、非法物品集合及外部并发替换不覆写；显示中文提示，以临时游玩继续。初始真实视口图保存在同目录 `before_<serial>.png`；恢复时若缺失，按该局准确地图/变体重建初始视口，**不改动正在恢复的 simulation**。headless renderer 不产生或伪装像素截图。

## 测试与演示

从仓库根目录（Godot 4.7.2，兼容渲染器）：

```sh
GODOT=../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
# 给测试使用独立且可写的 XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME。
$GODOT --headless --path godot --script res://modules/beach_cleanup/tests/test_sim.gd
$GODOT --headless --path godot --script res://modules/beach_cleanup/tests/test_storage.gd
$GODOT --headless --path godot --script res://modules/beach_cleanup/tests/test_runtime.gd
$GODOT --path godot res://modules/beach_cleanup/main.tscn
```

自动演示只发送普通 command/tick，通过同样的前方夹取、碰撞、容量和卸货规则完成；没有直接授予结果或移除物品。`--demo` **不读取或写入用户进度**。

```sh
# 开局真实视口截图；trace 是只读运行状态。
$GODOT --path godot res://modules/beach_cleanup/main.tscn -- --demo --capture=/tmp/beach-start.png --capture-after=2 --trace=/tmp/beach-start.json
# 加速普通规则到完整结算，并截图实际明信片（不是跳过结算）。
$GODOT --path godot res://modules/beach_cleanup/main.tscn -- --demo --demo-map=2 --demo-speed=12 --capture-phase=complete --capture=/tmp/beach-complete.png --trace=/tmp/beach-complete.json
# 实际帧序列；建议普通速度观看举起/入篮，按 ffmpeg 等外部工具编码。
$GODOT --path godot res://modules/beach_cleanup/main.tscn -- --demo --record-dir=/tmp/beach-frames --record-fps=12 --record-frames=120 --record-after=0 --trace=/tmp/beach-motion.json
```

`--demo-map=0..2`, `--demo-variant=0..2`, `--demo-speed=1..60`。截图/序列参数指定输出工件位置，**不能改变固定游戏存档路径**。弱 llvmpipe 云桌面帧率不是验收完成声明；单方向有界阴影、低 draw 目标，真实表现需要单独测量。

## 独立抽离

复制整个 `modules/beach_cleanup` 至新 Godot 项目的同路径，将主场景设为 `res://modules/beach_cleanup/main.tscn`，兼容 renderer，1280×800 推荐窗口。GLB、trash wrapper/palette 修正脚本、字体、音频、shader 均必须包含；不要仅复制脚本或依赖本机 `.godot` 导入缓存。参见本模块 art/audio/ui 的来源和制作记录。
