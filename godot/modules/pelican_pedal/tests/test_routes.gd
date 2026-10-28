extends SceneTree
const Sim=preload("../sim.gd")
const Driver=preload("legal_driver.gd")
func _initialize() -> void:
	for job in 8:
		var sim=Sim.new();sim.start(job)
		var driver=Driver.new()
		for frame in 36000:
			sim.command(driver.command(sim));sim.tick(1.0/60);sim.drain_events()
			if sim.phase in ["complete","failed"]:break
		print("JOB ",job," phase=",sim.phase," delivered=",sim.delivered," pos=",sim.pos," time=",sim.elapsed," collision=",sim.collisions," integrity=",sim.integrity)
		if sim.phase!="complete":quit(1);return
	print("PELICAN 8 LEGAL DELIVERY ROUTES PASS");quit()
