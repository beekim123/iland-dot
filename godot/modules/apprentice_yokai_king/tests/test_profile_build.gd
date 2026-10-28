extends SceneTree

const Build = preload("res://modules/apprentice_yokai_king/build_model.gd")
const Profile = preload("res://modules/apprentice_yokai_king/profile_store.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  printerr("FAIL: " + label)

func _initialize() -> void:
 test_build()
 test_profile()
 print("AYK profile/build: %d checks, %d failures" % [checks, failures.size()])
 quit(0 if failures.is_empty() else 1)

func test_build() -> void:
 for seed_value in range(120):
  var a = Build.new()
  var b = Build.new()
  a.reset(seed_value)
  b.reset(seed_value)
  check(a.offers() == b.offers() and a.offers().size() == 3, "deterministic opening")
  var selected: String = a.offers()[seed_value % 3]
  check(a.choose(selected) and b.choose(selected), "core selected")
  check(not a.choose(selected), "core cannot be selected twice")
  check(a.reroll() and b.reroll() and not a.reroll(), "one reroll only")
  for round_index in range(4):
   var options: Array[String] = a.offers()
   check(options == b.offers() and options.size() == 3, "deterministic filtered triple")
   for id: String in options:
    check(not id in Build.CORES and a.level(id) < 2, "no conflicting core or max card")
   var id: String = options[round_index % 3]
   check(a.choose(id) and b.choose(id), "legal card choice")
  check(a.chosen_count == 5 and a.offers().is_empty() and not a.choose("ayk_recovery"), "five upgrade hard limit")
  check(a.levels.size() <= 5, "five distinct cards limit")
 var build = Build.new()
 build.reset(5)
 check(not build.choose("res"+"://evil"), "unknown card rejected")
 build.choose("ayk_core_wind")
 for id: String in Build.CARDS:
  if not id in Build.CORES:
   build.levels[id] = 2
 check(build.offers().has("ayk_recovery"), "exhausted pool recovery")
 check(build.card_title("ayk_fast") != "" and build.card_description("ayk_recovery") != "", "UI card copy")

func write_raw(raw: String) -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Profile.PATH.get_base_dir()))
 var file := FileAccess.open(Profile.PATH, FileAccess.WRITE)
 file.store_string(raw)
 file.close()

func test_profile() -> void:
 # Run with isolated XDG_DATA_HOME: this test intentionally owns only the module profile.
 if FileAccess.file_exists(Profile.PATH):
  DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.PATH))
 var store = Profile.new()
 check(store.load_profile().records.standard.runs_finished == 0, "empty default")
 check(store.save_profile(), "initial atomic save")
 check(store.record_result("standard", true, 6, 300.0, "ayk_core_wind", ["grunt", "boss"], "test-one"), "genuine result API")
 check(not store.record_result("standard", true, 6, 300.0, "ayk_core_wind", ["grunt"], "test-one"), "same instance idempotent")
 check(FileAccess.file_exists(Profile.PATH + ".bak"), "valid previous backup")
 store = Profile.new()
 store.load_profile()
 check(not store.record_result("standard", true, 6, 300.0, "ayk_core_wind", ["grunt"], "test-one"), "restart idempotent")
 check(store.record_result("assist", false, 2, 99.0, "", ["shield"], "test-two"), "assist failure recorded")
 check(store.data.records.standard.wins == 1 and store.data.records.assist.wins == 0 and store.data.records.assist.runs_finished == 1, "difficulty isolation")
 check(not store.record_result("standard", true, 4, 80.0, "", [], "bad-wave"), "win must reach wave six")
 check(not store.record_result("standard", false, 1, NAN, "", [], "bad-nan"), "nonfinite runtime rejected")
 var invalid_values: Array = [true, -1, 1.5, 0, "1", null]
 for value in invalid_values:
  var candidate: Dictionary = Profile.defaults()
  candidate.schema_version = value
  var bytes := JSON.stringify(candidate)
  write_raw(bytes)
  store.load_profile()
  check(store.blocked and not store.save_profile() and FileAccess.get_file_as_string(Profile.PATH) == bytes, "bad schema protected")
 for mutation in range(8):
  var candidate: Dictionary = Profile.defaults()
  match mutation:
   0: candidate.module_id = "other_game"
   1: candidate.records.standard.wins = 1
   2: candidate.records.standard.best_wave = 7
   3: candidate.records.standard.best_clear_ms = 1
   4: candidate.discovery.enemy_ids = ["res"+"://unknown.tscn"]
   5: candidate.discovery.cleared_core_ids = ["ayk_core_other"]
   6: candidate.settings.charge_mode = "auto_attack"
   7: candidate.settings.screen_shake = 1
  var bytes := JSON.stringify(candidate)
  write_raw(bytes)
  store.load_profile()
  check(store.blocked and not store.save_profile() and FileAccess.get_file_as_string(Profile.PATH) == bytes, "invalid field preserved")
 for bytes: String in ["{broken", '{"schema_version":99,"module_id":"apprentice_yokai_king"}']:
  write_raw(bytes)
  store.load_profile()
  check(store.blocked and not store.save_profile() and FileAccess.get_file_as_string(Profile.PATH) == bytes, "corrupt/future exact preservation")
 var candidate: Dictionary = Profile.defaults()
 candidate.discovery.enemy_ids = ["grunt", "grunt"]
 write_raw(JSON.stringify(candidate))
 store.load_profile()
 check(not store.blocked and store.data.discovery.enemy_ids.size() == 1 and not store.warning.is_empty(), "duplicate discovery deduplicated with notice")
 write_raw("external-corruption")
 check(not store.save_profile() and FileAccess.get_file_as_string(Profile.PATH) == "external-corruption", "concurrent corrupt disk not overwritten")
 check(not store.reset_profile(), "reset requires explicit confirmation")
 check(FileAccess.get_file_as_string(Profile.PATH) == "external-corruption", "unconfirmed reset preserves original")
 check(store.reset_profile(true), "explicit reset can recover corrupt profile")
 check(not store.blocked and FileAccess.get_file_as_string(store.last_preserved_path) == "external-corruption", "reset archives original corrupt bytes exactly")
 check(store.data.records.standard.runs_finished == 0 and store.data.records.assist.runs_finished == 0, "reset isolates fresh difficulty records")
 var future_bytes := '{"schema_version":99,"module_id":"apprentice_yokai_king","unknown":{"keep":"exact bytes"}}'
 write_raw(future_bytes)
 store.load_profile()
 check(store.blocked and store.reset_profile(true), "explicit future-schema reset only with confirmation")
 check(FileAccess.get_file_as_string(store.last_preserved_path) == future_bytes, "future archive preserved byte-for-byte")
