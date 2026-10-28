# 海底水蛇：XYZ 改版契约（2026-10-28）
旧平面版本仅历史：build/revisions/fruit-gummy-snake-planar-20261028.tar.gz。旧测试绿灯不证明新版。

## 规则接口
sim.gd 纯 RefCounted：start(seed:int)、set_controls(yaw:float,pitch:float,throttle:float)、tick(delta:float)、drain_events()->Array、snapshot()->Dictionary。
公开 head:Vector3、forward:Vector3、body:Array[Vector3]（头在索引0）、foods:Array[Dictionary]（id,kind,position:Vector3,expires）、alive/won/score/longest/elapsed/collected。控制范围[-1,1]；yaw正值右转，pitch正值上浮，throttle正值加速。
固定1/120s积分；非法/负delta忽略；正常有效delta全量累积，单帧最多1200步且保留backlog（无时间丢弃）；失焦明确暂停负责清输入。连续Vector3移动，无二维投影。Yaw最大1.55rad/s，pitch最大1.15rad/s且限制±75°，不能瞬间掉头。速度1.7..4.6m/s（S精细慢游1.7，松开3.9，W加速4.6）；无后退/瞬反。
身体每0.55m弧长采样，保存折线路径，不按帧延迟；初始8节，最多120节，吃食物增加1/2节，120节完成本局。头半径0.30、身半径0.26。自碰撞忽略沿身体前2.2m近颈（索引<4，碰撞从body[4]→body[5]线段开始），其余用头移动线段对身体线段距离检测，不能只比XZ。边界X/Z±24,Y2..26；越界结束，提供3m预警。
食物6个：正常新局第一颗为非限时普通苹果（head+forward*4+UP*.4、intro=true），其余5个三轴随机；引导苹果仍走同一真实扫掠碰撞计分，不吸附，吃后不再出现引导标记。其余及后续补果半径0.5，三轴随机，边界内留2m、远离身体1.6m及其他食物2m；有限随机尝试后确定性三维候选扫描，无死循环。空间无不可穿越装饰，所有生成点可游达；不人为强制Y为常数。
水果积分/连续三种组合保持，西瓜12秒限时；新档固定user://games/fruit_gummy_snake/underwater_v2/profile.json，schema2，绝不读取或覆盖平面profile.json。

## Runtime / 摄像机 / 输入
第三人称透视追随，跟随身体朝向后上方，平滑相机位置与视线且不过海面/海底，保留俯仰深度线索。W/S加减速，A/D水平转向，Space上浮，C下潜；方向键上/下也可俯仰。松键立即清对应状态；暂停、失焦、退出清全部控制，回焦不自动继续。无鼠标捕获，不让长嘴/身体遮满画面。
深度读数、上/下提示、边界预警与目标深度差提示；水体浅雾不使用遮蔽一切的透明大平面。果实投影/光晕与海床地标提供空间深度，不用平面托盘伪装3D。
start(context)/exit_requested 保留；暂停/重开/关闭确认/音效清理沿用经过验证的生命周期但重新验收。

## 新验收
XYZ分别可位移；不同高度交叉不会误撞；相同XYZ头身接触会撞；近颈只豁免明确弧长；跨dt分割一致；转向速度上限；身体弧长间距；3D食物有限生成；边界/120节结束；新旧存档隔离；真实Viewport键按下松开/暂停/失焦/退出；最终原生截图与实际上下潜游玩验证。
