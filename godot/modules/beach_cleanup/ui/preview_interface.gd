extends SceneTree
## UI layout fixture only; not a native gameplay or art screenshot.
func _initialize() -> void: call_deferred('_build')
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color('#91b7a9')
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var hud = load('res://modules/beach_cleanup/ui/beach_hud.gd').new()
	root.add_child(hud)
	hud.update_state({'beach_name':'月牙湾 · 拾光海滩','cargo_used':9,'ground_remaining':11,'delivered':7,'zones_restored':1,'zones_total':3,'hint_text':'前方 8 米 · 轮胎占 3 格，清走它可打开捷径'})
	for arg in OS.get_cmdline_user_args():
		if arg == '--pause': hud.show_pause()
		if arg == '--completion': hud.show_completion({'distance':286,'unloads':4,'has_next':true})
