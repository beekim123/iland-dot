# 完整无头回归

2026-10-26 08:30 UTC，Godot `4.7.2.stable.official.ed1daf0bf`。

命令：`tools/test_all.sh`。脚本使用新建临时 XDG 数据目录，绝不修改玩家正常存档；全部阶段退出码 0。

| 阶段 | 结果 |
|---|---|
| editor import | 通过 |
| tests/check_scene.gd | failures=[]，21个真骨骼角色与当前场景 |
| tests/check_app.gd | 20次进出、镜头/音频/HUD恢复、3门与颜色/shader核验通过 |
| hub/tests/test_hub.gd | 3门、禁用门、点击/拖动区分、声音上限与释放通过 |
| gummy_bomber/test_sim.gd | 规则断言通过 |
| gummy_bomber/test_runtime.gd | 场景运行检查通过 |
| gummy_bomber/test_save_schema.gd | 旧数据迁移、未来版本保护通过 |
| independent.gd | 独立规则审计通过 |
| lifecycle.gd | 20轮生命周期，孤儿节点增长0 |
| storage.gd | 注入存档与重开测试通过 |

没有 ERROR；唯一 WARNING 是 schema 测试主动写入版本2后，旧版拒绝覆盖的预期提示。该保护提示不能当成运行故障，也不能在报告中隐去。

本报告仅证明无头程序检查，不替代真实图形与性能验收。GUI 最终结果由主任务另行记录。
