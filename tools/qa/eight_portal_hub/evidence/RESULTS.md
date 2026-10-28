# 八模块接入增量 · 独立真实UI验收

2026-10-28 05:28 UTC，Godot 4.7.2.stable.official.ed1daf0bf，隔离XDG：`/tmp/eight-independent.yTSPUN`。

**815项 PASS，实际退出码0**。无引擎错误/资源泄漏日志。仅QA目录修改，未改production、原root或推送。

覆盖：
- 八款真实可实例化ABI游戏池精确成员；随机选择四款、无重复、刷新更换成员、100轮固定seed全员观察覆盖（不是绝对公平保证）；海岛仍四门。
- 真目录第2页恰为水蛇+Monkey；各自真实Tab/Enter与鼠标进入，禁止重复启动；Escape暂停与实际HUD退出。水蛇使用二次确认按钮→leave_game；Monkey使用真实返回海岛按钮→request_exit，未假设leave_game。
- 两游戏各两次返回page2，filter/selection/scroll完整保留；确认press/release不穿透；岛上推荐/镜头保持、输入模式和自动关闭策略恢复、孤儿节点无增长。
- 水蛇新underwater_v2/schema_version2、Monkey自己profile/schema1真实保存；其他六模块profile哨兵与旧水蛇v1保持原字节；水蛇完成后保存的真实v2 profile加入保护，Monkey两次往返均未修改它。因此Monkey退出时旧七模块命名空间保持不变。
- 750个选定host、hub、八模块、QA源码文件前后SHA完全一致；原七模块583文件与seven-game-integration原字节一致。

发现并修复的真实反例：Monkey Enter按下退出时泄漏root._unhandled_input（松开才Button激活）；Escape按下打开暂停也未消费。保留`before-monkey-input-fix.log`。原owner修game.gd和HUD输入消费，hostowner按两文件SHA同步后复验，未放宽任何断言，额外补4条Escape keydown消费断言。

边界：目前真实键盘覆盖Enter，不据此声称KPEnter/Space所有组合均本套验证；水蛇Escape release仍可到Probe，但不触发岛/目录，测试严格要求pause按下与退出确认整组消费。未模拟通关、未重跑旧七游戏全部规则、未做真人Monkey全通关或GPU/Web性能。

分工：生产extractor Monkey fresh import/boot、作者只读套件和修复后独立13阶段由hostowner主增量执行，本独立套未重复执行相同模块规则。禁止test_rules_bonus_search写witness生成器。不能把此前旧SHA的13阶段结论直接算作新两文件运行时全部通过，主增量需提供新证据。

首条命令曾把--script误写为相对Godot project路径，启动报File not found；纠正绝对路径后测试正常，非生产缺陷。
