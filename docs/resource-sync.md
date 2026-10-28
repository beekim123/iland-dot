# 单副本运行资源与本地再生

当前清单的 9 个 GLB/WAV 只在 `godot/resources/` 保存入库成品。`docs/active_asset_manifest.json` 的 `source` 是作者工具生成的本地临时导出路径，不要求在 fresh clone 中存在；映射仍是唯一同步白名单，不扫描历史目录。可编辑 `.blend`、Python 制作脚本与必要上游源文件保留。

## 运行与校验（不需要 Blender）

```sh
python3 tools/sync_resources.py --check
# 在 Godot 中导入 godot/project.godot 后运行
```

`--check` 只读：逐项验证 runtime 对 `docs/resource_manifest.json` 的 SHA-256 和字节数。有本地导出但与 runtime 不同时也返回非零，明确提示尚未同步；不会自动接受导出或重写 hash。缺少本地导出正常；缺少/损坏 runtime 不正常。

## 编辑后明确同步

1. 用对应生成器或已编辑 Blender 源导出到清单中的原 `source` 路径；音频生成器是 `python3 audio/source/compose.py`（需要 NumPy）。本地导出被 Git ignore，但同步器仍可读。
2. 检查导出内容和制作 QA，然后明确运行 `python3 tools/sync_resources.py`（或 `tools/run.sh --sync`）。这会采用所有存在的清单内本地导出，输出旧/新 SHA-256；不要遗留不打算发布的旧导出。
3. 复核 runtime 与 `docs/resource_manifest.json` 的变更，运行 `--check`、相关 Godot/美术测试；提交 runtime、hash 锁及更新的可编辑源，不提交临时导出。同步器不会自动删除你的本地导出。

默认 sync 遇到缺源条目只能验证已有 runtime 与旧锁相符，绝不会以当前 runtime 重新生成 hash 来掩盖损坏。存在新源时可恢复缺失 runtime；GLB/WAV 的基本容器完整性先检查，但这不替代视觉、动画、音频 QA。新清单条目需明确同时建立经审核的锁记录；不自动纳入目录中新文件。

所有条目在写入前完整预检，校验失败没有任何文件变动。写入用同目录临时文件与原子替换，锁文件最后写；遇普通写入异常会回滚已替换 runtime。**这不是跨文件系统事务**：进程被杀、断电或回滚本身遭遇磁盘故障不能保证自动回滚，之后应以 `--check` 检测并从 Git 恢复。不支持两个写入同步进程并发运行。

## 作者依赖与复现范围

`art/v3/assemble_scene.py` 依赖 `landscape.blend`、`plants.blend`、`animals.blend`；turtle/crab/fish/gull/tern 生成器也依赖 `art/v3/animals.blend`，不能因目录版本旧而删除。鱼的 `art/rigged/fish/export_final.py` 还补上 frame 97 循环端点再导出，不能只用 `rig_fish.py` 代替最终步骤。保留最新版 rigged/v5 源与对应生成器。生成器运行会改写作者源/QA/预览，请在有备份的制作工作区运行。

重新生成需相应 Blender/NumPy 环境；**不承诺不同版本下再生字节与旧 GLB/WAV 完全一致**。锁定 hash 表示审核并提交的运行成品，不是跨环境可复现性证明。`tools/encode_video.sh` 直接读取正式 runtime 音频，不依赖作者临时 WAV。

## 无引擎边界测试

```sh
python3 -m unittest discover -s tools/qa -p test_sync_resources.py -v
```
