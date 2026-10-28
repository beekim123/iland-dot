extends Node
## Bounded audio lifetime: a fixed pool, no deferred timers or WeakRef owners.
const ROOT := "res://modules/volcano_escape/audio/"
const CUES := ["alert", "interact", "rock", "shelter", "evac", "click", "beacon", "damage", "rescue"]
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var paused := false
var retired := false
var last_alert_ms := -1000
var streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in CUES: streams[name] = load(ROOT + name + ".wav")
	music = AudioStreamPlayer.new()
	music.stream = load(ROOT + "dispatch_loop.wav")
	if music.stream is AudioStreamWAV:
		music.stream = music.stream.duplicate()
		music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream.loop_begin = 0
		music.stream.loop_end = 1323000
	music.volume_db = -12
	add_child(music)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8
		add_child(player)
		voices.append(player)

func start_music() -> void:
	if not retired and is_instance_valid(music) and not music.playing:
		music.play()
		music.stream_paused = paused

func play_cue(name: String) -> void:
	if retired or paused or voices.is_empty() or not streams.has(name): return
	if name == "alert":
		var now := Time.get_ticks_msec()
		if now-last_alert_ms < 700: return
		last_alert_ms = now
	var player: AudioStreamPlayer = null
	for offset in voices.size():
		var candidate := voices[(cursor+offset)%voices.size()]
		if not candidate.playing:
			player = candidate
			cursor = (cursor+offset+1)%voices.size()
			break
	if player == null: return
	player.stream = streams[name]
	player.play()

func handle_events(events: Array) -> void:
	for event: Dictionary in events:
		match str(event.get("type","")):
			"road_warning", "shelter_warning", "rock_warning": play_cue("alert")
			"rock_impact": play_cue("rock")
			"shelter_entered", "shelter_left": play_cue("shelter")
			"airship_called": play_cue("interact")
			"beacon_lit": play_cue("beacon")
			"damage": play_cue("damage")
			"finished":
				if is_instance_valid(music): music.stop()
				play_cue("evac" if str(event.get("status",""))=="success" else "rescue")

func set_paused(value: bool) -> void:
	paused = value
	if is_instance_valid(music): music.stream_paused = value
	for player in voices: player.stream_paused = value

func shutdown() -> void:
	if retired: return
	retired = true
	if is_instance_valid(music): music.stream_paused = false; music.stop(); music.stream = null
	for player in voices:
		if is_instance_valid(player): player.stream_paused = false; player.stop(); player.stream = null
	streams.clear()
	if is_inside_tree() and not is_queued_for_deletion(): queue_free()

func _exit_tree() -> void:
	shutdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: shutdown()

func set_muted(value: bool) -> void:
	if is_instance_valid(music): music.volume_db = -80 if value else -12
	for player in voices: player.volume_db = -80 if value else -8
