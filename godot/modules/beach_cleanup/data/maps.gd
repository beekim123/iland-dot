extends RefCounted
## Authored XZ metre layouts. Variants are bounded offsets, never random scatter.
const TYPES := ["bottle", "can", "wrapper", "sandal", "crate", "net"]
const VARIANT_COUNT := 3
const MAP_COUNT := 3

static func definition(map_id: int = 0, variant: int = 0) -> Dictionary:
	var index := clampi(map_id, 0, 2)
	var v := posmod(variant, VARIANT_COUNT)
	var sizes := [Vector2(32, 22), Vector2(34, 26), Vector2(40, 30)]
	var titles := ["月牙拾光", "曲岸回廊", "双湾环游"]
	var subtitles := ["沿月牙沙岸，找回第一片清澈", "绕过沙岩，清出返站近路", "两座驿站，串起双湾的生命"]
	var result := {"id": index, "variant": v, "title": titles[index], "subtitle": subtitles[index], "size": sizes[index], "start": Vector2(-12, 8), "heading": 0.0, "depots": [], "obstacles": [], "zones": [], "trash": []}
	var points: Array[Vector2] = []
	match index:
		0:
			result.depots = [{"id": "west", "pos": Vector2(-12,8), "radius": 2.0}]
			result.obstacles = [_rock("crescent_a", Rect2(-6,-2,12,3),1.2), _rock("crescent_b",Rect2(-3,1,6,3),0.8)]
			points.assign([Vector2(-13,-7),Vector2(-9,-7),Vector2(-5,-7),Vector2(-1,-7),Vector2(3,-7),Vector2(7,-7),Vector2(11,-7),Vector2(14,-4),Vector2(-13,-3),Vector2(-9,-3),Vector2(9,-3),Vector2(13,0),Vector2(-13,1),Vector2(-9,1),Vector2(-6,4),Vector2(6,4),Vector2(10,3),Vector2(13,4),Vector2(-9,7),Vector2(-5,8),Vector2(-1,8),Vector2(3,8),Vector2(7,8),Vector2(11,8)])
		1:
			result.start = Vector2(-14,10)
			result.depots = [{"id":"south", "pos":Vector2(-14,10),"radius":2.0}]
			result.obstacles = [_rock("upper_spine_west",Rect2(-10,-5,8.7,1.4),1.25),_rock("upper_spine_east",Rect2(1.3,-5,7.7,1.4),1.25),_rock("lower_spine",Rect2(-9,4,19,1.4),1.1),_rock("island",Rect2(11.5,-2,1,4),0.9)]
			for z in [-9.0,0.0,9.0]:
				for x in [-14.0,-11.0,-8.0,-5.0,-2.0,1.0,4.0,7.0,10.0,14.0]:
					points.append(Vector2(x,z))
		2:
			result.start = Vector2(-16,11)
			result.depots = [{"id":"west","pos":Vector2(-16,11),"radius":2.0},{"id":"east","pos":Vector2(16,-11),"radius":2.0}]
			result.obstacles = [_rock("west_loop_north",Rect2(-12,-5,7,3.7),1.4),_rock("west_loop_south",Rect2(-12,1.3,7,3.7),1.4),_rock("east_loop_north",Rect2(5,-5,7,3.7),1.4),_rock("east_loop_south",Rect2(5,1.3,7,3.7),1.4),_rock("waist_north",Rect2(-1,-12,2,7),0.8),_rock("waist_south",Rect2(-1,5,2,7),0.8)]
			for z in [-10.0,-7.0,7.0,10.0]:
				for x in [-16.0,-12.0,-8.0,-4.0,4.0,8.0,12.0,16.0]:
					points.append(Vector2(x,z))
			points.append_array([Vector2(-16,0),Vector2(-8.5,0),Vector2(8.5,0),Vector2(16,0)])
	# The crate in this narrow gate blocks a shortcut, never the outer bypass.
	if index == 1: points[4] = Vector2(0,-4.3)
	var half: Vector2 = result.size * 0.5
	if index == 0:
		result.zones = [{"id":"shell","title":"贝壳浅湾","rect":Rect2(-half,Vector2(11,22))},{"id":"dune","title":"月牙沙丘","rect":Rect2(-5,-11,10,22)},{"id":"seagrass","title":"海草沙洲","rect":Rect2(5,-11,11,22)}]
	elif index == 1:
		result.zones = [{"id":"tide","title":"潮汐北岸","rect":Rect2(-17,-13,34,8.7)},{"id":"corridor","title":"沙岩回廊","rect":Rect2(-17,-4.3,34,8.6)},{"id":"harbor","title":"归航南湾","rect":Rect2(-17,4.3,34,8.7)}]
	else:
		result.zones = [{"id":"northwest","title":"西湾鸟栖","rect":Rect2(-20,-15,20,15)},{"id":"northeast","title":"东湾海草","rect":Rect2(0,-15,20,15)},{"id":"southwest","title":"贝壳摇篮","rect":Rect2(-20,0,20,15)},{"id":"southeast","title":"日落蟹滩","rect":Rect2(0,0,20,15)}]
	var bulky: Array = [[4,17],[4,12,21,28],[4,13,20,29,33,34]][index]
	for i in points.size():
		var p: Vector2 = points[i] + [Vector2.ZERO,Vector2(0.25,0.25),Vector2(-0.25,-0.25)][v]
		var kind: String = TYPES[i % 4]
		if bulky.has(i): kind = "crate" if bulky.find(i) % 2 == 0 else "net"
		var zone_id: String = result.zones.back().id
		for zone: Dictionary in result.zones:
			if zone.rect.has_point(p): zone_id = zone.id; break
		result.trash.append({"id":"m%d_t%02d" % [index,i], "type":kind,"cost":3 if kind in ["crate","net"] else 1,"pos":p,"zone":zone_id,"blocks":kind in ["crate","net"]})
	return result

static func _rock(id: String, rect: Rect2, height: float) -> Dictionary:
	return {"id":id,"rect":rect,"height":height,"kind":"sandstone"}
