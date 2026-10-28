extends Node
## Local-only audio: no shared buses, input maps, or cross-module resources.
signal retired
var _retired := false
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _volume := 0.65
var _paused := false
var _retiring := false
var _cursor := 0
var _track := ""
var _base := ""

func _ready() -> void:
	_base = get_script().resource_path.get_base_dir()
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for index in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_apply_volume()

func _load_clip(name: String) -> AudioStream:
	if _cache.has(name): return _cache[name]
	if not name.is_valid_identifier(): return null
	var path := _base.path_join(name + ".wav")
	if not ResourceLoader.exists(path): return null
	var stream := load(path) as AudioStream
	_cache[name] = stream
	return stream

func start(track: String = "theme") -> void:
	if _retiring or _music == null: return
	if track not in ["theme", "boss"]: return
	if _track == track and _music.playing: return
	var source := _load_clip(track) as AudioStreamWAV
	if source == null: return
	var loop := source.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
	_music.stop()
	_music.stream = loop
	_track = track
	_music.play()
	_music.stream_paused = _paused

func cue(name: String) -> void:
	if _retiring or _paused or _voices.is_empty(): return
	var clip := _load_clip(name)
	if clip == null: return
	var voice := _voices[_cursor % _voices.size()]
	_cursor += 1
	voice.stop()
	voice.stream = clip
	voice.play()

func set_paused(value: bool) -> void:
	_paused = value
	if _music: _music.stream_paused = value
	for voice in _voices: voice.stream_paused = value

func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func _apply_volume() -> void:
	var db := linear_to_db(maxf(_volume, 0.00001))
	if _music: _music.volume_db = db - 10.0
	for voice in _voices: voice.volume_db = db - 5.0

func shutdown() -> void:
	if _retired: return
	if _retiring:
		await retired
		return
	_retiring = true
	if _music:
		_music.stream_paused = false
		_music.stop()
	for voice in _voices:
		voice.stream_paused = false
		voice.stop()
	# Scene owner must await this before freeing the scene or quitting the tree.
	await get_tree().create_timer(0.45, true).timeout
	if _music: _music.stream = null
	for voice in _voices: voice.stream = null
	_cache.clear()
	_retired = true
	retired.emit()
