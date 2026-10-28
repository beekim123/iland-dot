extends SceneTree
const Sim=preload("../sim.gd")
const Driver=preload("legal_driver.gd")
var checks:=0
var failed:=false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failed=true;printerr("FAIL ",label)
func _initialize() -> void:
	var sim=Sim.new();sim.start()
	# Ordinary riding toward the northern boundary must collide without escaping.
	for frame in 900:
		sim.command({"throttle":1.0});sim.tick(1.0/60)
		check(sim.Map.clear(sim.pos),"ordinary fast ride remains clear")
		if sim.phase=="failed":break
	check(sim.collisions>0 and sim.integrity<100,"collision damages cargo")
	var s=Sim.new();s.start()
	for frame in 150:s.command({"throttle":1.0});s.tick(1.0/60)
	var previous:Vector2=s.pos;var safe:Vector2=s.checkpoint
	for frame in 60:s.command({"reset":true,"brake":true});s.tick(1.0/60)
	check(s.resets==0,"one second R is insufficient")
	for frame in 20:s.command({"reset":true,"brake":true});s.tick(1.0/60)
	check(s.resets==1 and s.pos.distance_to(previous)>1,"hold reset returns to previously visited safe point")
	for frame in 180:s.command({"reset":true,"brake":true});s.tick(1.0/60)
	check(s.resets==1,"held reset cannot retrigger")
	var late=Sim.new();late.start()
	for frame in 8100:late.command({});late.tick(1.0/60)
	check(late.elapsed>late.deadline and late.phase=="pickup","deadline is not sudden loss")
	var driver=Driver.new()
	for frame in 12000:
		late.command(driver.command(late));late.tick(1.0/60)
		if late.phase=="complete":break
	check(late.phase=="complete" and late.score()==450,"late delivery still completes without fast bonus")
	var frozen=late.snapshot();for frame in 60:late.command({"throttle":1.0});late.tick(.1)
	check(late.snapshot()==frozen,"result cannot move or alter clock")
	print("PELICAN EDGE ",checks," checks; ","FAIL" if failed else "PASS");quit(1 if failed else 0)
