# 绒芽争园 · 双游戏与独立 Web 包验收

> **已被后续需求取代，未发布。** 2026-10-27 05:59 UTC 用户明确否定俯视镜头，要求第三人称追随/肩后效果。本记录与两份 ZIP 仅是旧俯视版的内部历史验证，不代表用户认可或最终交付；必须等镜头重做后重新导出、验收和授权发布。

日期：2026-10-27。输入为冻结的 **VISUAL_REV3**，Git 基线为 `e7d923545e9e5ec2b8216738b60022a5e2d83632`；导出早于最终提交，包内 `sourceCommit` 仅表示基线，**`source-manifest.json` 的逐文件哈希才是实际导出输入**。此记录将导出、原生挂载 PCK 与真实浏览器游玩严格区分。

## 构建与官方模板

- 使用官方 Godot **4.7.2 stable official ed1daf0bf** Linux x86_64。引擎原始发布 ZIP 已按官方 `SHA512-SUMS.txt` 校验；包内另记实际引擎 SHA-256。
- 从官方 `godotengine/godot-builds` 的 `4.7.2-stable` 发布 TPZ 通过 HTTP Range 提取 `templates/web_nothreads_release.zip`。
- 模板 10,245,903 字节，SHA-512 与仓库原有固定值完全一致：`33a52b6d9b1ce32d3683caaa3ea4b997a3f84c76a92a2e4a98a115b46da55d887854c9ef49bbf3b45b9629938110837978132c3a8cda26d278eb020bd6a9b8ea`。没有更改预期哈希以放行下载。仅验证提取成员；未声称下载或校验整个 1.28 GB TPZ。
- `tools/web/export.py` 只在 `build/web/staging-*` 副本启用 Web Stream playback 与 ETC2/ASTC 导入，不改桌面设置。单线程，无需 COOP/COEP。字体许可、来源及完整 Godot/第三方通知随包保留。
- 全岛 Web shell/README 已更新：粉色门为软糖爆爆岛，青色门为绒芽争园，紫色门保持未开放。右键是在己方花毯种花苞，不是投掷手榴弹。

复现全岛包：按 `tools/web/BUILD.md` 设置 `GODOT_BIN` 与 `GODOT_WEB_TEMPLATE`，运行 `python3 tools/web/export.py`。独立包先通过 `tools/extract_game.py bloom_skirmish <new-directory>` 抽离，再用相同单线程模板与 Web 设置导出，替换独立标题/操作说明；本次完整本地配方保存在忽略目录 `build/web/obsolete-topdown/standalone-source/`。可复现的是源输入、配置和构建步骤；没有声称不同机器/时间会产生逐字节相同的 ZIP。

## 实际输出

| 包 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `build/web/obsolete-topdown/sunny-shell-island-web.zip` | 27,509,252 | `7cccfbefde48739b0ab3855f14b1b91a67b44b6e95d50372dc05a527befa63a0` |
| `build/web/obsolete-topdown/bloom-skirmish-web.zip` | 11,796,941 | `774d570f5b4a50e5e3d95a60b8f85d4dbae94e79d050a4124fadfa4cf17c6259` |

独立包不含海岛或 Gummy；内含 `serve.py`、Mac `start.command`、准确操作说明和许可证。独立模式没有海岛宿主：房子图标会停止游戏并隐藏 HUD，刷新页面可重新开始；结算“再来一局”保留。Web 运行必须通过本机 HTTP，不能双击 HTML。

## 已通过：实际包结构、导入与生命周期

- 全岛包：**23 个 ZIP 条目、22 个 manifest 文件、152 项检查通过**。逐文件 SHA-256/大小与解压包完全相同，CRC 正确；无重复路径、绝对路径、`..`、反斜杠、源工程或导入缓存目录混入。208 个源输入逐一比对冻结工程，**0 处变化**。
- 独立包：**15 个 ZIP 条目、14 个 manifest 文件、104 项检查通过**，同样验证 CRC、路径、完整文件覆盖与哈希。51 个抽离输入中所有模块文件逐一匹配最终冻结源码。
- 两包的 HTML 均无 `$GODOT_` 占位符，仅引用本地 `index.js`；WASM magic/version 正确。使用各包内真实 `serve.py` Handler 建立临时本机 HTTP 服务，HTML/JS/WASM/PCK/两项 audio worklet 的 **6 个 HEAD 均为 200**；WASM MIME 为 `application/wasm`，PCK 为 `application/octet-stream`。
- **挂载实际全岛导出 PCK**：54 个场景、字体、音频、模型和 shader 资源通过 ResourceLoader/remap 加载，4 个 raw JSON 存在且可解析。6 个模型实例化并找到骨骼：蟹26、海豚10、鱼11、海鸥17、燕鸥17、龟15。
- 实际全岛 PCK 执行 **20 次双游戏交替往返**，包含第二道青色门启动 Bloom；`APP_LIFECYCLE_20_BOTH_GAMES: PASS`。宿主场景、镜头、HUD、音频暂停状态与无孤儿增长检查通过。
- **挂载实际独立 PCK**：17 个资源与2个raw JSON加载通过；确认没有宿主 `app/main.tscn` 或 Gummy 入口。执行20次带活动角色的暂停/恢复/重开/双次退出/释放，**560 项检查、0 失败、孤儿基线为0**。
- 上述 PCK 检查均以临时 XDG 用户数据目录运行，退出码0，无 `SCRIPT ERROR`、`Parse Error` 或引擎 `ERROR`。它们验证资源与原生包运行，不验证浏览器声音、WebGL shader 最终编译或 GPU 帧率。

证据在忽略目录 `build/web/obsolete-topdown/qa/`：`package-verification.json`、`pack-resources.log`、`pack-lifecycle.log`、`bloom-skirmish-web-verification.json`、`standalone-pack-resources.log`、`standalone-pack-lifecycle.log`。包内清单随 ZIP 交付，大包与临时 QA 不进入 Git。

## 真实浏览器：明确阻塞，未冒充通过

2026-10-27 **05:56 UTC**，实际云端 Chromium 打开同一全岛包 `http://127.0.0.1:8071/`。中文标题、两款游戏说明、页面布局正常；引擎能力检查明确显示 **`WebGL2 - Check web browser configuration and hardware support`**。页面友好说明需支持 WebGL 2 的桌面浏览器，没有假进度或无限加载。实际截图：`build/web/obsolete-topdown/qa/browser-webgl-block.png`。

执行环境服务与浏览器起初分属不同 localhost 命名空间；先观察到连接拒绝，随后由云桌面终端运行同一包的 `serve.py`，正常到达页面。没有修改浏览器安全/图形启动参数。

**未执行 WebGL 2 里的海岛、portal 转场、两款游戏输入/画面/声音与浏览器跨刷新存档测试**。独立包也没有浏览器实玩结果；两包均保留 `browserGameplayVerified: false`。需要支持 WebGL 2 的用户设备进一步验证。原生实际完整对局与图形证据另见 `bloom-native-gui.md`，不将它们算作浏览器通过。
