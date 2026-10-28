extends Control
## Catalogue illustration when no studio model portrait exists. Never labelled as gameplay.
var game_id := ""
var ink := Color("ff7db0")
func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw() -> void:
 var s := size
 var c := s * Vector2(.5,.48)
 var k := minf(s.x/340.0,s.y/180.0)
 draw_circle(c+Vector2(0,22)*k,61*k,Color(1,1,1,.22))
 if game_id == "gummy_bomber":
  for y in 3:
   for x in 5:
    var p := c+Vector2((x-2)*32,(y-1)*31)*k
    if (x+y)%3==0:
     draw_style_box(_box(Color("f9c6d6"),8),Rect2(p-Vector2(13,13)*k,Vector2(26,26)*k))
  draw_circle(c,23*k,Color("ff658f"))
  draw_circle(c+Vector2(-7,-4)*k,3*k,Color("293f50"));draw_circle(c+Vector2(7,-4)*k,3*k,Color("293f50"))
  draw_arc(c+Vector2(21,-18)*k,15*k,PI,PI*1.7,16,Color("fff1a2"),4*k,true)
 elif game_id == "fruit_gummy_snake":
  for i in 6:
   draw_circle(c+Vector2((i-2.5)*21,sin(i*.9)*17)*k,(15+i*.7)*k,Color("9bd58f"))
  var head := c+Vector2(52.5,sin(4.5)*17)*k
  draw_circle(head+Vector2(4,-5)*k,3*k,Color("254a43"))
  draw_circle(c+Vector2(-43,-40)*k,12*k,Color("ff8f8f"))
  draw_line(c+Vector2(-43,-50)*k,c+Vector2(-39,-58)*k,Color("477e55"),4*k,true)
 elif game_id == "dawn_sword":
  # Original sunrise-and-sword theme symbol, not a gameplay screenshot.
  draw_circle(c+Vector2(0,-15)*k,38*k,Color("f6c66d"))
  draw_colored_polygon(PackedVector2Array([c+Vector2(0,-62)*k,c+Vector2(12,-42)*k,c+Vector2(8,21)*k,c+Vector2(-8,21)*k,c+Vector2(-12,-42)*k]),Color("e4f5ef"))
  draw_line(c+Vector2(-26,23)*k,c+Vector2(26,23)*k,Color("b27c49"),8*k,true)
  draw_line(c+Vector2(0,24)*k,c+Vector2(0,53)*k,Color("56546a"),9*k,true)
 elif game_id == "apprentice_yokai_king":
  # Original horned yokai and oversized hammer theme symbol.
  draw_circle(c+Vector2(-13,5)*k,35*k,Color("9ad4bd"))
  for x in [-32,6]:
   draw_colored_polygon(PackedVector2Array([c+Vector2(x-8,-18)*k,c+Vector2(x,-48)*k,c+Vector2(x+10,-18)*k]),Color("fff0bb"))
  for x in [-25,-2]:draw_circle(c+Vector2(x,1)*k,4*k,Color("494354"))
  draw_line(c+Vector2(31,48)*k,c+Vector2(31,-28)*k,Color("855d60"),9*k,true)
  draw_style_box(_box(Color("ecacba"),7),Rect2(c+Vector2(2,-48)*k,Vector2(60,34)*k))
 else:
  # Pelican and bicycle symbol, intentionally an illustration rather than an absent new model.
  for x in [-37,37]: draw_arc(c+Vector2(x,24)*k,25*k,0,TAU,40,Color("32707b"),4*k,true)
  draw_polyline(PackedVector2Array([c+Vector2(-37,24)*k,c+Vector2(-8,-9)*k,c+Vector2(14,24)*k,c+Vector2(-37,24)*k,c+Vector2(37,24)*k,c+Vector2(15,-24)*k]),Color("f8e5b2"),5*k,true)
  draw_circle(c+Vector2(-3,-37)*k,18*k,Color("fff9e7"))
  draw_colored_polygon(PackedVector2Array([c+Vector2(10,-44)*k,c+Vector2(56,-34)*k,c+Vector2(8,-26)*k]),Color("edaf52"))
  draw_circle(c+Vector2(3,-42)*k,3*k,Color("254a43"))
func _box(color:Color,radius:int)->StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=color;box.set_corner_radius_all(radius);return box
