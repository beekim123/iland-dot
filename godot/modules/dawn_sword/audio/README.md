# 原创合成音频

本模块音乐与音效由保留的 Python/NumPy 乐谱生成器原创合成，无外部音源/采样、未借用既有游戏曲目。乐谱、SHA、峰值、RMS及循环长度见 source/compose.py 与 manifest.json。源为AI辅助原创，不声称现场乐器录音。

24kHz单声道PCM16；数值检查无削波。主题按完整小节循环，合成尾音回绕。Godot适配器只使用本模块资源与自己的播放节点，不改全局音量总线。退出前 await shutdown() 再释放或退出，暂停冻结播放。

接口：start("theme"|"boss")、cue(name)、set_paused(bool)、set_volume(0..1)、await shutdown()。

音频主观试听未验收；Dummy驱动下通过初始化不能称为听过。生成脚本可复现并需NumPy，运行游戏无需Python。
