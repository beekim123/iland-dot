extends Control
# Original resolution-independent candy pictograms. No external art dependencies.
var kind := "bomb"
var tint := Color("ec81aa")
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(36,36)
func _draw() -> void:
	var c := size * 0.5
	var ink := Color("624765")
	match kind:
		"bomb":
			draw_arc(c+Vector2(2,-10),7,PI,TAU,16,ink,3,true)
			draw_circle(c+Vector2(0,3),12,tint)
			draw_circle(c+Vector2(-4,-2),3,Color(1,1,1,.7))
			draw_line(c+Vector2(10,-14),c+Vector2(13,-17),Color("ffca60"),3,true)
		"range":
			draw_line(c-Vector2(12,0),c+Vector2(12,0),tint,8,true)
			draw_line(c-Vector2(0,12),c+Vector2(0,12),tint,8,true)
			draw_circle(c,5,Color("fff7d9"))
		"speed":
			draw_colored_polygon(PackedVector2Array([c+Vector2(3,-15),c+Vector2(-10,3),c+Vector2(-1,3),c+Vector2(-4,15),c+Vector2(12,-4),c+Vector2(3,-4)]),tint)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI/2+i*PI/5
				pts.append(c+Vector2(cos(a),sin(a))*(15 if i%2==0 else 7))
			draw_colored_polygon(pts,tint)
		"pause":
			for x in [-5,5]: draw_line(c+Vector2(x,-8),c+Vector2(x,8),ink,5,true)
		"home":
			draw_polyline(PackedVector2Array([c+Vector2(-12,0),c+Vector2(0,-11),c+Vector2(12,0)]),ink,4,true)
			draw_rect(Rect2(c+Vector2(-8,0),Vector2(16,12)),ink,false,3)
			draw_line(c+Vector2(0,12),c+Vector2(0,5),ink,4,true)
		"gummy":
			draw_circle(c+Vector2(-7,-9),6,tint); draw_circle(c+Vector2(7,-9),6,tint)
			draw_circle(c,14,tint)
			for x in [-5,5]: draw_circle(c+Vector2(x,-1),2,ink)
			draw_arc(c+Vector2(0,2),4,0,PI,12,ink,1.5,true)
			draw_circle(c+Vector2(-7,-7),3,Color(1,1,1,.5))
