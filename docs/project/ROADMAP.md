# 项目路线图

源码基线：绒芽争园最终动物版已推送 [cc7bed6](https://github.com/beekim123/iland-dot/commit/cc7bed614ff010737ca0761c4bd86c960330382d)，远端 main/树/父链已核对；当时 CI checks、status 与 Actions runs 均为 0，未称 CI 通过。原生完整回合与真正抽离有证据，新 Web、用户设备性能和全部环境美术改版不冒称完成。

开发顺序的唯一详细清单为 **[开发队列](DEVELOPMENT-QUEUE.md)**：

| 顺序 / 模块 | 玩法与独立视觉 | 状态 |
|---|---|---|
| 1 `gummy_bomber` | 糖果格子爆破、无限波次、死亡重试/回岛 | 既有实现与验收保留，持续回归 |
| 2 `bloom_skirmish` | 第三人称动物 2v2 花露争地、180 秒、重开/回岛 | 动物版源码已发布，具体限制见任务板 |
| 3 `tide_gulp` | [逐潮小鱼](../design/tide-gulp.md)：3D 水彩绘本、XY 侧视吞食成长、预警避险与流潮 | 实现、原生/完整聚合/抽离验收完成；待本次源码发布核验与交付 |
| 4 `pelican_pedal` | [鹈鹕急送](../design/pelican-pedal.md)：3D 第一人称骑行配送、路线/负载/软迟到、风邮海堤镇 | 设计批准，下一款待开发；前款发布交付后自动开工 |
| 5 `beach_cleanup` | [拾光海滩](../design/beach-cleanup.md)：斜俯视沙雕微缩、容量清理/返站/生态回归 | 设计完成，排队未开发 |
| 6 `volcano_escape` | [火山岛逃生](../design/volcano-escape.md)：3/4 黏土岛、预警选路/暂避/三出口撤离 | 设计完成，排队未开发 |

第三款完成、验证并交付后自动开始第四款，再依次第五、第六，不重复问开工、不并行制作后续游戏；允许提前设计。详细门槛与进度沟通规则见开发队列。

`reef_memory` 已由第三款独立ID `tide_gulp` 替换，第三紫门已接通且真实往返验收；第四 `cloud_hop` 仍禁用，待实施 `pelican_pedal` 时再处理入口。本次发布候选包含第三作已验收源码，不是只改设计文档。`snake` 已由第二款替代，不建别名或复用存档。每款独立 `godot/modules/<id>/` 与 `user://games/<id>/`，不跨模块引用资源，视觉不自动继承前作。

具体事实与平台边界见[逐潮小鱼验收](../acceptance/tide-gulp.md)、[任务板](TASKBOARD.md)、[架构](ARCHITECTURE.md)。设计、实现、无头验证、原生实机、源码发布与平台交付分别记状态，不互相冒充。
