extends Node
## Original score playback; no dependence on a host audio bus or global settings.
const ROOT := "res://modules/tide_gulp/audio/"
const EVENTS := ["swallow", "growth", "dash", "warning", "tide", "death", "button"]
var enabled := true
var paused := false
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _voice_index := 0
var _last_play: Dictionary = {}
var _music_fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.name = "PaperSeaMusic"
	add_child(_music)
	var stream := load(ROOT + "music_loop.wav") as AudioStreamWAV
	if stream:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		_music.stream = stream
	_music.volume_db = -9.0
	for event in EVENTS:
		_streams[event] = load(ROOT + event + ".wav")
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.name = "WaterNote%d" % i
		voice.volume_db = -5.0
		add_child(voice)
		_voices.append(voice)
	_sync_music()

func play(event: String) -> void:
	if not enabled or paused or not _streams.has(event) or _voices.is_empty(): return
	var now := Time.get_ticks_msec()
	var gap := 1300 if event == "warning" else 95 if event == "swallow" else 60
	if now - int(_last_play.get(event, -10000)) < gap: return
	_last_play[event] = now
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stop()
	voice.stream = _streams[event]
	voice.pitch_scale = 1.0
	voice.play()

func set_paused(value: bool) -> void:
	paused = value
	if paused:
		for voice in _voices: voice.stop()
	_sync_music()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for voice in _voices: voice.stop()
	_sync_music()

func _sync_music() -> void:
	if not is_instance_valid(_music): return
	if is_instance_valid(_music_fade): _music_fade.kill()
	if not enabled or paused:
		_music.stream_paused = true
		return
	if not _music.playing:
		_music.play()
	_music.stream_paused = false
	_music.volume_db = -30.0
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -9.0, .4)

func stop_all() -> void:
	if is_instance_valid(_music_fade): _music_fade.kill()
	if is_instance_valid(_music): _music.stop()
	for voice in _voices: voice.stop()

func _exit_tree() -> void:
	stop_all()
	if is_instance_valid(_music): _music.stream = null
	for voice in _voices: voice.stream = null
	_streams.clear()

func get_debug_state() -> Dictionary:
	return {"enabled":enabled, "paused":paused, "music_playing":is_instance_valid(_music) and _music.playing, "music_paused":is_instance_valid(_music) and _music.stream_paused, "voice_count":_voices.size()}
