# 晴贝小岛 · 完整建模组装

完整源文件：`art/blender/sunny_shell_island.blend`；完整交换模型：`art/export/sunny_shell_island.glb`。独立的环境及三种动物源文件、GLB 均不覆盖，Godot 仍可单独加载与动画控制。

`art/scripts/assemble_island.py` 先打开原创环境，再导入原创海龟、螃蟹、海鸥的完整几何。三者 Blender 位置分别为 `(-2.2,-4.8,.70)`、`(2,-6.1,.68)`、`(5.5,-3.7,.64)`；整体比例 1.55、1.75、1.65；Z 轴旋转 -.40、.15、-.65 弧度。位置与 Godot 版本一致。

主场景有 93 个网格物体、40,275 个顶点、47,001 个多边形，0 个外部链接库。完整 GLB 不包含灯光或摄影机。所有模型材质为程序化设定的纯色材质，没有外部贴图依赖。

实际 Blender Cycles CPU 渲染：1280×960，40 samples；当前安装不支持 OpenImageDenoise，明确关闭降噪。使用 AgX Medium High Contrast、曝光 0。两张图片为真实模型渲染，不是概念图或 Godot 运行截图：

- `art/previews/island_complete.png`：小岛全景。
- `art/previews/island_complete_beach.png`：海滩动物近景。

主文件保留原始环境摄影机与柔光灯，另添加两个成品摄影机，默认打开全景。

复现：在项目根目录执行 `/usr/bin/blender -b -t 8 --python art/scripts/assemble_island.py`。

## 交付检查

已直接查看两张最终构图：全岛完整入镜，海滩三只动物均无遮挡；近景可辨认海龟背甲与笑脸、螃蟹双钳与眼柄、海鸥羽翼与黄色脚掌。GLB JSON 验证为 93 个 mesh、0 个 camera、无灯光扩展、无外部图片；二进制 buffer 内嵌，三只动物的父节点与独立结构保留。
