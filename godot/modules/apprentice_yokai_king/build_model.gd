extends RefCounted

const CORES := ["ayk_core_wind", "ayk_core_thunder", "ayk_core_quake"]
const CARDS := {
 "ayk_core_wind": ["核心 · 出手有风", "满蓄附带短风刃：伤害 1，最多穿透 3 敌。", "wind"],
 "ayk_wind_step": ["顺风步", "蓄力移速提高到 80% / 90%。", "wind"],
 "ayk_wind_return": ["回风", "风刃末端回返一次；二级回返伤害提高。", "wind"],
 "ayk_core_thunder": ["核心 · 闷雷落槌", "满蓄命中后预告落雷：伤害 1，最多命中 3 敌。", "thunder"],
 "ayk_thunder_chain": ["导雷角", "落雷额外连接邻近 1 / 2 敌，不重复命中。", "thunder"],
 "ayk_thunder_charge": ["蓄电", "轻击命中 3 / 2 次，强化下一次满蓄落雷。", "thunder"],
 "ayk_core_quake": ["核心 · 震荡地圈", "满蓄附带地圈击退：伤害 1，最多影响 6 敌。", "quake"],
 "ayk_quake_slow": ["软地回响", "地圈减速 20% / 30%，持续 1 秒。", "quake"],
 "ayk_quake_echo": ["余震", "首圈后追加一次 50% / 75% 伤害余震。", "quake"],
 "ayk_fast": ["短柄快挥", "轻击恢复缩短 10% / 18%，前摇不变。", "all"],
 "ayk_elastic": ["弹性槌头", "击飞距离增加 15% / 25%，连撞上限仍为 3。", "all"],
 "ayk_roll": ["滚得圆", "闪避冷却降至 1.0 / 0.9 秒，无敌时长不变。", "all"]
}
var levels: Dictionary = {}
var core: String = ""
var chosen_count: int = 0
var reroll_used: bool = false
var rng := RandomNumberGenerator.new()
var _offers: Array[String] = []

func reset(seed_value: int) -> void:
 levels.clear()
 core = ""
 chosen_count = 0
 reroll_used = false
 rng.seed = seed_value
 _offers.clear()

func level(id: String) -> int:
 return int(levels.get(id, 0))

func offers() -> Array[String]:
 if chosen_count >= 5:
  return []
 if not _offers.is_empty():
  return _offers.duplicate()
 if core.is_empty():
  _offers.assign(CORES)
  return _offers.duplicate()
 var pool: Array[String] = []
 var route: String = str(CARDS[core][2])
 for id: String in CARDS:
  if id in CORES:
   continue
  if CARDS[id][2] != "all" and CARDS[id][2] != route:
   continue
  if level(id) >= 2 or (levels.size() >= 5 and level(id) == 0):
   continue
  pool.append(id)
 while not pool.is_empty() and _offers.size() < 3:
  var i := rng.randi_range(0, pool.size() - 1)
  _offers.append(pool[i])
  pool.remove_at(i)
 while _offers.size() < 3:
  _offers.append("ayk_recovery")
 return _offers.duplicate()

func choose(id: String) -> bool:
 if (not CARDS.has(id) and id != "ayk_recovery") or (id in CORES and not core.is_empty()):
  return false
 if chosen_count >= 5 or not id in offers():
  return false
 if id != "ayk_recovery":
  levels[id] = level(id) + 1
  if id in CORES:
   core = id
 chosen_count += 1
 _offers.clear()
 return true

func reroll() -> bool:
 if reroll_used or chosen_count >= 5:
  return false
 reroll_used = true
 _offers.clear()
 offers()
 return true

func card_title(id: String) -> String:
 if id == "ayk_recovery":
  return "歇一歇 · 恢复"
 return str(CARDS.get(id, ["未知卡牌"])[0]) + (" · 升至 II" if level(id) == 1 and not id in CORES else "")

func card_description(id: String) -> String:
 if id == "ayk_recovery":
  return "恢复 2 心；满血则生命上限 +1（最多 7）；已达上限则获得 1 次护盾。"
 if not CARDS.has(id):
  return ""
 var upgraded := level(id) == 1
 var specific := ""
 match id:
  "ayk_wind_step": specific = "蓄力移动速度：80% → 90%。" if upgraded else "蓄力移动速度：65% → 80%。"
  "ayk_wind_return": specific = "回返伤害：1 → 1.5；仍只回返一次。" if upgraded else "风刃末端回返一次：伤害 1，最多 3 敌，不再生风刃。"
  "ayk_thunder_chain": specific = "落雷额外连接目标：1 → 2。" if upgraded else "落雷额外连接邻近 1 敌，每个目标只命中一次。"
  "ayk_thunder_charge": specific = "强化所需轻击命中：3 → 2 次。" if upgraded else "轻击命中 3 次后，下次满蓄雷伤：1 → 3；不能叠层。"
  "ayk_quake_slow": specific = "地圈减速：20% → 30%，持续 1 秒。" if upgraded else "地圈使普通敌人减速 20%，持续 1 秒。"
  "ayk_quake_echo": specific = "余震伤害：首圈的 50% → 75%。" if upgraded else "首圈后追加一次 50% 伤害余震，不再产生余震。"
  "ayk_fast": specific = "轻击恢复缩短：10% → 18%，前摇不变。" if upgraded else "轻击恢复缩短 10%，前摇不变。"
  "ayk_elastic": specific = "击飞距离加成：15% → 25%，连撞仍最多 3 敌。" if upgraded else "击飞距离 +15%，连撞仍最多 3 敌。"
  "ayk_roll": specific = "闪避冷却：1.0 → 0.9 秒，无敌时长不变。" if upgraded else "闪避冷却：1.1 → 1.0 秒，无敌时长不变。"
  _: specific = str(CARDS[id][1])
 return specific
