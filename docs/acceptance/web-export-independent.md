# Web 导出独立验收

日期：2026-10-26。基础工程：`3cbee42b4032a7550d7d1024a5f34424f515a01e`。
本记录区分代码/资源检查、实际打包检查与浏览器实际游玩；不把桌面测试或静态检查当作浏览器游玩通过。

## 静态范围

- 主入口 `res://app/main.tscn`，渲染方法 GL Compatibility；Web 需要 WebGL 2。
- 水面和三种传送门 shader 无屏幕/深度纹理及导数依赖。最终 WebGL 着色器仍须在支持 WebGL 2 的浏览器验证。
- 传送门站点 JSON 使用 `FileAccess`，需要原样放进 PCK；模型、音频和模块场景含动态路径，导出采用 all_resources。
- 32×32 自绘 SVG 鼠标由代码创建，无遗漏的外置 cursor 图片。拖动阈值、HUD 输入阻断、进出模块的 cursor 恢复在现有代码中保留。
- 粉色传送门进入 Gummy Bomber；其余条目未启用。模块以自己的场景、资源、UI 和音频目录隔离。
- Gummy 分数仅写 `user://games/gummy_bomber/score.json`。Web 存储属于浏览器站点数据，不等同于用户磁盘可见文件；不同浏览器/站点/端口、隐私模式或清理站点数据可能无法续用。未将持久化代码存在当作跨刷新持久化已实测。
- 原始 GLB/WAV/OTF 由 Godot 导入格式与 remap 供运行时加载；没有直接读取原始二进制数据的运行时代码时，不要求在 Web 包中重复保存源资产。

## 导出与 ZIP

最终交付 ZIP（导出者确认未再改包，独立重跑哈希一致）：`sunny-shell-island-web.zip`，25,893,779 字节。
SHA-256：`81bfce1016b435ab2679fa812d75d65c88202746fe5bda63884f6d8203e54564`。

- 20 个 ZIP 条目 CRC 通过，无重复路径、绝对路径、`..`、反斜杠或源工程/缓存目录混入。
- build-manifest 的 19 个文件大小与 SHA-256 全部匹配；HTML 仅本地相对 `index.js`，无残留导出占位符、外部 CDN 或绝对引用；WASM magic/version 正确。
- 包内 `serve.py` 的实际 Handler 检测：HTML/JS/WASM/PCK/两项 audio worklet 六个 HEAD 均 200；WASM MIME `application/wasm`，PCK `application/octet-stream`。
- 使用官方 Godot 4.7.2 原生 headless 挂载**实际导出的 PCK**，32 个场景/字体/模型/音频/shader 资源加载全部成功；raw JSON 包含 63 个 portal sites。
- 6 个骨骼模型实例化通过：龟 15 骨，蟹 26，鱼 11，海鸥和燕鸥各 17（Fly/Glide），海豚 10（Swim）。字体、音乐和音效均经导入 remap 成功加载。
- PCK 主场景执行 120 帧，停止音频、释放场景并留出 0.25 秒音频回收后退出，无错误/警告。直接 `--quit-after` 快速退出可留下两首循环音频的清理警告；此处不把 native dummy-audio 快速退出当作 Web 音频验证。
- 导出者运行实际 PCK 的 20 次岛→Gummy→岛生命周期；独立读取 `build/web/pack-lifecycle.log`，结果 `APP_LIFECYCLE_20: PASS`。这是原生挂载 PCK 测试，不是浏览器游玩。
- 导出者额外 PCK 音频生命周期检查：岛上两首循环均有播放器，Gummy music 非空及 7 SFX，20 次往返通过；独立读取 `build/web/pack-audio-lifecycle.log`。此项只确认资源/播放器，不宣称主观听音通过。
- 单线程 template，Web Stream playback，8071 本机 HTTP 服务；不要求 COOP/COEP。Godot 与第三方 notices、字体 OFL/来源随包保留。

临时复测脚本与日志在 `build/web/qa/`（不作为游戏资源打包）。

## 浏览器

2026-10-26 08:56 UTC，真实云端 Chromium 打开 `http://127.0.0.1:8071/`：页面标题、中文说明与 loader 正常，引擎能力检测明确显示缺少 `WebGL2`。页面正确展示友好失败说明，没有无止境等待或假进度。

**浏览器实际海岛、portal 转场、小游戏输入/画面、声音及跨刷新存档未执行**，因为该云端浏览器不提供 WebGL 2。本记录没有改变浏览器安全设置，也没有以 native 测试代替 Web 游玩测试。需要在具备 WebGL 2 的桌面浏览器进一步验收。
