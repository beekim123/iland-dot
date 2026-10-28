extends RefCounted
## Explicit authored chapters: four distinct playable sections each, not random waves.
const CHAPTERS = [
	["离乡之剑", ["火焰划开的庆典", "公主的蓝丝带", "伐木营救援", "巨斧的路障"]],
	["风雨古桥", ["淹水遗迹", "断桥上的箭雨", "守桥人与钟楼", "铁甲桥卫"]],
	["暮色山道", ["峡谷回声", "蝠影矿道", "山城外墙", "岩壳巨蜥"]],
	["赤焰城关", ["焦黑城门", "燃烧兵营", "晨光圣堂", "灰烬骑士"]],
	["龙塔黎明", ["旋风塔阶", "囚室的封印", "两人的逃离", "赤焰龙巢"]]
]
const ENEMY_STATS = {
	"bandit": [45, 84.0, 12, 0.65, 70.0], "wolf": [32, 145.0, 10, 0.42, 72.0],
	"shield": [55, 65.0, 14, 0.85, 80.0], "archer": [34, 55.0, 11, 0.9, 420.0],
	"bat": [25, 130.0, 9, 0.6, 65.0], "salamander": [45, 80.0, 13, 0.9, 250.0],
	"slinger": [38, 65.0, 14, 1.0, 350.0], "heavy": [75, 58.0, 22, 1.15, 96.0],
	"mage": [40, 62.0, 16, 1.05, 400.0],
	"axe_lord": [240, 82.0, 23, 1.0, 130.0], "bridge_guard": [280, 72.0, 24, 1.2, 145.0],
	"rock_lizard": [300, 95.0, 22, 1.1, 150.0], "ash_knight": [360, 115.0, 24, 0.8, 115.0],
	"dragon": [600, 68.0, 28, 1.15, 210.0]
}
const MIXES = [["bandit","wolf"],["shield","archer","bandit"],["bat","salamander","slinger"],["heavy","mage","shield"],["mage","heavy","bat"]]
const BOSSES = ["axe_lord","bridge_guard","rock_lizard","ash_knight","dragon"]
const OBJECTIVES = [
	["穿过街道，保护村民；在金色路标处互动", "沿公主留下的丝带穿过森林", "救出被困的伐木工，向营火前进", "观察巨斧前摇，击败匪首后出发"],
	["越过遗迹升降台，寻找古桥", "用盾挡箭，跨过断桥", "转动钟楼机关，救助守桥人", "绕开正面盾牌，反击桥卫"],
	["穿过摆锤峡谷", "借矿道梯子避开蝠群", "躲开喷焰，登上山城", "诱使巨蜥冲锋撞墙，再攻击弱点"],
	["突破赤焰城门", "在兵营开辟通路", "触碰圣堂铭文，获得晨光斩", "击败灰烬骑士，打开登塔之门"],
	["攀登龙塔，寻找囚室", "用晨光击破封印，再互动救出艾琳", "与艾琳开启两道机关，送她进入防护厅", "在公主的防护下迎战恶龙；三阶段决战"]
]
# Individual section geometry (x, y, width); safe main lane plus authored high routes.
const ROUTES = [
 [[420,510,230],[760,410,230],[1100,480,260],[1560,510,220],[1900,450,240]],
 [[350,520,300],[800,420,260],[1220,490,220],[1760,490,240],[2150,430,220]],
 [[500,510,230],[850,400,250],[1250,480,260],[1780,500,260],[2160,410,240]],
 [],
 [[400,500,220],[780,410,250],[1140,470,300],[1650,500,220],[2010,420,260]],
 [[340,510,280],[760,410,230],[1150,480,260],[1570,510,300],[2010,440,260]],
 [[430,500,230],[800,410,240],[1200,480,300],[1630,500,250],[2000,420,240]],
 [],
 [[400,510,260],[790,410,230],[1130,480,300],[1700,510,220],[2100,430,250]],
 [[350,520,280],[780,410,300],[1190,480,260],[1650,510,240],[2060,420,270]],
 [[410,510,230],[790,410,240],[1160,480,300],[1700,510,250],[2100,430,240]],
 [],
 [[400,510,300],[800,410,250],[1210,480,220],[1620,500,300],[2050,420,250]],
 [[420,510,230],[780,410,260],[1150,480,300],[1630,510,240],[2050,430,300]],
 [[380,510,280],[780,410,250],[1140,480,300],[1680,510,240],[2100,420,250]],
 [],
 [[420,510,250],[790,410,260],[1180,480,280],[1640,510,220],[2010,430,300]],
 [[380,510,260],[780,410,250],[1200,480,250],[1630,500,300],[2050,410,270]],
 [[420,510,250],[790,410,260],[1180,480,280],[1640,510,220],[2010,430,300]],
 []
]
static func level(chapter: int, segment: int) -> Dictionary:
	var boss: bool = segment == 3
	var width: float = 1800.0 if boss else 3300.0 + chapter * 180.0
	var platforms: Array = [{"x":0.0,"y":620.0,"w":width,"kind":"ground"}]
	var hazards: Array = []
	var ladders: Array = []
	if not boss:
		# Upper optional route, drop-through ledges and distinct obstacle rhythm.
		var route: Array = ROUTES[chapter*4+segment]
		for i in range(route.size()):
			var p: Array = route[i]
			platforms.append({"x":float(p[0]),"y":float(p[1]),"w":float(p[2]),"kind":"moving" if i == 2 else ("crumble" if i == 3 else "ledge")})
		ladders.append({"x":float(route[4][0])+30.0,"top":float(route[4][1]),"bottom":620.0})
		if segment > 0 or chapter > 0:
			hazards.append({"x":1440.0,"w":110.0,"kind":"pit","period":0.0})
			hazards.append({"x":2250.0,"w":140.0,"kind":"flame" if chapter >= 2 else "pendulum","period":3.6})
		if chapter == 1: hazards.append({"x":2700.0,"w":150.0,"kind":"pit","period":0.0})
	var enemies: Array = []
	if boss:
		enemies.append({"kind":BOSSES[chapter],"x":1250.0,"y":620.0,"boss":true})
	else:
		for i in range(6):
			var mix: Array = MIXES[chapter]
			enemies.append({"kind":mix[(i+segment)%mix.size()],"x":680.0+i*390.0,"y":620.0,"boss":false})
	var mechanisms: Array = []
	if chapter == 0 and segment == 0: mechanisms.append({"id":"town_rescue","x":940.0,"y":620.0,"kind":"rescue","label":"保护街角居民","message":"居民：公主为了保护我们被龙掳走了。她往森林留下了丝带。"})
	if chapter == 0 and segment == 1: mechanisms.append({"id":"ribbon","x":1790.0,"y":620.0,"kind":"clue","label":"查看蓝色丝带","message":"丝带上的王室结扣：艾琳仍在为你指路。"})
	if chapter == 0 and segment == 2: mechanisms.append({"id":"lumber_rescue","x":2500.0,"y":620.0,"kind":"rescue","label":"救出伐木工","message":"伐木工推开了倒木。通往匪首营地的路打开了。"})
	if chapter == 1 and segment == 0: mechanisms.append({"id":"sluice","x":2020.0,"y":420.0,"kind":"lever","label":"升起遗迹水闸","message":"水闸升起，古桥遗迹的捷径已打开。"})
	if chapter == 1 and segment == 2: mechanisms.append({"id":"bell","x":2030.0,"y":420.0,"kind":"lever","label":"敲响钟楼救助守桥人","message":"守桥人：山城圣堂里保存着晨光铭文。请一定带公主平安回来。"})
	if chapter == 2 and segment == 1: mechanisms.append({"id":"mine_lift","x":2090.0,"y":420.0,"kind":"lever","label":"启动矿井升降机关","message":"旧升降机关重新运转，山城的外墙就在前方。"})
	if chapter == 3 and segment == 1: mechanisms.append({"id":"barracks","x":2080.0,"y":430.0,"kind":"lever","label":"关闭兵营喷焰阀门","message":"喷焰阀门关闭。圣堂的石门显露在烟尘之后。"})
	# Region-specific causal loops. Requirements change routes, not just a counter.
	var extra: Dictionary = {
		"0:0":[["street_valve",2600,620,"lever","关闭街道火源","居民已经脱险，街道火源熄灭了。",["town_rescue"],"flames"]],
		"0:1":[["forest_winch",1120,480,"lever","沿丝带回到倒木绞盘","丝带指向了树顶的旧绞盘。倒木挪开，林路重新连通。",["ribbon"],"bridge"]],
		"0:2":[["workers_bridge",2150,410,"lever","与伐木工放下木桥","伐木工接住缆绳，放下通往匪首营地的木桥。",["lumber_rescue"],"bridge"]],
		"1:0":[["ruin_tablet",810,410,"clue","水退后查看遗迹石碑","退水露出王室记号：龙塔古道经由钟楼。",["sluice"],""]],
		"1:1":[["bridge_anchor",1170,480,"lever","固定断桥左端索锚","第一道索锚锁定。雨中的吊桥不再晃动。",[],"bridge"],["bridge_anchor_far",2600,620,"lever","固定断桥另一端","两端索锚都已固定，弓箭手的阵地暴露了。",["bridge_anchor"],"flames"]],
		"1:2":[["bridgekeeper",980,620,"rescue","下楼接应老守桥人","守桥人交出圣堂路线：以晨光破暗焰，以勇气守护所爱。",["bell"],""]],
		"2:0":[["canyon_weight",1150,480,"lever","拉起峡谷配重","配重抬起了一半桥面。去另一侧固定绳索。",[],"bridge"],["canyon_rope",2570,620,"lever","固定峡谷绳索","绳索固定，通往矿道的桥已经安全。",["canyon_weight"],"flames"]],
		"2:1":[["mine_cart",1190,620,"cart","乘矿车穿过下层轨道","矿车沿下层轨道启动。按跳跃可提前离车。",["mine_lift"],"bridge"]],
		"2:2":[["wall_valve_low",1150,480,"lever","关闭城墙下层火阀","第一道火阀关闭。高处仍有一道主阀。",[],"flames"],["wall_valve_high",2130,430,"lever","转动城墙主阀","城墙主阀关闭，通往城门的路露出来了。",["wall_valve_low"],"flames"]],
		"3:0":[["gate_chain",1200,480,"lever","解开城门锁链","第一组锁链松开。守门卫兵正在向另一侧集合。",[],"bridge"],["gate_counterweight",2650,620,"lever","释放城门配重","沉重的城门终于升起。",["gate_chain"],"flames"]],
		"3:1":[["barracks_captive",980,620,"rescue","回去救出兵营囚徒","囚徒逃向安全道路，并指出圣堂三座晨光铭文的位置。",["barracks"],""]],
		"3:2":[["rune_courage",820,410,"clue","触碰勇气铭文","第一座铭文：面对恐惧，仍选择向前。",[],""],["rune_mercy",1730,620,"clue","触碰守护铭文","第二座铭文：力量是为了保护，而不是掠夺。",["rune_courage"],""],["rune_dawn",2690,620,"clue","让旧剑承接晨光","第三座铭文：无论黑夜多长，晨曦总会到来。晨光斩觉醒！",["rune_mercy"],"dawn"]],
		"4:0":[["tower_brake",1200,480,"lever","解除龙塔升降锁","风塔升降台开始运转。留意风向，再跳向上层。",[],"bridge"],["tower_anchor",2700,620,"lever","锁住上层风闸","上层风闸锁定，囚室就在前方。",["tower_brake"],"flames"]],
		"4:1":[["prison_lock",1280,480,"lever","打开囚室外层锁","外层门锁打开。内层暗焰必须用晨光斩击破。",[],"bridge"]]
	}
	for item in extra.get("%d:%d" % [chapter,segment],[]):
		mechanisms.append({"id":item[0],"x":float(item[1]),"y":float(item[2]),"kind":item[3],"label":item[4],"message":item[5],"requires":item[6],"effect":item[7]})
	for mechanism in mechanisms:
		if mechanism.y<600:
			platforms.append({"x":mechanism.x-65.0,"y":mechanism.y,"w":130.0,"kind":"ledge"})
			ladders.append({"x":mechanism.x,"top":mechanism.y,"bottom":620.0})
	if not boss and chapter>0:
		var mix: Array = MIXES[chapter]
		enemies.append({"kind":mix[(segment+1)%mix.size()],"x":1120.0,"y":620.0,"boss":false})
		enemies.append({"kind":mix[segment%mix.size()],"x":2320.0,"y":620.0,"boss":false})
	return {"mechanisms":mechanisms,"wind":chapter == 4 and segment == 0,"name":CHAPTERS[chapter][1][segment],"chapter_name":CHAPTERS[chapter][0],"width":width,"platforms":platforms,"hazards":hazards,"ladders":ladders,"enemies":enemies,"objective":OBJECTIVES[chapter][segment],"exit_x":width-110.0,"checkpoint_x":180.0,"collectible":Vector2(860,390),"boss":boss}
