extends Node
## Module-local audio. Owns its players; never edits shared audio buses.
## Usage: add_child(instance), start(), cue(name), await shutdown() before exit.
signal retired

const CLIPS := ["theme", "click", "play_card", "attack", "damage", "draw", "turn", "guard", "death", "win", "lose", "error"]
const ALIASES := {"select": "click", "play": "play_card", "loss": "lose"}
const VOICE_COUNT := 4
# With the source peaks (music <= 0.54, cues <= 0.55), even four coincident
# effects plus music stay below 0 dBFS at maximum local volume.
const MUSIC_GAIN_DB := -12.0
const CUE_GAIN_DB := -9.0
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _volume := 0.65
var _paused := false
var _music_enabled := true
var _started := false
var _retiring := false
var _retired := false
var _base := ""
var _fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base = get_script().resource_path.get_base_dir()
	_music = AudioStreamPlayer.new()
	_music.name = "WoodlandMusic"
	add_child(_music)
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "WoodlandCue%d" % index
		add_child(voice)
		_voices.append(voice)
	_apply_volume()

func _load_clip(clip_name: String) -> AudioStreamWAV:
	if clip_name not in CLIPS: return null
	if _cache.has(clip_name): return _cache[clip_name] as AudioStreamWAV
	var path := _base.path_join(clip_name + ".wav")
	if not ResourceLoader.exists(path): return null
	var clip := load(path) as AudioStreamWAV
	if clip: _cache[clip_name] = clip
	return clip

func start(track: String = "theme") -> void:
	if _retiring or not is_instance_valid(_music) or track != "theme": return
	if _started: return
	var source := _load_clip("theme")
	if source == null: return
	var loop := source.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
	_music.stream = loop
	_started = true
	_music.play()
	_music.stream_paused = _paused or not _music_enabled
	_music.volume_db = -80.0
	_fade_music(_music_db(), 0.16)

func cue(clip_name: String) -> void:
	if _retiring or _paused or _volume <= 0.0: return
	var resolved: String = ALIASES.get(clip_name, clip_name)
	if resolved == "theme": return
	var clip := _load_clip(resolved)
	if clip == null: return
	# Reserve one voice for the result so a busy battle cannot swallow win/lose.
	var first := VOICE_COUNT - 1 if resolved in ["win", "lose"] else 0
	var last := VOICE_COUNT if first > 0 else VOICE_COUNT - 1
	# Never cut a playing transient mid-wave: bounded polyphony drops excess spam.
	for index in range(first, last):
		var voice := _voices[index]
		if not voice.playing:
			voice.stream = clip
			voice.play()
			return

func pause() -> void:
	set_paused(true)

func resume() -> void:
	set_paused(false)

func set_paused(value: bool) -> void:
	if _retiring: return
	_paused = value
	if is_instance_valid(_music): _music.stream_paused = value or not _music_enabled
	for voice in _voices: voice.stream_paused = value

func set_music_enabled(value: bool) -> void:
	if _retiring: return
	_music_enabled = value
	if is_instance_valid(_music): _music.stream_paused = _paused or not value

func set_volume(value: float) -> void:
	if _retiring: return
	_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func _music_db() -> float:
	return linear_to_db(maxf(_volume, 0.00001)) + MUSIC_GAIN_DB

func _apply_volume() -> void:
	if is_instance_valid(_music): _fade_music(_music_db(), 0.06)
	var db := linear_to_db(maxf(_volume, 0.00001)) + CUE_GAIN_DB
	for voice in _voices: voice.volume_db = db

func _fade_music(target_db: float, seconds: float) -> void:
	if _fade and _fade.is_valid(): _fade.kill()
	if not is_inside_tree():
		_music.volume_db = target_db
		return
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_music, "volume_db", target_db, seconds)

func shutdown() -> void:
	if _retired: return
	if _retiring:
		await retired
		return
	_retiring = true
	if _fade and _fade.is_valid(): _fade.kill()
	# A brief local fade avoids an exit click; always runs while the game is paused.
	if is_inside_tree():
		var release := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		if is_instance_valid(_music): release.tween_property(_music, "volume_db", -80.0, 0.08)
		for voice in _voices: release.tween_property(voice, "volume_db", -80.0, 0.08)
		await release.finished
	_stop_and_release()
	# Let queued audio-server commands drain before the scene owner frees this node.
	if is_inside_tree():
		await get_tree().create_timer(0.12, true, false, true).timeout
		await get_tree().process_frame
		await get_tree().process_frame
	_retired = true
	retired.emit()

func _stop_and_release() -> void:
	if is_instance_valid(_music):
		_music.stream_paused = false
		_music.stop()
		_music.stream = null
	for voice in _voices:
		if not is_instance_valid(voice): continue
		voice.stream_paused = false
		voice.stop()
		voice.stream = null
	_cache.clear()

func _exit_tree() -> void:
	if _fade and _fade.is_valid(): _fade.kill()
	_stop_and_release()
