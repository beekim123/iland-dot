# 云鲸便当铺

原创云鲸浮空餐铺经营 Demo。只借鉴空间组合、订单、强化与收支循环；故事、食材、界面和程序插画均原创。无需外部资源或其他模块。

## 玩什么

- 三天九单，3×3 便当格。客人限定 **恰好 5 或 6 份**，口味加减价。
- 12 种食材，米蔬/果奶/柠香海鲜正交相邻组合，中心蛋与三色横排。
- 点击食材再点格子；选择「收回模式」取回。全部摆放可免费调整。
- 每单可花 3 贝币买两份集市食材或跳过；结账扣食材成本。
- 每三单自动扣租金（42/62/78），负债失败；打烊可花 6 币永久强化一种食材售价 +2；第三天不负债获胜。
- 右侧实时列出收入、口味、食材成本与每项摆放奖励；没有倒计时。
- Esc 暂停；手册、自动存档、继续、重试和返回海岛。

## 运行与测试

Godot 4.7.2：从项目根目录运行：

```sh
godot --path godot res://modules/whale_bento/main.tscn
godot --headless --path godot --script res://modules/whale_bento/tests/test_rules.gd
godot --headless --path godot --script res://modules/whale_bento/tests/test_storage.gd
godot --headless --path godot --script res://modules/whale_bento/tests/test_runtime.gd
```

`rules.gd` 独立于 UI；测试覆盖邻接/换行/对角、组合叠加、口味、库存、无效操作、容量、收入租金、强化、终局、重试、JSON 与损坏档案、宿主退出及全部 UI 阶段。运行环境须允许写入 Godot user data；CI 可设置独立 HOME/XDG 目录。

接口：`start(context={})`、`signal exit_requested`、幂等 `request_exit()`。独立运行自动启动、退出结束进程；宿主模式发退出信号；系统关闭委托 `context.quit_handler`。档案始终固定在 `user://games/whale_bento/run.json`，不接受外部目录重定向。屏幕按 1280×800 等比缩放；鼠标和触摸点击均支持，**不提供拖拽操作**。

## 素材

食材、客人、云鲸、蒸汽全部以 Godot 图元绘制，无图片素材。`ui/bento-sans.otf` 为 Noto Sans CJK SC Regular 运行字符子集，SIL OFL 1.1，见 `ui/OFL.txt`。模块内字体为独立抽离所必需。没有网络、遥测或共享档案。
