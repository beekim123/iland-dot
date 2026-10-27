# 原创「纸海小调」音频

`synthesize_audio.py` 使用确定性 NumPy 加法/滤波噪声合成，未使用外部录音、现成音乐或采样。旋律为轻柔长笛/拇指琴感的 3/4 拍，60 BPM，8 小节共 24 秒；循环跨界音符采用 wrap-add，底音也采用整周期频率，避免接缝突变。音乐和 SFX 均 44.1 kHz、16-bit stereo WAV。

事件：`swallow` 吞食 / `growth` 成长 / `dash` 冲刺 / `warning` 天敌预警 / `tide` 潮汐 / `death` 结束 / `button` 按钮。

```sh
python3 godot/modules/tide_gulp/audio/synthesize_audio.py
python3 godot/modules/tide_gulp/audio/validate_audio.py
```

`audio_manifest.json` 保留每份文件的 SHA-256、时长、峰值/RMS、削波数、接缝差值与生成信息；`validation.json` 为从 WAV 重新读取的验证记录。音乐原始峰值约 -16.9 dBFS，播放额外 -9 dB；SFX 额外 -5 dB，4 个有界复用 voice，吞食/预警防重叠节流。未使用宿主的全局 bus 或修改其他模块音量。

`tide_audio.gd.new()` 默认启用循环，API：`play(event)`, `set_paused(bool)`, `set_enabled(bool)`, `stop_all()`。暂停立即静音音乐并停止所有 SFX；恢复以 0.4 秒淡入；离场停止并释放流。声音开关可跨会话由 runtime 保存。按钮声音在运行/恢复时可播放，暂停状态不播任何声音。

这些记录是波形、接缝和生命周期**客观验证**，不是主观试听。当前云任务未宣称耳听效果通过，仍需可听环境最终试听。
