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
	return {"name":CHAPTERS[chapter][1][segment],"chapter_name":CHAPTERS[chapter][0],"width":width,"platforms":platforms,"hazards":hazards,"ladders":ladders,"enemies":enemies,"objective":OBJECTIVES[chapter][segment],"exit_x":width-110.0,"checkpoint_x":180.0,"collectible":Vector2(860,390),"boss":boss}
