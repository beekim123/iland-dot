extends Node
## Eight fixed voices. No timers/tweens/callback capture survives scene retirement.
const CUES := ['pickup', 'clamp_lift', 'unload', 'ecology', 'complete', 'capacity', 'click']
const ROOT := 'res://modules/beach_cleanup/audio/'
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var music: AudioStreamPlayer
var cursor := 0
var retiring := false
var retirement_left := 0.18
var last_cue_ms: Dictionary = {}
var game_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for cue_name in CUES:
		streams[cue_name] = load(ROOT + cue_name + '.wav')
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -8.0
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	var stream := load(ROOT + 'shore_theme.wav') as AudioStreamWAV
	if stream:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	music.stream = stream
	music.volume_db = -13.0
	add_child(music)
	music.play()
	set_process(false)

func cue(event: String) -> void:
	if retiring or (game_paused and event != 'click') or not streams.has(event) or voices.is_empty(): return
	var now := Time.get_ticks_msec()
	var cooldown := 90 if event == 'pickup' else 180
	if now - int(last_cue_ms.get(event, -1000)) < cooldown: return
	last_cue_ms[event] = now
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stop()
	voice.stream = streams[event]
	voice.play()

func shutdown() -> void:
	if retiring: return
	retiring = true
	retirement_left = 0.18
	set_process(true)

func _process(delta: float) -> void:
	if not retiring: return
	retirement_left -= delta
	var gain := clampf(retirement_left / 0.18, 0.0, 1.0)
	if is_instance_valid(music): music.volume_db = -13.0 + linear_to_db(maxf(gain, 0.001))
	for voice in voices: voice.volume_db = -8.0 + linear_to_db(maxf(gain, 0.001))
	if retirement_left <= 0:
		for voice in voices:
			voice.stop()
			voice.stream = null
		if is_instance_valid(music):
			music.stop()
			music.stream = null
		streams.clear()
		queue_free()

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice): voice.stop()
	if is_instance_valid(music): music.stop()

func set_paused(value: bool) -> void:
	game_paused = value
	if is_instance_valid(music) and not retiring: music.volume_db = -20.0 if value else -13.0
	if value:
		for voice in voices: voice.stop()

func tick(_delta: float, _state: Dictionary = {}) -> void:
	# Playback is autonomous; only retirement uses ALWAYS _process.
	pass

func debug_state() -> Dictionary:
	var active := 0
	for voice in voices:
		if is_instance_valid(voice) and voice.playing: active += 1
	return {'voice_count': voices.size(), 'active_voices': active, 'retiring': retiring, 'paused': game_paused, 'music_playing': is_instance_valid(music) and music.playing}
