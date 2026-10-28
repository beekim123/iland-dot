extends RefCounted
## Authored geometry, never random stretch. Rects are left-bottom, positive size.
const TEMPLATE_NAMES = ["fern_gully", "waterfall", "canopy", "ancient_grove"]
static func get_segment(seed_value: int, index: int) -> Dictionary:
	var template: int = posmod(index, 4)
	var platforms: Array = [
		{"id":"start", "rect":Rect2(-3,-2,5,2)},
		{"id":"rest", "rect":Rect2(11.5,-2,4.5,2)},
		{"id":"exit", "rect":Rect2(25.5,-2,6,2)}]
	var vines: Array = []
	for i in range(6):
		var x: float = 4.0 + float(i % 3) * 3.0 + float(i / 3) * 14.0
		var kind := "fixed"
		var extra_length := 0.15 * float(template) * float(i % 2)
		# Features live on optional upper-route vines, safe line stays fixed.
		vines.append({"id":"vine_%d" % i,"anchor":Vector2(x,5+extra_length),"length":3.0+extra_length,"type":kind,"warning_duration":1.0})
	if template == 1:
		vines.append({"id":"bonus_moving","anchor":Vector2(7,7),"length":2.0,"type":"moving","warning_duration":1.0})
	if template >= 2:
		vines.append({"id":"bonus_fragile","anchor":Vector2(21.5,7),"length":2.0,"type":"fragile","warning_duration":1.2})
	var fruit: Array = []
	for i in range(6):
		fruit.append({"id":"banana_%d" % i,"pos":Vector2(4.0 + float(i % 3)*3.0 + float(i/3)*14.0,2.1),"value":10})
	fruit.append({"id":"golden","pos":Vector2(7,4.8),"value":50})
	return {"id":TEMPLATE_NAMES[template],"template":template,"seed":seed_value,"bounds":Rect2(-5,-8,39,20),"spawn":Vector2(0,.32),"checkpoint_platform":"start","platforms":platforms,"vines":vines,"collectibles":fruit,"exit_rect":Rect2(26.5,0,5,3),"witness_id":"safe_route_v1","wind":0.35 if template == 3 else 0.0}
