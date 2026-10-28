extends Node
const ROOT="res://modules/monkey_vine/audio/"
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer]=[]
var volume:=.65
func _ready() -> void:
	music=AudioStreamPlayer.new(); add_child(music)
	var stream=load(ROOT+"canopy_loop.wav") as AudioStreamWAV
	if stream:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0; stream.loop_end=stream.data.size()/2
		music.stream=stream
	for i in range(6):
		var voice:=AudioStreamPlayer.new(); add_child(voice); voices.append(voice)
	set_volume(volume)
func music_start() -> void:
	if music and not music.playing: music.play()
func set_volume(value: float) -> void:
	volume=clampf(value,0,1)
	if music: music.volume_db=linear_to_db(maxf(.0001,volume*.45))
	for voice in voices: voice.volume_db=linear_to_db(maxf(.0001,volume*.65))
func play_event(event: String) -> void:
	if event=="banana": event="collect"
	if event=="finish": event="segment_clear"
	if not event in ["grab","release","collect","land","checkpoint","fail","respawn","segment_clear","break_warning","vine_break"]: return
	for voice in voices:
		if not voice.playing:
			voice.stream=load(ROOT+event+".wav"); voice.play(); return
func set_paused(value: bool) -> void:
	if music: music.stream_paused=value
	for voice in voices: voice.stream_paused=value
func stop_all() -> void:
	if music: music.stop()
	for voice in voices: voice.stop()
