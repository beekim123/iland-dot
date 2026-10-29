# 林间牌局音频

原创程序合成：24 秒、80 BPM 的柔和木琴与拨弦森林主题，以及 11 个短音效。
全部为单声道 16-bit PCM / 16 kHz；无第三方录音、采样或外部依赖。
这些原创音频随本项目使用、修改和分发，不要求另行署名。

`audio_director.gd` 仅管理自身播放器，不更改全局音频总线。
加入场景后调用 `start()`；事件：`click`、`play_card`、`attack`、`damage`、
`draw`、`turn`、`guard`、`death`、`win`、`lose`、`error`。
兼容别名：`select` / `play` / `loss`。
支持 `pause()` / `resume()`、`set_volume(0..1)`、`set_music_enabled(bool)`。
退出前必须 `await shutdown()`；重开游戏创建新实例。
