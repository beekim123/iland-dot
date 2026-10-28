extends Control
const EFFECT=preload("portal_cover.gdshader")
const Symbol=preload("catalog_cover.gd")
var game_id:=""
var portal_color:=Color("4fded3")
var portrait:Texture2D
var available:=true
var emphasized:=false
var clock:=0.0
var shader_material:ShaderMaterial
var symbol
func _ready()->void:
 mouse_filter=MOUSE_FILTER_IGNORE
 var surface:=ColorRect.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.mouse_filter=MOUSE_FILTER_IGNORE;add_child(surface)
 shader_material=ShaderMaterial.new();shader_material.shader=EFFECT;shader_material.set_shader_parameter("portal_color",portal_color);shader_material.set_shader_parameter("active",1.0 if available else .25);shader_material.set_shader_parameter("phase",float(hash(game_id)%100)*.1)
 shader_material.set_shader_parameter("has_portrait",portrait!=null)
 if portrait:shader_material.set_shader_parameter("portrait",portrait)
 surface.material=shader_material
 if not portrait:
  symbol=Symbol.new();symbol.game_id=game_id;symbol.ink=portal_color;symbol.modulate=Color(1,1,1,.8 if available else .5);add_child(symbol)
 resized.connect(_fit);_fit()
func _fit()->void:
 if shader_material:shader_material.set_shader_parameter("aspect",size.x/maxf(size.y,1))
 if symbol:
  symbol.size=Vector2(size.y*.50,size.y*.55);symbol.position=size*Vector2(.5,.49)-symbol.size*.5
 queue_redraw()
func set_emphasized(value:bool)->void:
 emphasized=value
 if shader_material:shader_material.set_shader_parameter("emphasis",1.0 if value else 0.0)
func _process(delta:float)->void:
 clock+=delta
 if is_visible_in_tree():queue_redraw()
func _draw()->void:
 var c:=size*Vector2(.5,.49)
 for i in 9:
  var a:float=float(i)*TAU/9.0+clock*.1+float(hash(game_id)%17)
  var p:=c+Vector2(cos(a)*size.y*.33,sin(a)*size.y*.46)
  var alpha:float=(.25+.55*pow(sin(clock*1.7+i*.9),2))*(1.0 if available else .3)
  var color:=portal_color.lightened(.5);color.a=alpha
  var r:float=1.0+float(i%3)*.5
  draw_circle(p,r,color)
  if i%3==0:
   draw_line(p-Vector2(4,0),p+Vector2(4,0),color,1.0,true);draw_line(p-Vector2(0,4),p+Vector2(0,4),color,1.0,true)
