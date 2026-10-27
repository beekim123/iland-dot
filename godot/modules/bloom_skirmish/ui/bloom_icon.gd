extends Control
## Bloom's original monoline sports symbols. Team identity remains shape-readable.
var kind := "pod":
	set(value):
		kind = value
		queue_redraw()
var tint := Color("f2f5f5"):
	set(value):
		tint = value
		queue_redraw()
var active := true:
	set(value):
		active = value
		queue_redraw()
var is_player := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _line(points: Array, color: Color, width: float = 1.9) -> void:
	var path := PackedVector2Array()
	for p in points:
		path.append(size * .5 + p * minf(size.x, size.y) * .34)
	draw_polyline(path, color, width, true)

func _draw() -> void:
	var c := size * .5
	var r := minf(size.x, size.y) * .34
	var color := tint if active else Color("7a858f")
	match kind:
		"home":
			_line([Vector2(-1,-.1),Vector2(0,-.95),Vector2(1,-.1)],color)
			_line([Vector2(-.7,-.2),Vector2(-.7,.9),Vector2(-.15,.9),Vector2(-.15,.2),Vector2(.35,.2),Vector2(.35,.9),Vector2(.7,.9),Vector2(.7,-.2)],color)
		"pause":
			for x in [-.38,.38]: draw_line(c+Vector2(r*x,-r*.8),c+Vector2(r*x,r*.8),color,2.8,true)
		"sound", "mute":
			_line([Vector2(-1,-.3),Vector2(-.5,-.3),Vector2(.05,-.85),Vector2(.05,.85),Vector2(-.5,.3),Vector2(-1,.3),Vector2(-1,-.3)],color)
			if kind == "sound":
				draw_arc(c+Vector2(r*.1,0),r*.8,-PI*.3,PI*.3,16,color,1.8,true)
			else:
				_line([Vector2(.4,-.4),Vector2(1,.4)],color)
				_line([Vector2(.4,.4),Vector2(1,-.4)],color)
		"dash":
			_line([Vector2(-.25,-.85),Vector2(.85,0),Vector2(-.25,.85)],color,2.4)
			_line([Vector2(-.95,-.7),Vector2(-.15,0),Vector2(-.95,.7)],color,2.1)
		"heart", "health":
			_line([Vector2(-.35,-.95),Vector2(.35,-.95),Vector2(.35,-.35),Vector2(.95,-.35),Vector2(.95,.35),Vector2(.35,.35),Vector2(.35,.95),Vector2(-.35,.95),Vector2(-.35,.35),Vector2(-.95,.35),Vector2(-.95,-.35),Vector2(-.35,-.35),Vector2(-.35,-.95)],color)
		"water":
			var points := PackedVector2Array([c+Vector2(0,-r)])
			for i in 21:
				var a := float(i)/20.0*PI
				points.append(c+Vector2(cos(a)*r*.72,sin(a)*r*.72+r*.08))
			points.append(c+Vector2(0,-r))
			draw_polyline(points,color,1.9,true)
			draw_arc(c+Vector2(0,r*.08),r*.38,.2,PI*.5,10,color,1.7,true)
		"team_blue", "leaf":
			_line([Vector2(0,-1),Vector2(.7,0),Vector2(0,1),Vector2(-.7,0),Vector2(0,-1)],color)
			_line([Vector2(-.3,-.05),Vector2(0,.38),Vector2(.3,-.05)],color,1.8)
		"team_orange":
			_line([Vector2(-.6,-.7),Vector2(.6,-.7),Vector2(1,0),Vector2(.6,.7),Vector2(-.6,.7),Vector2(-1,0),Vector2(-.6,-.7)],color)
			_line([Vector2(-.35,-.23),Vector2(.35,-.23)],color,1.7)
			_line([Vector2(-.35,.23),Vector2(.35,.23)],color,1.7)
		"play":
			_line([Vector2(-.5,-.8),Vector2(.8,0),Vector2(-.5,.8),Vector2(-.5,-.8)],color)
		"replay":
			draw_arc(c,r*.8,-PI*.75,PI*.85,28,color,1.9,true)
			_line([Vector2(-.85,-.75),Vector2(-.85,-.05),Vector2(-.15,-.05)],color)
		_:
			# Hard-shell seed pod opening into three pointed petals, not a sticker flower.
			_line([Vector2(0,.9),Vector2(-.85,.05),Vector2(-.8,-.7),Vector2(-.2,-.3),Vector2(0,-1),Vector2(.2,-.3),Vector2(.8,-.7),Vector2(.85,.05),Vector2(0,.9)],color)
			_line([Vector2(0,.9),Vector2(0,-.35)],color,1.7)
			_line([Vector2(-.75,-.5),Vector2(0,.35),Vector2(.75,-.5)],color,1.7)
	if kind.begins_with("team_"):
		if not active: _line([Vector2(-.75,.85),Vector2(.75,-.85)],Color("dce1e1"),1.7)
		if is_player: draw_rect(Rect2(c+Vector2(-r*.35,r*1.25),Vector2(r*.7,2)),Color("f2f5f5"))
