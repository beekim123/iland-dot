> 资源整理说明（2026-10-28）：本文保留当时的制作/验收记录；旧模型、预览和试听二进制可能已从当前树删除，作者导出为本地可再生产物。需要复现原始文件时请使用整理前提交 `7b16265a990a1e3c342315fb0ab0ce94e5774601`，当前运行成品以 active_asset_manifest 的 destination 为准。

# Sunny Shell v3 · Q 版海湾地形重建

## 造型结果

本次不是给旧平面小岛继续加运动，而是重新构造地形和码头。最终方向遵从用户最新要求：**Q 版、圆润、玩具／黏土质感，不做写实**。

- 单个连续实体网格：非对称海湾、连贯的暖沙坡面、起伏草丘；不再使用多层同心圆盘叠地形。
- 地表最高点约 2.82 m；整个轮廓约 22.29 × 14.10 m。底部延伸到水下，避免薄纸边缘。
- 前方留连续宽沙滩，草地与沙地通过顶点颜色相接；不是另加一个漂浮草坪片。
- 岩石为原创不规则圆角黏土块，使用大圆角和加权法线，没有球体散点堆，也没有写实岩层条纹。
- 左侧弯曲木码头：19 块独立圆角木板、弯梁、8 根支柱、粗绳与绳结。已删除细木纹以保持 Q 版简洁。
- 两组少量贝壳／卵石、小木牌构成有意安排的道具组，没有随机满地散点。
- 连续青绿海面采用缓慢的深浅渐变，不使用边界清晰的叠层水圈。

## 文件

| 文件 | 内容 |
|---|---|
| `art/v3/build_landscape.py` | 完整可复现源代码；也可不导入 Blender，直接读取地表 API |
| `art/v3/landscape.blend` | 可编辑模型、材质、灯光和预览相机 |
| `art/v3/landscape.glb` | 仅地形／海面／码头／道具，不含预览相机和灯光 |
| `art/v3/landscape_preview.png` | 1280 × 960 实际 Cycles 渲染 |
| `art/v3/landscape_contract.json` | 海岸 256 点、坐标约定、放置位置、对象名 |
| `art/v3/landscape_manifest.json` | 模型统计及当前推荐位置 |
| `art/v3/landscape_qa.json` | 几何与渲染设置检查结果 |

地形集合：`V3 LANDSCAPE • sculpted cove`。主地形对象：`Cove terrain • single continuous sculpted solid`。

**前两张工作过程图**保存在 `landscape_wip_01.png` 与 `landscape_wip_02.png`；它们不是最终成品，第一张保留了随后已修复的中央折痕，仅用于复现记录。

## 复现

在 `chibi-island` 根目录：

```bash
/usr/bin/blender -b --python art/v3/build_landscape.py
/usr/bin/blender -b art/v3/landscape.blend --python art/v3/check_landscape.py
```

本环境实际可执行文件为 `/usr/bin/blender`，版本 4.3.2。`-- --no-render` 可只重建 `.blend/.glb` 和合同数据。

预览：CPU Cycles，48 samples，1280 × 960，关闭降噪；正交相机约 31 m，位置 `(18,-24,19)`。没有使用图像生成或后期绘图伪造模型预览。

## 放置及海岸 API

```python
import sys
sys.path.insert(0, 'art/v3')
from build_landscape import terrain_height, grass_mask, shoreline_radius, island_boundary
z = terrain_height(x, y)
```

- Blender：XY 地面，Z 向上，前方为 Y 负方向。
- 海平面 `SEA_Z = -0.10`。到 Godot 的坐标变换为 `(x,z,-y)`。
- `terrain_height(x,y)`：与实际网格生成完全相同的标高函数。
- `grass_mask(x,y)`：0 是沙地，1 是草地。
- `island_boundary(theta)`：从 `(0,1.1)` 出发的实体网格外边界，部分位于水下。
- `shoreline_radius(theta)`：二分求解真实 `terrain_height == SEA_Z` 的静态岸线。
- JSON 的 `dry_shoreline_xy` 是静态水面交线；`land_boundary_xy` 不是干沙边界。

旧工程的椭圆浪花轮廓不适用于新版，必须使用新版海岸数据。演员脚底需要匹配局部地形，不能只照搬旧版原点高度。最终加入三个融入同一网格的柔和沙地落脚区：

| 角色 | XY 中心 | 地面 Z | 内部平缓半径 |
|---|---|---:|---:|
| 海龟 | `(-4.3,-3.0)` | 0.46 | 1.55 m |
| 螃蟹 | `(-1.6,-3.0)` | 0.36 | 0.70 m |
| 海鸥 | `(4.8,-2.7)` | 0.40 | 0.50 m |

落脚区以平滑权重混合原地形，并保护水边坡面；没有单独圆盘。植物仍按 API 逐个取高。

## 验证范围及限制

- 对实际 PNG 逐轮目视检查，修复过中央尖折、过窄沙滩、岩石横向切面条纹、细木纹噪声。
- 检查 GLB 的地形／海面均携带 `COLOR_0` 顶点色。
- 主地形检查封闭流形、退化面及非有限坐标。
- 海面上的轻微程序噪声凹凸是 Blender 预览专用；GLB 保留几何和顶点渐变，不声称程序节点在所有运行时完全一致。
- 本交付只负责静态建模，不改动旧版资源或 Godot 工程；整体植物、动物组装另行验证。
