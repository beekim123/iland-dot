extends Control
var kind:="shell"
var muted:=false
func _ready(): mouse_filter=MOUSE_FILTER_IGNORE
func _draw():
	var c:=size*.5
	var ink:=Color("36686b")
	match kind:
		"shell":
			var points:=PackedVector2Array([c+Vector2(0,13)])
			for i in 25:
				var a:=PI+i*PI/24
				points.append(c+Vector2(cos(a)*17,sin(a)*17))
			draw_colored_polygon(points,Color("f2b49a"))
			for x in [-12,-6,0,6,12]: draw_line(c+Vector2(0,11),c+Vector2(x,-10 if abs(x)<12 else -5),Color("fff2ce"),2,true)
		"view":
			draw_arc(c,14,0,TAU,32,ink,2.5,true)
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-10),c+Vector2(-5,6),c,c+Vector2(5,-6)]),ink)
		"beach":
			draw_arc(c+Vector2(0,2),13,PI,TAU,24,ink,2.5,true)
			draw_line(c+Vector2(-13,2),c+Vector2(13,2),ink,2.5,true)
			draw_line(c+Vector2(0,2),c+Vector2(0,14),ink,2.5,true)
			draw_line(c+Vector2(-8,14),c+Vector2(8,14),ink,2.5,true)
		"sound":
			draw_colored_polygon(PackedVector2Array([c+Vector2(-12,-4),c+Vector2(-6,-4),c+Vector2(1,-10),c+Vector2(1,10),c+Vector2(-6,4),c+Vector2(-12,4)]),ink)
			if muted:
				draw_line(c+Vector2(6,-5),c+Vector2(13,5),ink,2.5,true); draw_line(c+Vector2(6,5),c+Vector2(13,-5),ink,2.5,true)
			else: draw_arc(c+Vector2(1,0),12,-PI/3,PI/3,16,ink,2.5,true)
