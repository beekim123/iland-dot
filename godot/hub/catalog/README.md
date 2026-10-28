# 海岛游玩手册

状态（2026-10-28）：旧不透明手册卡片被用户退回。用户随后确认“半透明背景、每款仍是传送门”方向并要求分页，现已实现此新方向；实机画面与最终视觉仍由用户验收。

`game_catalog.gd` 是独立 Control，由 app 的 CanvasLayer 承载，只有 app 有权启动模块或恢复海岛。

- `set_games(entries)`（别名 `setup`）：条目字段 id/title/description/enabled/available/scene_path/color/status_label。
- `open_catalog()` / `close_catalog()` 保留筛选、页码、滚动和选中游戏。每页固定6款；桌面3列，小屏2列但每页数不变。
- `current_page`零起，`get_page_count()`至少1，空池显示空态；上一页/下一页及左右/PageUp/PageDown切换，边界禁用。筛选改变回第1页，注册表变化页码自动clamp。
- 导航状态新增 `page`，旧状态缺该字段时按第1页处理。
- `get_navigation_state()` / `restore_navigation_state()` 可以跨实例保留导航。
- `set_portal_games(ids)` 标记当前岛上推荐；`set_status(text)` 用于无损展示加载失败。
- `game_requested(id)` / `close_requested` 由宿主监听。UI 在发送可能导致同步卸载的信号前消费当前输入，不在信号后访问 Viewport。
- 仅 enabled、available、scene_path 存在均成立的条目可启动；运行时实例化/模块接口校验仍由 registry/app负责。

## 视觉来源

四张封面是本项目真实 GLB 的离线棚拍，标注“模型预览”，不是游戏截图。软糖迷宫与尚未制作的新游戏封面为绘制的“主题图标”，不假装其模型已经实现。生成器 `tools/render_covers.py` 不改原模型。

字体是 Noto Sans CJK SC Regular 的子集，OFL 许可证随附，`tools/subset_font.py` 可复现。页面不创建实时 3D 子视口。每扇门使用一个轻量Canvas shader将静态模型预览裁成椭圆不规则裂隙，边缘流光和9个少量星点；未开放门降饱和且禁止启动。背景仅半透明遮罩，真实海岛仍由宿主渲染，目录不替换地形，不使用AI概念整图作为UI。

## 验证

`res://hub/catalog/preview.tscn` 为可视预览，不会真正启动游戏；正式运行通过 app。
`--headless --path godot --script res://hub/catalog/tests/test_catalog.gd` 验证四尺寸布局、筛选、禁用、导航保留及同步卸载。
