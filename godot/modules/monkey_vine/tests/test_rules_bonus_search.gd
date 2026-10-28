extends SceneTree
const Rules = preload("../rules/rules.gd")
func run_route(first_release: int, bonus_release: float, template: int) -> Dictionary:
	var r = Rules.new()
	r.configure(937,template)
	var held := false
	var inputs: Array = []
	var grabs: Array = []
	var golden := false
	var warned := false
	var bonus_grab_tick := -1
	var release_cooldown := 0
	for frame in range(1800):
		var s: Dictionary = r.snapshot()
		var next := held
		if s.grounded: next = not held and s.player_pos.x <25 and s.player_pos.x > (1.0 if s.player_pos.x<11 else 15.0)
		elif not s.vine_id.is_empty():
			var vine: Dictionary = {}
			for v in s.vines:
				if v.id==s.vine_id: vine=v
			if s.vine_id==("vine_0" if template==1 else "vine_3"):
				next = frame != first_release
			elif s.vine_id.begins_with("bonus"):
				next = (template==2 and frame-bonus_grab_tick<48) or not (s.player_pos.x > vine.anchor.x+bonus_release and s.player_vel.x>0)
			else: next = not (s.player_pos.x > vine.anchor.x+.65 and s.player_vel.x>0)
		else: next=true
		if held and not next and not s.grounded:release_cooldown=10
		if release_cooldown>0:
			next=false
			release_cooldown-=1
		var input := {"right":true,"left":false,"grab_held":next,"grab_pressed":next and not held,"grab_released":held and not next}
		held=next
		inputs.append(input)
		s=r.step(Rules.H,input)
		for e in s.events:
			if e.type=="grab":
				grabs.append(e.id)
				if e.id.begins_with("bonus"):bonus_grab_tick=frame
			if e.type=="collect" and e.id=="golden":golden=true
			if e.type=="break_warning":warned=true
			if e.type=="fail":return {}
		if s.segment != template:return {}
		if (s.checkpoint=="rest" if template==1 else s.phase=="segment_clear"):
			if ("bonus_moving" in grabs and golden if template==1 else "bonus_fragile" in grabs and warned):
				return {"seed":937,"segment":template,"inputs":inputs,"grabs":grabs,"golden":golden,"warned":warned,"first_release":first_release,"bonus_release":bonus_release,"finish":s.checkpoint,"air_release_gap_ticks":10}
	return {}
func _initialize() -> void:
	for template in [1,2]:
		var found := false
		for release in range(150 if template==1 else 330,300 if template==1 else 430,2):
			for threshold in [.3,.65,1.0,1.4]:
				var result := run_route(release,threshold,template)
				if not result.is_empty():
					print("FOUND template=",template," release=",release," threshold=",threshold," frames=",result.inputs.size()," grabs=",result.grabs," golden=",result.golden," warned=",result.warned)
					var file := FileAccess.open("res://modules/monkey_vine/data/bonus_witness_%d.json"%template,FileAccess.WRITE)
					file.store_string(JSON.stringify(result))
					found=true
					break
			if found:break
		print("FOUND=",found)
	quit()
