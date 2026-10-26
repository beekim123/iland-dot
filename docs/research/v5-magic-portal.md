# V5 魔法裂隙原型：先独立验收，再接海岛

## 用户参考优先级

用户给出的手绘轮廓是竖向、不规则、悬空的能量入口，内部有流动线条。随后用户明确纠正：**地面是阴影，不是魔法阵**。因此本版不包含地面符文、发光圆盘、魔法阵、台座、实体圆环或镜框。用户参考图仅用于设计判断，默认不随公共仓库发布。

## 本次实际查阅

1. 原作者 Rody Muijrers 的 [Sketch #22 / Portal breakdown](https://realtimevfx.com/t/rodymuijrers-sketch-22/8663)。阅读其分层、UV扰动、边缘与视差说明，并下载其 Portal 03 动图、提取首帧亲自查看：实际是一片黑色入口、细白边和周围烟雾。只借鉴“能量边缘 + 内层深度 + 漂浮粒子”的结构，不复制其圆形外观、黑烟或写实气质。本文没有声称看完该页视频。
2. 原作者 Abel Sayadi 的 [Stylized Water Portal VFX UE5](https://abelsayadi.artstation.com/projects/qJ8kLN)。阅读作者对带状元素、动画节奏与分层的文字说明；本轮未直接播放嵌入视频，不作为已目视确认的效果证据。
3. [Godot spatial shader 官方参考](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html)：确认 unshaded、blend_add、depth_draw_never 等模式的语义。此链接是4.6版本文档；代码另用本地4.7.2官方引擎测试，不把文档版本冒称4.7.2。

## 原创实现

- `godot/hub/portal_v2/magic_rift.gd`：自包含视觉节点；configure(entry)、set_hovered、set_time 保留未来集成边界。
- `energy.gdshader`：多频平滑扰动的不规则边界；内部低频柔和云层、不同速度的带状能量，少量VIEW偏移制造视差。避免照片噪点和静态实体板。
- 多层边缘显式模拟柔光，不依赖后处理辉光；细粒子采用加法混合。
- `soft_shadow.gdshader`：柔边暗色椭圆投影，绝无发光地圈。
- 三个原型粉色、青绿、紫色；当前只展示美术，不更改实际小游戏入口或启用状态。
- 幻门全高约3米，离地约0.25米。只有薄片视觉，不等同真正跨空间渲染；后续若要可见目标场景，应单独增加SubViewport传送视窗。

## 真实运行与导出

```sh
GODOT=/workspace/scratch/e3e9ec015b32/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --path /workspace/scratch/e3e9ec015b32/chibi-island/godot res://hub/portal_v2/preview.tscn -- --portal-shots
"$GODOT" --path /workspace/scratch/e3e9ec015b32/chibi-island/godot res://hub/portal_v2/preview.tscn -- --portal-gif
```

必须使用可用图形桌面而非headless；代码遇到headless截图请求会明确失败。PNG：`art/previews/v5/portal_v2_three_colors.png`。动画：`art/previews/v5/portal_v2_frames/frame_0000.png`起共96帧，12fps、8秒。每帧显式时间步进，不让软件渲染速度影响动画时间。

验收状态：2026-10-26，本地4.7.2 headless场景运行3帧成功、无脚本错误；实际Compatibility渲染、图像审查由主agent图形桌面继续，未在headless检查时冒称视觉验收完成。

实际视觉复核更新（2026-10-26 08:18 UTC）：主agent使用图形桌面生成 `portal_v2_three_colors.png`；制作agent也亲自打开查看，确认三色不规则竖向能量幕、柔和发光边缘、内部流线与独立软阴影可见，无台座、地面魔法阵、矩形卡片边。此为待用户反馈的独立原型，不代表已获准替换海岛入口。

动态复核更新（08:20 UTC）：用户认可静态方向后，图形桌面完成96帧实机捕获。`portal_v2_motion.gif`（800px宽，约4.4MB）与`portal_v2_motion.mp4`（960px宽，H264，约262KB）均为12fps、8秒。制作agent目视复核首、中、末帧，检查轮廓、内部流线和粒子变化；首末像素均值差约2.4/255，非重复静帧。GIF循环播放但并非数学无缝循环。动画未改变已认可的视觉造型。
