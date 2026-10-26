# V5 原生游戏 UI 重做（2026-10-26）

## 调研来源
- King 官方 Candy Crush 入口：https://www.king.com/game/candycrush （现跳转 https://www.candycrush.com/ ）
- King 发布的 App Store 产品/图库：https://apps.apple.com/us/app/candy-crush-saga/id553834731
- Nintendo 官方《集合啦！动物森友会》产品图库：https://www.nintendo.com/us/store/products/animal-crossing-new-horizons-switch/

以上用于题材/信息层级参考，不下载复制游戏图标、商标或整套布局。研究浏览器无法直接解码图库，随后从官方 App Store 页面提取 Apple CDN 截图，通过本地图片查看器实际检查 3 张：糖果封面、Explore the Candy World、Match Candy Combos。可见实机 HUD 将目标图标/数字压缩在顶端、糖果拥有高光/体积感，棋盘中心没有文字面板；底部宣传标语属于商店营销图，不照搬进游戏。Nintendo 图库图片仍未成功解码，不将页面文字当成视觉证据。项目实际旧截图已本地检查：`art/previews/v5/gummy_first_actual.png`、`art/previews/runtime/v4_01_island_overview.png`。

## 设计判断及实现（本项目原创方案）
1. **游戏空间优先**：旧版左上大文字矩形与底部长句像演示文稿。新 HUD 只在边缘放图标计数与小型波次徽章，中心专门留给 3D 俯视棋盘。
2. **题材即控件语言**：糖果用奶油白、软糖粉/薄荷绿/葡萄紫的圆润徽章，轻边缘高光及短阴影；不以更大的渐变面板代替设计。
3. **识别优先于阅读**：炸弹、十字范围、速度闪电、分数星星采用原创 CanvasDraw 图标，按钮用暂停/小屋轮廓，悬停补中文说明。
4. **反馈只在需要时出现**：常态无中央说明板；暂停/死亡显示精简浮层，波次变化只改波次徽章；首次操作提示 8 秒后淡出为低强调。
5. **真正游戏交互**：52 px 按钮，悬停增亮、按下缩放/阴影降低，禁用键盘焦点，避免 Space 被 UI 抢走。UI 不接管移动或游戏时钟。

## 组件契约
`godot/modules/gummy_bomber/ui/candy_hud.gd` extends CanvasLayer。
信号 `pause_requested`, `exit_requested`, `restart_requested`。
`update_state({wave,score,highscore,capacity,bombs_active,range,speed,paused,alive,next_wave})`。
字体为 Noto Sans CJK Bold SC 自包含子集；授权沿用模块 fonts/OFL 文档。
没有 hub 依赖；设计坐标 1200×750，等比缩放与 letterbox 居中适应 viewport。

## 验证要求
Headless 只验证编译/节点生命周期；父任务还需实际 Godot 截图确认布局、中文、棋盘边界和点击反馈。

## 海岛配套 HUD
`godot/hub/ui/island_hud.gd`：贝壳小标识+短标题，不再覆盖大块景色；右侧罗盘/阳伞/声音图标，短操作提示在 10 秒后降低强调；无底部通栏。采用独立海绿色/沙色，与糖果模块不互相依赖。signals: reset_requested, beach_requested, mute_requested, volume_changed(value)；set_muted / set_status。
组件 headless 创建/状态更新/销毁验证通过。字体 cmap 检查覆盖本地 UI 全部中文标点。

### 实际查看的官方截图链接
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/b7/20/5d/b7205d1b-eef5-68ae-3059-38bfba017dfb/b3ae2543-a3e9-4195-9ec8-ceacf068f596_479855_CCS_Rewording_Taglines_Screenshots_Nov_23_route4_sta_ios-XS_1242x2688_1.jpg/300x650bb.webp
- https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/4c/30/d9/4c30d918-4e95-791a-6888-9b9c5b87f0e1/e97cabb9-bbfa-4c51-98f9-2a0ed2c38288_479855_CCS_Rewording_Taglines_Screenshots_Nov_23_route4_sta_ios-XS_1242x2688_2.jpg/300x650bb.webp

官方图只在 /tmp 供研究查看，不进入项目素材或发布包。

## 实机回看
已检查父任务保存的 `art/previews/v5/gummy_ui_redesign_actual.png`：新图标/中文均正常、棋盘无遮挡、3D 俯视角保留。发现顶排徽章与棋盘顶部过近，后续将属性组/波次组上移 8 px，增加间隙。需要父任务最终捕获确认该微调。
