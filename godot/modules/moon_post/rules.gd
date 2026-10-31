extends RefCounted
## Deterministic simultaneous movement; couriers are paper spirits and may overlap.
const DIRS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const LEVEL_PATH = "res://modules/moon_post/levels.json"
var levels: Array = []
var level_index := 0
var positions: Array = []
var history: Array = []
var moves := 0

func _init():
	levels = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	reset(0)

func reset(index: int):
	level_index = clampi(index, 0, levels.size()-1)
	positions = coordinates(levels[level_index].starts)
	history.clear()
	moves = 0

func coordinates(raw: Array) -> Array:
	var result: Array = []
	for p in raw: result.append(Vector2i(int(p[0]), int(p[1])))
	return result

func tile(p: Vector2i) -> String:
	var grid: Array = levels[level_index].grid
	if p.y < 0 or p.y >= grid.size() or p.x < 0 or p.x >= grid[p.y].length(): return "#"
	return grid[p.y][p.x]

func gates_open(state: Array) -> bool:
	for p in state:
		if tile(p) == "s": return true
	return false

func transition(state: Array, direction: int) -> Array:
	var result: Array = []
	var opened := gates_open(state)
	for p in state:
		var target: Vector2i = p + DIRS[posmod(direction, 4)]
		var terrain := tile(target)
		result.append(p if terrain == "#" or (terrain == "g" and not opened) else target)
	return result

func move(direction: int) -> bool:
	var next := transition(positions, direction)
	if next == positions: return false
	history.append(positions.duplicate())
	positions = next
	moves += 1
	return true

func undo() -> bool:
	if history.is_empty(): return false
	positions = history.pop_back()
	moves -= 1
	return true

func won(state: Array = []) -> bool:
	if state.is_empty(): state = positions
	return state == coordinates(levels[level_index].goals)

func key(state: Array) -> String:
	var parts := PackedStringArray()
	for p in state: parts.append("%d,%d" % [p.x, p.y])
	return ";".join(parts)

## Breadth-first proof also provides an optional next-step hint from any state.
func solve(from_state: Array = []) -> String:
	if from_state.is_empty(): from_state = positions
	var queue: Array = [from_state.duplicate()]
	var paths := {key(from_state): ""}
	var cursor := 0
	while cursor < queue.size():
		var state: Array = queue[cursor]
		cursor += 1
		var path: String = paths[key(state)]
		if won(state): return path
		for d in range(4):
			var next := transition(state, d)
			var id := key(next)
			if not paths.has(id):
				paths[id] = path + str(d)
				queue.append(next)
	return "!"
