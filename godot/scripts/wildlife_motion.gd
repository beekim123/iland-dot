extends Node3D
## Only world trajectories are procedural. Mesh deformation uses authored bone clips.
const BoneActor = preload("res://scripts/bone_actor.gd")
var turtle: Node3D
var crab: Node3D
var gull: Node3D
var tern: Node3D
var dolphin: Node3D
var rigs: Array[Dictionary] = []
var setup_complete := false
func setup(actors: Array) -> void:
	if setup_complete: return
	turtle=actors[0]; crab=actors[1]; gull=actors[2]; tern=actors[3]; dolphin=actors[4]
	rigs.append(BoneActor.bind_actor(turtle,"Turtle_Swim_Loop_4s"))
	rigs.append(BoneActor.bind_actor(crab,"Crab_Scuttle"))
	rigs.append(BoneActor.bind_actor(gull,"Fly"))
	rigs.append(BoneActor.bind_actor(tern,"Fly"))
	rigs.append(BoneActor.bind_actor(dolphin,"Swim"))
	setup_complete = true
	apply_motion(0.0)

func apply_motion(t: float) -> void:
	if not setup_complete: return
	var swim_angle := t*0.28
	var velocity := Vector3(0.56*cos(swim_angle),0,-0.168*sin(swim_angle))
	turtle.position = Vector3(-4+2*sin(swim_angle),-0.28+0.035*sin(t*1.3),8+0.6*cos(swim_angle))
	turtle.rotation = Vector3(0.025*sin(t*1.5),atan2(velocity.x,velocity.z),0.02*sin(t*.8))
	BoneActor.sample(rigs[0],"Turtle_Swim_Loop_4s",t)
	var flight := t*0.32+0.4
	var flight_velocity := Vector3(-8.6*.32*sin(flight),.34*.62*cos(t*.62),7*.32*cos(flight))
	gull.position = Vector3(8.6*cos(flight),8+.34*sin(t*.62),1+7*sin(flight))
	gull.rotation = Vector3(-atan2(flight_velocity.y,Vector2(flight_velocity.x,flight_velocity.z).length()),atan2(flight_velocity.x,flight_velocity.z),-.12-.05*sin(flight))
	# Whole authored four-second cycles: eight seconds Fly, then four Glide.
	var clip := "Glide" if fposmod(t,12.0)>=8.0 else "Fly"
	BoneActor.sample(rigs[2],clip,t)
	var raw := sin(t*.48)
	var traverse := clampf(raw*1.5,-1,1)
	var walking := 1-smoothstep(.62,.70,abs(raw))
	crab.position = Vector3(-1.6+.45*traverse,.395,3+.12*cos(t*.48))
	crab.rotation = Vector3(0,.16+walking*.035*sin(t*.5),0)
	BoneActor.sample(rigs[1],"Crab_Scuttle",t)
	var a := t * 0.27 + 2.6
	var v := Vector3(-7.4 * .27 * sin(a), .18 * .7 * cos(t * .7), 6.1 * .27 * cos(a))
	tern.position = Vector3(7.4 * cos(a), 6.8 + .18 * sin(t * .7), 1 + 6.1 * sin(a))
	tern.rotation = Vector3(-atan2(v.y, Vector2(v.x,v.z).length()), atan2(v.x,v.z), -.10)
	BoneActor.sample(rigs[3], "Glide" if fposmod(t+4,16.0) >= 12.0 else "Fly", t+1.4)
	# Offshore oval, outside the beach contour; flukes remain vertically animated by bones.
	var d := t * .20
	var dv := Vector3(3.0 * .20 * cos(d), .055 * 1.1 * cos(t * 1.1), -1.15 * .20 * sin(d))
	dolphin.position = Vector3(5.5 + 3.0 * sin(d), -.62 + .055 * sin(t * 1.1), 10.6 + 1.15 * cos(d))
	dolphin.rotation = Vector3(-atan2(dv.y,Vector2(dv.x,dv.z).length()),atan2(dv.x,dv.z),.04*sin(d))
	BoneActor.sample(rigs[4],"Swim",t)
func update_motion(t:float) -> void:
	apply_motion(t)
