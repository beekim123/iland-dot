# 绒芽争园 · 第三人称/液体 Web 包验收

> **美术/UI已被新要求取代，禁止交付当前包。** 2026-10-27 06:29 UTC用户否定当前美术与UI风格，要求每个新项目独立重新设计。本文保留第三人称/液体功能和打包的实际测试事实，但不代表视觉被接受或最终版本；待新风格冻结后必须重导出并复验。当前源码未形成远端提交，main未更新。

日期：2026-10-27。本次从新的 **第三人称越肩 + 连续花蜜液体源码（VISUAL_REV4）** 重新导出，不复用旧俯视包。旧包未发布，已移到 `build/web/obsolete-topdown/`；旧结果只见[历史记录](bloom-web-topdown-history.md)。06:29 UTC新完整技术QA及原生回合已有通过证据，但随后用户拒绝现有美术/UI，当前仍禁止最终交付和发布。

导出时 Git 基线为 `e7d923545e9e5ec2b8216738b60022a5e2d83632`，尚未最终提交。因此包内 `sourceCommit` 仅表示基线，`sourceWorktreeStatus` 说明未提交输入；**`source-manifest.json` 逐文件哈希才是准确的导出源码身份**。不把旧提交SHA误称为本次新增内容已在远端。

## 官方工具与构建

- Godot **4.7.2.stable.official.ed1daf0bf**；原始Linux x86_64发布ZIP按官方 `SHA512-SUMS.txt` 校验。实际引擎SHA-256：`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`。
- 从官方 `godotengine/godot-builds` 4.7.2-stable TPZ以HTTP Range提取 `templates/web_nothreads_release.zip`，10,245,903字节。成员SHA-512与仓库原有固定值一致：`33a52b6d9b1ce32d3683caaa3ea4b997a3f84c76a92a2e4a98a115b46da55d887854c9ef49bbf3b45b9629938110837978132c3a8cda26d278eb020bd6a9b8ea`。未改哈希放行；未声称下载或校验整个1.28GB TPZ。
- `tools/web/export.py` 复制项目到 `build/web/staging-*` 后独立导入，Web使用Stream播放与ETC2/ASTC导入，不改桌面项目设置。单线程，无需COOP/COEP。包含新近景/液体效果脚本、384×288权威覆盖实现和已重做的shoot/hit/bloom三段湿润音效。
- 全岛包复现命令见 `tools/web/BUILD.md`。独立包先用 `tools/extract_game.py bloom_skirmish <新目录>`，再用相同模板/导出设置、独立标题与README；本次完整本地配方在 `build/web/standalone-source/`。构建输入与步骤可复现，不承诺跨机器/时间ZIP逐字节相同。

## 新包与校验和

| 包 | 字节数 | SHA-256 |
|---|---:|---|
| `build/web/sunny-shell-island-web.zip` | 27,563,842 | `bb904aff9060f38315da9cc0c1cd25f6d09158195bafe6738197f2c119f4d0b9` |
| `build/web/bloom-skirmish-web.zip` | 11,850,315 | `4b3d4e0e7b09c271f03f74b5b484876bb86f724fe84885bd3bcf467bb75098bb` |

全岛包含海岛、粉色软糖门、青色绒芽门及仍锁定的紫色门。独立包没有海岛或Gummy；房子图标会停止游戏并隐藏HUD，刷新可重新开始，结果页仍可再来一局。两包都有本机 `serve.py`、Mac `start.command`、操作说明、字体许可/来源与Godot第三方通知。Mac启动脚本的存在不表示已在用户Mac实测。

## 明确的第三人称操作说明

Web loader与README均已更新：进入绒芽后**主动点击捕获鼠标**，WASD/方向键相对镜头移动，鼠标环视/俯仰，中心准星瞄准；左键喷射有重力弧线的花蜜，右键己方地面种花苞，空格冲刺。Esc暂停并释放鼠标，点击继续或按Esc恢复；获取锁定的点击不射击。说明不再使用旧俯视点地瞄准。

浏览器只允许在真实输入事件中获取指针锁；实际Web捕获/释放是否正常不能由原生或静态代码证明。不能双击HTML，须通过HTTP与支持WebGL2的设备运行；无需降低浏览器安全设置。

## 已实际通过：包与原生PCK

- 全岛：**23个ZIP条目、22个manifest文件、153项结构/文件/HTTP检查通过**；**213个输入哈希**与冻结源码完全相同。
- 独立：**15个ZIP条目、14个manifest文件、104项检查通过**；**56个抽离输入**中的所有模块文件逐一匹配冻结原项目。
- 两包CRC正确，ZIP与解压目录逐字节一致，manifest完整覆盖文件并匹配大小/SHA-256；无重复路径、绝对路径、`..`、反斜杠或外部源工程/缓存目录混入。
- HTML无残留`$GODOT_`占位符，仅本地`index.js`引用；WASM magic/version正确。运行包内真实`serve.py`的Handler建立临时HTTP服务，HTML/JS/WASM/PCK/两项audio worklet共6个HEAD均200；WASM MIME=`application/wasm`，PCK MIME=`application/octet-stream`。
- 挂载**实际全岛导出PCK**：55个场景、模型、音频、字体和shader加载成功，4个raw JSON可解析；6个模型实例找到蟹26、海豚10、鱼11、海鸥17、燕鸥17、龟15骨骼。
- 实际全岛PCK执行20次交替Gummy/Bloom进入和回岛，包含青色门实际激活；`APP_LIFECYCLE_20_BOTH_GAMES: PASS`。验证同岛/镜头/HUD/音频状态和无孤儿增长。
- 挂载**实际独立PCK**：18个资源与2个raw JSON通过，确认不存在海岛宿主或Gummy入口。20次带活动角色的暂停/恢复/重开/双次退出/释放：**660项检查、0失败**；孤儿基线0，20轮释放后对象数均1555。
- 两种PCK测试均以隔离XDG用户数据目录执行；退出0，无SCRIPT ERROR、Parse Error或引擎ERROR。新音效由全新staging import导入，不沿用旧导入缓存。

证据位于 `build/web/qa/`：两份`*-verification.json`、`pack-resources.log`、`pack-lifecycle.log`、`standalone-pack-resources.log`、`standalone-pack-lifecycle.log`。所有大包、临时工程和测试数据被Git忽略；清单随ZIP交付。

## 浏览器边界

2026-10-27 **06:26 UTC**，真实云端Chromium重新加载**本次新全岛包** `http://127.0.0.1:8071/`。中文标题、两游戏入口说明、点击锁鼠/相机相对WASD/环视瞄准/Esc释放等新版文案实际显示；引擎检查仍明确报告 `WebGL2 - Check web browser configuration and hardware support`，友好失败页正常，无假进度或无限加载。截图为 `build/web/qa/browser-thirdperson-webgl-block.png`，不是旧包截图。由桌面终端运行本次包的 `serve.py` 后访问；未更改任何浏览器安全或图形参数。

无论原生PCK是否通过，**目前没有在WebGL2浏览器里运行新相机/鼠标捕获、动态液体、声音、portal转场或跨刷新存档的实测证据**。两包保留 `browserGameplayVerified: false`。真实原生回合与动态图形验收由主任务另记，不替代Web实际游玩。
