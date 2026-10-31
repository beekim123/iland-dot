extends Node2D
signal exit_requested
const Rules = preload("res://modules/whale_bento/rules.gd")
const FONT = preload("res://modules/whale_bento/ui/bento-sans.otf")
const CREAM=Color("fff8e8")
const INK=Color("494c49")
const JADE=Color("639f88")
const CORAL=Color("df8374")
const SAVE="user://games/whale_bento/run.json"
var model=Rules.new()
var started=false
var hosted=false
var exiting=false
var quit_handler:Callable
var screen="title"
var overlay=""
var selected=-1
var buttons:Array=[]
var time=0.0
var pulse_slot=-1
var pulse=0.0
var notice="先选食材，再点便当格。点击已放食材可收回。"
var resume_available=false
var saved_data:Dictionary={}
var previous_auto_quit=true

func _ready():
 get_viewport().size_changed.connect(_resize)
 _resize()
 call_deferred("_auto_start")

func _auto_start():
 if not started: start()

func start(context:Dictionary={}):
 if started: return
 started=true
 hosted=not context.is_empty() or not exit_requested.get_connections().is_empty()
 quit_handler=context.get("quit_handler",Callable())
 previous_auto_quit=get_tree().auto_accept_quit
 get_tree().auto_accept_quit=false
 model.reset()
 if FileAccess.file_exists(SAVE):
  var f=FileAccess.open(SAVE,FileAccess.READ)
  if f:
   var parsed=JSON.parse_string(f.get_as_text())
   if parsed is Dictionary:
    saved_data=parsed
    var probe=Rules.new()
    resume_available=probe.restore(parsed)
 queue_redraw()

func _resize():
 var view=get_viewport_rect().size
 var k=minf(view.x/1280.0,view.y/800.0)
 scale=Vector2(k,k); position=(view-Vector2(1280,800)*k)*0.5

func _process(delta):
 time+=delta; pulse=maxf(0,pulse-delta*3)
 queue_redraw()

func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  _save()
  if quit_handler.is_valid(): quit_handler.call()
  else: request_exit()

func _exit_tree():
 if is_inside_tree(): get_tree().auto_accept_quit=previous_auto_quit

func request_exit():
 if exiting: return
 exiting=true; _save()
 if is_inside_tree(): get_tree().auto_accept_quit=previous_auto_quit
 if hosted: exit_requested.emit()
 elif is_inside_tree(): get_tree().quit()

func _save():
 if screen!="game": return
 DirAccess.make_dir_recursive_absolute("user://games/whale_bento")
 var f=FileAccess.open(SAVE,FileAccess.WRITE)
 if f: f.store_string(JSON.stringify(model.snapshot()))

func _input(event):
 if exiting: return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  get_viewport().set_input_as_handled()
  if overlay!="": overlay=""
  elif screen=="game": overlay="pause"
  else: request_exit()
  return
 var pressed=false
 var point=Vector2.ZERO
 if event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  pressed=true; point=get_local_mouse_position()
 if event is InputEventScreenTouch and event.pressed:
  pressed=true; point=get_global_transform_with_canvas().affine_inverse()*event.position
 if pressed:
  for b in buttons:
   if b.rect.has_point(point):
    get_viewport().set_input_as_handled()
    b.action.call(); return

func _label(text:String,at:Vector2,size:int=22,color:Color=INK):
 draw_string(FONT,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _panel(rect:Rect2,color:Color=CREAM,radius:int=20):
 var style=StyleBoxFlat.new()
 style.bg_color=color; style.set_corner_radius_all(radius)
 style.shadow_color=Color(0.25,0.35,0.32,0.12); style.shadow_size=5; style.shadow_offset=Vector2(0,5)
 draw_style_box(style,rect)

func _button(rect:Rect2,text:String,action:Callable,color:Color=JADE,enabled:bool=true):
 _panel(rect,color if enabled else Color("b9c2b5"),14)
 var width=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
 _label(text,rect.position+Vector2((rect.size.x-width)/2,rect.size.y/2+8),22,Color.WHITE)
 if enabled: buttons.append({"rect":rect,"action":action})

func _draw():
 buttons=[]
 draw_rect(Rect2(-1500,-1500,4300,3800),Color("b9dfdb"))
 for i in 7:
  var p=Vector2(fposmod(i*233+time*9,1500)-100,70+(i%3)*65)
  _cloud(p,0.7,Color("eaf2df"))
 _whale(Vector2(1050,680+sin(time)*7),1.2)
 if screen=="title": _title()
 else: _game()
 if overlay!="": _overlay()

func _cloud(p:Vector2,k:float,color:Color):
 draw_circle(p,35*k,color); draw_circle(p+Vector2(36,-15)*k,46*k,color); draw_circle(p+Vector2(79,0)*k,33*k,color)

func _whale(p:Vector2,k:float):
 draw_set_transform(p,0,Vector2(k,k))
 draw_colored_polygon(PackedVector2Array([Vector2(95,0),Vector2(173,-50),Vector2(156,8),Vector2(186,37),Vector2(105,35)]),Color("729eaf"))
 draw_set_transform(p,0,Vector2(k*1.8,k))
 draw_circle(Vector2.ZERO,95,Color("91b9c1"))
 draw_set_transform(p,0,Vector2(k,k))
 draw_arc(Vector2(-44,5),30,0.1,2.5,24,Color("e6e6d3"),4)
 draw_circle(Vector2(-85,-18),6,INK); draw_circle(Vector2(-86,-20),2,Color.WHITE)
 draw_circle(Vector2(-100,2),12,Color("e7aba0"))
 draw_line(Vector2(-10,-91),Vector2(-13,-120-sin(time*2)*5),Color("e7f8ee"),6)
 draw_circle(Vector2(-25,-126-sin(time*2)*5),10,Color("e7f8ee"))
 draw_circle(Vector2(0,-132-sin(time*2)*5),12,Color("e7f8ee"))
 draw_set_transform(Vector2.ZERO)

func _food(id:int,p:Vector2,k:float=1.0):
 var c=Color(Rules.INGREDIENTS[id].color)
 draw_set_transform(p,0,Vector2(k,k))
 draw_circle(Vector2(0,5),25,Color(0.2,0.25,0.2,0.12))
 match id%6:
  0:
   draw_colored_polygon(PackedVector2Array([Vector2(-27,16),Vector2(0,-27),Vector2(27,16),Vector2(22,25),Vector2(-22,25)]),c)
   draw_rect(Rect2(-9,9,18,17),JADE)
  1:
   for j in 3: draw_circle(Vector2(-17+j*16,sin(j*1.5)*10-6),14,c)
   draw_arc(Vector2(0,0),28,0,PI,18,Color("4e9379"),4)
  2:
   draw_arc(Vector2.ZERO,22,-2.6,1.8,22,c,17)
   draw_colored_polygon(PackedVector2Array([Vector2(-18,-15),Vector2(-32,-32),Vector2(-10,-28)]),c)
   for j in 3: draw_line(Vector2(8+j*5,-18+j*8),Vector2(18+j*2,-12+j*8),CREAM,3)
  3:
   draw_circle(Vector2.ZERO,27,Color("fff9dc")); draw_circle(Vector2(4,0),16,c)
  4:
   var points=PackedVector2Array()
   for j in 10:
    var a=j*PI/5-PI/2
    points.append(Vector2(cos(a),sin(a))*(29 if j%2==0 else 15))
   draw_colored_polygon(points,c)
   draw_line(Vector2(-2,-25),Vector2(6,-35),JADE,5)
  5:
   draw_rect(Rect2(-23,-16,46,38),c)
   _ellipse(Vector2(0,-16),Vector2(23,10),Color("fff8f0"))
   draw_line(Vector2(-15,0),Vector2(14,0),Color.WHITE,3)
 draw_circle(Vector2(-7,7),2.2,INK); draw_circle(Vector2(7,7),2.2,INK)
 draw_set_transform(Vector2.ZERO)

func _ellipse(p:Vector2,r:Vector2,c:Color):
 var pts=PackedVector2Array()
 for i in 32: pts.append(p+Vector2(cos(i*TAU/32),sin(i*TAU/32))*r)
 draw_colored_polygon(pts,c)

func _title():
 _panel(Rect2(100,125,790,540))
 _label("晴贝小岛 · 云上小食记",Vector2(145,183),23,JADE)
 _label("云鲸便当铺",Vector2(143,265),64,INK)
 _label("把小小食材，摆成一份晴天。",Vector2(148,319),29,CORAL)
 _label("三天 · 九位旅客 · 一头会飞的温柔鲸鱼",Vector2(148,367),23)
 for i in 6: _food(i,Vector2(177+i*112,425),0.95)
 _button(Rect2(145,489,285,62),"开张 · 新旅程",func(): model.reset(); screen="game"; selected=-1; _save())
 _button(Rect2(455,489,285,62),"继续营业",func():
  if model.restore(saved_data): screen="game"; selected=-1
 ,CORAL,resume_available)
 _button(Rect2(145,576,180,52),"玩法手册",func(): overlay="help")
 _button(Rect2(345,576,180,52),"返回海岛",request_exit,Color("8b9c9b"))
 _label("原创云端料理 · 食材插画均为程序绘制",Vector2(145,716),20,Color("537f78"))

func _game():
 _panel(Rect2(24,18,1232,78))
 _label("云鲸便当铺",Vector2(48,69),34)
 _label("第 %d / 3 天   第 %d / 9 单"%[model.day,mini(model.order+1,9)],Vector2(305,65),23)
 _label("贝币 %d   今日租金 %d"%[model.coins,Rules.RENT[model.day-1]],Vector2(645,65),23,CORAL)
 _button(Rect2(1020,33,100,48),"手册",func(): overlay="help")
 _button(Rect2(1132,33,100,48),"暂停",func(): overlay="pause",Color("8b9c9b"))
 _panel(Rect2(24,113,350,640))
 _label("今日客人",Vector2(46,149),20,JADE)
 _customer_portrait(Vector2(92,211))
 _label(model.customer().name,Vector2(150,196),24)
 _label("恰好 %d 份食材"%model.customer().count,Vector2(150,232),21)
 _label(model.customer().wish,Vector2(47,286),23,CORAL)
 _label("食材篮 · 点击选择",Vector2(47,330),23)
 for id in 12:
  var col=id%3; var row=id/3
  var r=Rect2(42+col*106,349+row*86,96,78)
  if model.stock[id]>0:
   _panel(r,Color("e4efe0") if id!=selected else Color("f6d7b0"),12)
   _food(id,r.position+Vector2(30,28),0.6)
   _label("×%d"%model.stock[id],r.position+Vector2(64,31),17)
   _label(Rules.INGREDIENTS[id].name,r.position+Vector2(7,67),18)
   if model.phase=="serve": buttons.append({"rect":r,"action":func(): selected=id; notice=Rules.INGREDIENTS[id].tip})
  else:
   _panel(r,Color("eeeadd"),12)
   _label("售罄",r.position+Vector2(26,46),18,Color("b2b6aa"))
 _label("每份食材费在交餐时结算",Vector2(47,725),19,JADE)
 _panel(Rect2(391,113,481,640))
 _label("晴天便当盒",Vector2(418,157),28)
 _label("同一横排：三种类别 +5",Vector2(418,190),21,JADE)
 for slot in 9:
  var r=Rect2(419+(slot%3)*140,216+(slot/3)*140,128,128)
  _panel(r,Color("eed8b7"),17)
  _panel(Rect2(r.position+Vector2(6,6),r.size-Vector2(12,12)),Color("fff5de"),12)
  if model.board[slot]>=0:
   var id:int=model.board[slot]
   _food(id,r.position+Vector2(64,49),1.25+(pulse*0.18 if pulse_slot==slot else 0))
   for steam in 2:
    var drift=fposmod(time*16+steam*18,36)
    draw_arc(r.position+Vector2(50+steam*24+sin(time*2+steam)*3,36-drift),8,-1.3,1.3,12,Color(1,1,1,(1-drift/36)*0.6),2)
   _label(Rules.INGREDIENTS[id].name,r.position+Vector2(19,105),20)
   if model.enhancements[id]>0: _label("+%d"%(2*model.enhancements[id]),r.position+Vector2(96,24),18,CORAL)
  else:
   _label("+" if selected>=0 else "·",r.position+Vector2(55,72),30,Color("cdbda3"))
  if model.phase=="serve": buttons.append({"rect":r,"action":func():
   if selected>=0:
    if model.place(selected,slot): pulse_slot=slot; pulse=1; _save()
    else: notice="食材用完或餐盒已满。先收回再换一种。"; selected=-1
   else: model.remove(slot); _save()
  })
 _button(Rect2(419,655,198,55),"收回模式",func(): selected=-1; notice="点击盒中食材收回，再重新摆放。",Color("8b9c9b"),model.phase=="serve")
 _button(Rect2(632,655,210,55),"交给客人",func():
  if model.serve(): selected=-1; _save()
  else: notice="食材不够，至少要 %d 份。"%model.customer().count
 ,CORAL,model.phase=="serve" and model.evaluate().count>=model.customer().count)
 _preview()
 _label(notice,Vector2(400,786),20,INK)
 if model.phase!="serve": _phase_modal()

func _customer_portrait(p:Vector2):
 var index=(model.order+model.day-1)%3
 var col=[Color("e8d2d2"),Color("c5b49b"),Color("aabac8")][index]
 if index==0:
  _ellipse(p+Vector2(-15,-32),Vector2(9,30),col)
  _ellipse(p+Vector2(15,-32),Vector2(9,30),col)
 draw_circle(p,40,col)
 if index==2:
  draw_colored_polygon(PackedVector2Array([p+Vector2(-35,-15),p+Vector2(-35,-49),p+Vector2(-10,-31)]),col)
  draw_colored_polygon(PackedVector2Array([p+Vector2(35,-15),p+Vector2(35,-49),p+Vector2(10,-31)]),col)
 for x in [-14,14]:
  draw_circle(p+Vector2(x,0),9,CREAM); draw_circle(p+Vector2(x,0),3,INK)
 draw_circle(p+Vector2(0,12),4,CORAL)

func _preview():
 var e=model.evaluate()
 _panel(Rect2(890,113,366,494))
 _label("账单预览",Vector2(914,157),28)
 _label("食材 %d / 恰好 %d"%[e.count,model.customer().count],Vector2(914,195),22)
 _label("基础售价       %d"%e.base,Vector2(914,236),23)
 _label("客人口味      %+d"%e.preference,Vector2(914,273),23,CORAL)
 _label("摆放加成      +%d"%e.bonus,Vector2(914,310),23,JADE)
 _label("食材成本      −%d"%e.cost,Vector2(914,347),23)
 draw_line(Vector2(914,367),Vector2(1230,367),Color("dfd9c5"),2)
 _label("预计净赚   %+d"%e.profit,Vector2(914,408),31,JADE)
 var counts={}
 for reason in e.reasons: counts[reason]=counts.get(reason,0)+1
 var y=447
 for reason in counts:
  _label(reason+(" ×%d"%counts[reason] if counts[reason]>1 else ""),Vector2(914,y),19)
  y+=26
 if counts.is_empty(): _label("相邻指上下左右，不含对角。",Vector2(914,453),19)
 if selected>=0:
  _label(Rules.INGREDIENTS[selected].name+" · "+Rules.INGREDIENTS[selected].tip,Vector2(900,645),19)
  _label("售价 %d / 成本 %d"%[Rules.INGREDIENTS[selected].price+model.enhancements[selected]*2,Rules.INGREDIENTS[selected].cost],Vector2(900,678),21)

func _phase_modal():
 buttons=[]
 draw_rect(Rect2(0,100,1280,700),Color(0.15,0.26,0.25,0.53))
 _panel(Rect2(250,200,780,430))
 var phase=model.phase
 if phase=="draft":
  _label("云端集市 · 补充食材",Vector2(290,253),34)
  _label("花 3 贝币买两份；也可以只用免费食材篮。",Vector2(290,296),23)
  for i in 3:
   var id:int=model.offers[i]
   _food(id,Vector2(385+i*245,365),1.1)
   _label(Rules.INGREDIENTS[id].tip,Vector2(290+i*245,424),19)
   _button(Rect2(284+i*245,449,220,57),Rules.INGREDIENTS[id].name+" ×2",func():
    if model.buy(id): _save()
   ,JADE,model.coins>=3)
  _button(Rect2(405,545,470,55),"跳过采购 · 开始摆盘",func(): model.skip(); _save(),CORAL)
 elif phase=="upgrade":
  _label("第 %d 天打烊 · 租金已付"%model.day,Vector2(290,253),32)
  _label("剩余 %d 贝币。花 6 币，让一种食材永久售价 +2。"%model.coins,Vector2(290,297),22)
  for i in 6:
   _button(Rect2(285+(i%3)*245,333+(i/3)*80,220,60),Rules.INGREDIENTS[i].name+" +2",func():
    if model.upgrade(i): _save()
   ,JADE,model.coins>=6)
  _button(Rect2(405,545,470,55),"保留贝币 · 迎接明天",func(): model.next_day(); _save(),CORAL)
 elif phase=="receipt":
  _label("叮！一份晴天已送达",Vector2(290,260),36)
  _label("售价 %d − 食材 %d = 净赚 %d"%[model.last_result.total,model.last_result.cost,model.last_result.profit],Vector2(290,333),29,JADE)
  _label("三单后付租金。下一位客人的口味会改变。",Vector2(290,391),23)
  _button(Rect2(405,495,470,62),"欢迎下一位",func(): model.advance(); _save(),CORAL)
 else:
  _label("云鲸的三日小店，圆满收工！" if phase=="won" else "贝币不够付租金啦",Vector2(290,267),34)
  _label("结余 %d 贝币 · 完成 %d 份便当"%[model.coins,model.order],Vector2(290,335),27,JADE)
  _label("鲸鱼说：下次试试口味搭配和三色横排吧。",Vector2(290,391),23)
  _button(Rect2(290,490,330,62),"再开一家 · 重新挑战",func(): model.reset(); selected=-1; _save(),CORAL)
  _button(Rect2(650,490,330,62),"返回海岛",request_exit)
 _button(Rect2(1132,33,100,48),"暂停",func(): overlay="pause",Color("8b9c9b"))

func _overlay():
 buttons=[]
 draw_rect(Rect2(0,0,1280,800),Color(0.13,0.24,0.23,0.75))
 _panel(Rect2(170,108,940,584))
 if overlay=="help":
  _label("云鲸店主手册",Vector2(215,168),38)
  var lines=["1   先看客人口味与限定份数；集市可买两份稀有食材，或跳过。","2   点食材篮，再点 3×3 格子。收回模式可免费重摆。","3   米团/海苔 + 蔬菜：每组相邻 +3；海鲜 + 柠檬：+4。","4   甜果 + 奶冻：相邻 +4；月牙蛋在正中心：+4。","5   任一横排放满三种不同类别：+5。只算上下左右相邻。","6   喜爱食材每份 +3，不爱每份 −3。右边实时显示账单。","7   三单付一次租金，负债即停业。三天后不负债就胜利。","8   打烊可花 6 币强化食材，后续每份售价 +2，可叠加。"]
  for i in lines.size(): _label(lines[i],Vector2(215,226+i*45),23)
  _button(Rect2(425,613,430,55),"明白啦 · 回到小店",func(): overlay="",CORAL)
 else:
  _label("鲸鱼休息中",Vector2(215,183),42)
  _label("进度自动保存在本游戏的独立档案里。",Vector2(215,249),26)
  _button(Rect2(350,307,580,64),"继续营业",func(): overlay="")
  _button(Rect2(350,393,580,64),"查看玩法",func(): overlay="help",CORAL)
  _button(Rect2(350,479,580,64),"保存并返回海岛",request_exit,Color("8b9c9b"))
  _label("Esc 也可暂停或继续 · 没有倒计时，慢慢摆。",Vector2(270,613),23)
