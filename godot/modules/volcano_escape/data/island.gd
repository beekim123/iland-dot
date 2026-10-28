extends RefCounted
## All visible gameplay geometry is authored here; Vector2 coordinates are world XZ.
const SPEED := 2.8
const PLAYER_RADIUS := 0.33
const ROAD_WIDTH := 3.6
const HUB_RADIUS := 3.0
const NODES := {"A":Vector2(-18,-24),"B":Vector2(0,-24),"C":Vector2(18,-24),"D":Vector2(-18,-8),"E":Vector2(0,-8),"F":Vector2(18,-8),"G":Vector2(-18,8),"H":Vector2(0,8),"I":Vector2(18,8),"J":Vector2(-18,24),"K":Vector2(0,24),"L":Vector2(18,24)}
const EDGES := ["AB","BC","DE","EF","GH","HI","JK","KL","AD","DG","GJ","BE","EH","HK","CF","FI","IL","EI"]

static func build(script_id: int = 0) -> Dictionary:
	var s := posmod(script_id,3)
	var roads: Array = []
	var spare: Array = [["DG","AB","EI","JK","BC","KL"],["EI","KL","DG","BC","JK","AB"],["BC","JK","AB","DG","KL","EI"]][s]
	for id: String in EDGES:
		var index: int = spare.find(id)
		var closes := 115.0 + index * 25.0 if index >= 0 else -1.0
		roads.append({"id":id,"a":NODES[id[0]],"b":NODES[id[1]],"width":ROAD_WIDTH,"closes_at":closes,"warns_at":closes-20.0 if closes>0 else -1.0})
	var shelters: Array = []
	for i in 6:
		var node: String = ["A","D","F","G","I","L"][i]
		var expires := 165.0 + posmod(i+s,6)*23.0
		shelters.append({"id":"shelter_"+node,"node":node,"position":NODES[node],"expires_at":expires,"warns_at":expires-30.0})
	var exits := [
		{"id":"boat","node":"K","position":NODES.K,"windows":[Vector2(120,155),Vector2(240,280)]},
		{"id":"balloon","node":"C","position":NODES.C,"windows":[Vector2(135,175),Vector2(250,310)]},
		{"id":"airship","node":"J","position":NODES.J,"windows":[Vector2(145,185),Vector2(265,330)]}]
	var beacons: Array = []
	for node: String in ["B","H","L"]:
		beacons.append({"id":"beacon_"+node,"node":node,"position":NODES[node]+Vector2(1.5,0)})
	var rocks: Array = []
	# Fixed, avoidable rocks hit route centers, never the entire 3.6 m road.
	var rock_positions := [Vector2(0,0),Vector2(18,-16),Vector2(-18,-8),Vector2(0,16),Vector2(9,-8),Vector2(-18,8),Vector2(18,-8),Vector2(0,-16),Vector2(18,24)]
	for i in 18:
		var impact := 40.0+i*15.0+s*2.0
		rocks.append({"id":"rock_%02d"%i,"position":rock_positions[posmod(i+s,9)],"radius":0.95,"impact_at":impact,"warns_at":impact-4.0,"ends_at":impact+1.2})
	return {"nodes":NODES.duplicate(),"roads":roads,"shelters":shelters,"exits":exits,"beacons":beacons,"rocks":rocks,"spawn":NODES.E,"hub_radius":HUB_RADIUS,"road_width":ROAD_WIDTH,"player_radius":PLAYER_RADIUS,"speed":SPEED,"timeout":330.0,"script_id":s}

static func road_polygon(road: Dictionary) -> PackedVector2Array:
	var a: Vector2 = road.a
	var b: Vector2 = road.b
	var side := (b-a).normalized().orthogonal()*float(road.width)*0.5
	return PackedVector2Array([a+side,a-side,b-side,b+side])

static func hub_polygon(center: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in 48: polygon.append(center+Vector2.from_angle(TAU*i/48.0)*HUB_RADIUS)
	return polygon
