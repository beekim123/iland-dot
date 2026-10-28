# 七模块增量独立验收 · 2026-10-28

Godot 4.7.2.stable.official.ed1daf0bf。仅staging QA；未改生产、原root或推送。

已通过：
- 真实host增量755检查：七可玩池随机四款无重复/每次替换/固定seed观察全七覆盖；真实第二页唯一水蛇按钮，鼠标及Tab/Enter启动；Esc暂停、实际退出与确认按钮，回到原page2/selection/filter/scroll；同步卸载后输入不穿透；mouse_mode与auto_accept_quit恢复；无孤儿增长。
- 实际新schema2写user://games/fruit_gummy_snake/underwater_v2；其他六游戏及旧水蛇v1哨兵全部原字节保留。
- 调用真实tools/extract_game.py导出全新项目，只有水蛇模块，fresh import成功；作者六套1424/483/26/52/32/6全部通过，已扫描日志无引擎错误/资源泄漏。
- 本轮抽离版独立underwater intro680、kinematics8582通过。
- 六既有模块532文件与原root完全一致；水蛇51文件原root冻结版/staging/本次独立抽离版/hostowner抽离版全部SHA相同。选定670源码文件前后SHA无变化。

未重复宣称完成：
- 本轮导航4seed首次240秒测试预算耗尽exit124（无失败断言），保留navigation-timeout240.log；延长900重跑后应root要求主动停止重复CPU工作，exit130。resumed_navigation.log不算PASS，其余8项未在这次独立runner重跑。新水蛇完整独立规则复用已冻结同SHA证据；hostowner完整增量继续执行。
- 原六模块本轮未全规则重跑；不称“全七旧游戏全部重跑”，不代替实际视觉/Web性能验收。

Harness说明：初轮/tmp/seven-independent.ninXek因运行时编辑runner修XDG引发bash读取偏移错误，非生产缺陷。当前run.sh每test240秒对导航不足，且!grep需换为显式if失败退出；已告owner，staging源冻结期间未改runner。上述成功项另显式grep验过，无错误。最终主聚合使用owner严格守卫与600秒预算。
