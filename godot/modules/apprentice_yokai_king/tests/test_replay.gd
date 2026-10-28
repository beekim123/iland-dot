extends SceneTree
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
func _initialize():
	var args = OS.get_cmdline_user_args()
	assert(args.size() == 1,"Pass a trace JSONL produced by test_playthrough.gd trace=/absolute/path")
	var file = FileAccess.open(args[0],FileAccess.READ)
	assert(file != null)
	var header = JSON.parse_string(file.get_line())
	if header.has("model_sha256"): assert(header.model_sha256 == FileAccess.get_sha256("res://modules/apprentice_yokai_king/run_model.gd"),"Replay belongs to another rules revision")
	var m = Model.new(); m.reset(int(header.seed),header.mode,false)
	var frames = 0
	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty(): continue
		var input: Dictionary = JSON.parse_string(line)
		if input.has("choose"): assert(m.select_card(input.choose))
		elif input.has("result"):
			assert(m.phase == input.result and m.hp == input.hp and m.wave == input.wave and m.build.chosen_count == input.choices and absf(m.elapsed-input.elapsed)<0.00001)
			print("YOKAI exact recorded-input replay PASS ",m.phase," frames=",frames," hp=",m.hp," choices=",m.build.chosen_count)
			file.close(); quit(); return
		else:
			for key in ["move","aim"]:
				if input.has(key): input[key] = Vector2(input[key][0],input[key][1])
			m.advance(float(header.dt),input); frames += 1
	quit(1)
