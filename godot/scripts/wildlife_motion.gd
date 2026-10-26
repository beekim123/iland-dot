extends Node3D
## Only world trajectories are procedural. Mesh deformation uses authored bone clips.
const BoneActor = preload("res://scripts/bone_actor.gd")
var turtle: Node3D
var crab: Node3D
var gull: Node3D
var rigs: Array[Dictionary] = []
var setup_complete := false
func setup(actors: Array) -> void:
	if setup_complete: return
	turtle=actors[0]; crab=actors[1]; gull=actors[2]
	rigs.append(BoneActor.bind_actor(turtle,"Turtle_Swim_Loop_4s"))
	rigs.append(BoneActor.bind_actor(crab,"Crab_Scuttle"))
	rigs.append(BoneActor.bind_actor(gull,"Fly"))
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
func update_motion(t:float) -> void:
	apply_motion(t)
