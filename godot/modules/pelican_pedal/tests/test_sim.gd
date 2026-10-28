extends SceneTree
const Sim=preload("../sim.gd")
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:push_error(label);quit(1)
func _initialize() -> void:
	var sim=Sim.new();sim.start()
	check(sim.phase=="pickup" and sim.pos==Vector2(0,29),"start")
	sim.command({"throttle":1.0});for i in 30:sim.tick(1.0/60)
	check(sim.pos.y<29 and sim.elapsed>.49,"normal forward motion")
	var snap=sim.snapshot();var restored=Sim.new();check(restored.restore(snap),"valid snapshot")
	check(restored.pos==sim.pos and restored.speed==0,"restore safely stopped")
	for dt in [NAN,INF,-1.0]:
		var before=sim.snapshot();sim.tick(dt);check(sim.snapshot()==before,"invalid dt ignored")
	var wrong=snap.duplicate(true);wrong.pos=[NAN,0];check(not restored.restore(wrong),"reject NaN")
	wrong=snap.duplicate(true);wrong.phase="complete";check(not restored.restore(wrong),"reject false completion")
	print("PELICAN SIM BASIC PASS ",checks);quit()
