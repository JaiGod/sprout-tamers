extends Node
## Sprout Tamers - farm simulation, sprouts, breeding and saving. Autoloaded as "G".

const SAVE_PATH = "user://sprouttamers.save"
const CFG_PATH = "user://sprouttamers.cfg"
const MAX_SPROUTS = 8
const COLS = 7

var season: int = 0
var day: int = 1
var dayno: int = 0
var gold: int = 0
var energy: int = 0
var max_energy: int = 16
var hearts: int = 3
var rows: int = 4
var farm: Array = []
var seeds: Array = []
var bag: Array = []
var items: Dictionary = {}
var sprouts: Array = []
var upgrades: Dictionary = {}
var vhearts: Array = [0, 0, 0, 0]
var request: Dictionary = {}
var found: Array = []
var harvested_season: int = 0
var harvested_total: int = 0
var battles_won: int = 0
var bosses: int = 0
var bred_day: int = -1
var talked: Array = [-1, -1, -1, -1]
var next_id: int = 1
var ribbons: Array = []
var sound_on: bool = true
var best: Dictionary = {"found": 0, "bosses": 0, "wins": 0}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load_cfg()
	reset()

func reset() -> void:
	season = 0
	day = 1
	dayno = 0
	gold = 120
	max_energy = 16
	energy = max_energy
	hearts = 3
	rows = 4
	farm = []
	for i in rows * COLS:
		farm.append(_empty_tile())
	seeds = []
	bag = []
	for i in D.CROPS.size():
		seeds.append(0)
		bag.append(0)
	seeds[0] = 4
	seeds[2] = 4
	items = {"tonic": 2, "nectar": 1, "compost": 0}
	sprouts = []
	upgrades = {}
	vhearts = [0, 0, 0, 0]
	request = {}
	found = []
	for i in D.SPROUTS.size():
		found.append(false)
	harvested_season = 0
	harvested_total = 0
	battles_won = 0
	bosses = 0
	bred_day = -1
	talked = [-1, -1, -1, -1]
	next_id = 1
	ribbons = []

func new_game() -> void:
	reset()
	# a few pre-tilled plots so the first morning has something to do
	for i in [8, 9, 10, 15, 16, 17]:
		farm[i]["t"] = true
	var s = make_sprout(1, ["Cheery", "Green Thumb"], 1, 1)
	s["fr"] = 4
	add_sprout(s)
	_new_request()

func _empty_tile() -> Dictionary:
	return {"t": false, "c": -1, "g": 0, "w": false, "dead": false}

# ------------------------------------------------------------------ sprouts
func make_sprout(sp: int, traits = null, pot: int = -1, gen: int = 1) -> Dictionary:
	var tr: Array = []
	if traits == null:
		var keys = D.TRAITS.keys()
		while tr.size() < 2:
			var k = keys[rng.randi() % keys.size()]
			if not tr.has(k):
				tr.append(k)
	else:
		tr = traits.duplicate()
	if pot < 0:
		pot = rng.randi_range(0, 2)
	var s = {"id": next_id, "sp": sp, "lv": 1, "xp": 0, "hp": 0, "fr": 2, "tr": tr, "pot": pot, "gen": gen, "pet": -1, "team": true}
	next_id += 1
	s["hp"] = stat(s, 0)
	return s

func add_sprout(s: Dictionary) -> void:
	var on_team = 0
	for o in sprouts:
		if o["team"]:
			on_team += 1
	s["team"] = on_team < 3
	sprouts.append(s)
	found[s["sp"]] = true
	best["found"] = maxi(int(best["found"]), found.count(true))
	save_cfg()

func stat(s: Dictionary, k: int) -> int:
	var b: int = D.SPROUTS[s["sp"]]["b"][k]
	var lv: int = s["lv"]
	var pot: int = s["pot"]
	var tr: Array = s["tr"]
	var v: float
	if k == 0:
		v = b + lv * 4 + pot * 2 + (10 if tr.has("Hearty") else 0)
	else:
		v = b + (lv - 1) * (1.4 if k != 3 else 1.0) + pot * 0.6
		if k == 1 and tr.has("Fierce"):
			v += 3
		if k == 2 and tr.has("Sturdy"):
			v += 3
		if k == 3 and tr.has("Swift"):
			v += 3
	return int(v)

func xp_next(s: Dictionary) -> int:
	return 10 + int(s["lv"]) * 8

func gain_xp(s: Dictionary, amt: int) -> bool:
	var up = false
	s["xp"] += amt
	while s["xp"] >= xp_next(s) and s["lv"] < 30:
		s["xp"] -= xp_next(s)
		s["lv"] += 1
		up = true
	if up:
		s["hp"] = stat(s, 0)
	return up

func befriend(s: Dictionary, amt: int) -> void:
	if s["tr"].has("Cheery"):
		amt += 1
	s["fr"] = clampi(int(s["fr"]) + amt, 0, 10)

func team() -> Array:
	var out = []
	for s in sprouts:
		if s["team"] and out.size() < 3:
			out.append(s)
	if out.is_empty() and not sprouts.is_empty():
		out.append(sprouts[0])
	return out

func sp_name(s: Dictionary) -> String:
	return D.SPROUTS[s["sp"]]["n"]

func can_breed(s: Dictionary) -> bool:
	return int(s["fr"]) >= 6

func breed(a: Dictionary, b: Dictionary) -> Dictionary:
	## child takes the species of a random parent, one trait from each parent, and better potential
	var sp = a["sp"] if rng.randf() < 0.5 else b["sp"]
	var ta: Array = a["tr"]
	var tb: Array = b["tr"]
	var t1 = ta[rng.randi() % ta.size()]
	var t2 = tb[rng.randi() % tb.size()]
	var keys = D.TRAITS.keys()
	if t2 == t1:
		for t in tb + ta:
			if t != t1:
				t2 = t
				break
	var mutated = false
	if rng.randf() < 0.2 or t2 == t1:
		var k = keys[rng.randi() % keys.size()]
		while k == t1:
			k = keys[rng.randi() % keys.size()]
		t2 = k
		mutated = true
	var pot = mini(9, int((int(a["pot"]) + int(b["pot"])) / 2.0 + 0.5) + 1)
	var c = make_sprout(sp, [t1, t2], pot, maxi(int(a["gen"]), int(b["gen"])) + 1)
	c["fr"] = 4
	c["mut"] = mutated
	bred_day = dayno
	befriend(a, -1)
	befriend(b, -1)
	return c

# ------------------------------------------------------------------ farming
func tile_state(i: int) -> String:
	var t = farm[i]
	if not t["t"]:
		return "wild"
	if t["dead"]:
		return "dead"
	if t["c"] < 0:
		return "tilled"
	if t["g"] >= D.CROPS[t["c"]]["d"]:
		return "ripe"
	return "growing"

func act_tile(i: int, seed: int) -> Dictionary:
	## the one contextual farm action: till -> plant -> water -> harvest
	var t = farm[i]
	var st = tile_state(i)
	match st:
		"wild":
			if energy < 1:
				return {"ok": false, "msg": "Too tired. Sleep to restore energy."}
			energy -= 1
			t["t"] = true
			return {"ok": true, "fx": "till", "msg": ""}
		"dead":
			t["dead"] = false
			t["c"] = -1
			t["g"] = 0
			return {"ok": true, "fx": "till", "msg": "Cleared the wilted plant."}
		"tilled":
			if seed < 0 or seeds[seed] <= 0:
				return {"ok": false, "msg": "No seeds selected. Buy some at Tilly's market."}
			if D.CROPS[seed]["s"] != season:
				return {"ok": false, "msg": D.CROPS[seed]["n"] + " only grows in " + D.SEASONS[D.CROPS[seed]["s"]] + "."}
			seeds[seed] -= 1
			t["c"] = seed
			t["g"] = 0
			t["w"] = false
			return {"ok": true, "fx": "plant", "msg": ""}
		"growing":
			if t["w"]:
				return {"ok": false, "msg": "Already watered today."}
			if not upgrades.has("can"):
				if energy < 1:
					return {"ok": false, "msg": "Too tired. Sleep to restore energy."}
				energy -= 1
			t["w"] = true
			return {"ok": true, "fx": "water", "msg": ""}
		"ripe":
			var c = t["c"]
			harvest(i)
			return {"ok": true, "fx": "harvest", "crop": c, "msg": "+1 " + D.CROPS[c]["n"]}
	return {"ok": false, "msg": ""}

func harvest(i: int, amount: int = 1) -> void:
	var t = farm[i]
	bag[t["c"]] += amount
	harvested_season += amount
	harvested_total += amount
	t["c"] = -1
	t["g"] = 0
	t["w"] = false

func use_compost() -> bool:
	if items["compost"] <= 0:
		return false
	items["compost"] -= 1
	for t in farm:
		if t["c"] >= 0 and not t["dead"]:
			t["g"] = mini(t["g"] + 1, D.CROPS[t["c"]]["d"])
	return true

func expand() -> void:
	rows += 1
	for i in COLS:
		farm.append(_empty_tile())

func working(job: String) -> Array:
	var out = []
	for s in sprouts:
		if D.SPROUTS[s["sp"]]["job"] == job and int(s["fr"]) >= 3:
			out.append(s)
	return out

func night() -> Array:
	## growth + blight mites. Returns lg lines.
	var lg: Array = []
	for t in farm:
		if t["c"] >= 0 and not t["dead"]:
			if t["w"]:
				t["g"] = mini(t["g"] + 1, D.CROPS[t["c"]]["d"])
			t["w"] = false
	var chance = 0.3 + 0.06 * season
	if upgrades.has("ward"):
		chance *= 0.5
	var guards = working("guard")
	for g in guards:
		chance -= 0.1 + (0.06 if g["tr"].has("Watchful") else 0.0)
	var growing = []
	for i in farm.size():
		if tile_state(i) == "growing":
			growing.append(i)
	if not growing.is_empty():
		if rng.randf() < maxf(chance, 0.04):
			var i = growing[rng.randi() % growing.size()]
			farm[i]["dead"] = true
			lg.append("Blight mites wilted a " + D.CROPS[farm[i]["c"]]["n"] + " in the night!")
		elif not guards.is_empty() and rng.randf() < 0.5:
			lg.append(sp_name(guards[0]) + " chased off blight mites in the night.")
	return lg

func morning() -> Array:
	## new day: sprouts do their jobs, crop combos attract new sprouts.
	var lg: Array = []
	dayno += 1
	energy = max_energy
	for s in sprouts:
		s["hp"] = stat(s, 0)
	# green thumb
	for s in sprouts:
		if s["tr"].has("Green Thumb") and int(s["fr"]) >= 3:
			var cand = []
			for i in farm.size():
				if tile_state(i) == "growing":
					cand.append(i)
			if not cand.is_empty():
				var i = cand[rng.randi() % cand.size()]
				farm[i]["g"] += 1
	# waterers
	var wcount = 0
	for s in working("water"):
		var n = 3 + (2 if s["tr"].has("Dewy") else 0) + int(s["lv"]) / 5
		for i in farm.size():
			if n <= 0:
				break
			if tile_state(i) == "growing" and not farm[i]["w"]:
				farm[i]["w"] = true
				n -= 1
				wcount += 1
	if wcount > 0:
		lg.append("Your waterers watered %d plots." % wcount)
	# harvesters (leave combos standing unless the field is full of ripe crops)
	var hcount = 0
	for s in working("harvest"):
		var n = 2 + int(s["lv"]) / 6
		for i in range(farm.size() - 1, -1, -1):
			if n <= 0:
				break
			if tile_state(i) == "ripe" and not _in_combo(i):
				var amt = 2 if (s["tr"].has("Lucky") and rng.randf() < 0.5) else 1
				harvest(i, amt)
				hcount += amt
				n -= 1
	if hcount > 0:
		lg.append("Your harvesters gathered %d crops." % hcount)
	# combos
	var arrived = check_combos()
	if not arrived.is_empty():
		lg.append(arrived["msg"])
	if request.is_empty() or request.get("done", false):
		_new_request()
	return lg

func _in_combo(i: int) -> bool:
	var c = farm[i]["c"]
	for j in _nbrs(i):
		if tile_state(j) == "ripe" and D.combo_for(c, farm[j]["c"], season) >= 0:
			return true
	return false

func _nbrs(i: int) -> Array:
	var out = []
	var x = i % COLS
	var y = i / COLS
	if x > 0:
		out.append(i - 1)
	if x < COLS - 1:
		out.append(i + 1)
	if y > 0:
		out.append(i - COLS)
	if y < rows - 1:
		out.append(i + COLS)
	return out

func combos_now() -> Array:
	## [sprout id, tile a, tile b] for every ripe neighbouring pair that forms a combo
	var out = []
	for i in farm.size():
		if tile_state(i) != "ripe":
			continue
		for j in _nbrs(i):
			if j > i and tile_state(j) == "ripe":
				var sp = D.combo_for(farm[i]["c"], farm[j]["c"], season)
				if sp >= 0:
					out.append([sp, i, j])
	return out

func check_combos() -> Dictionary:
	if sprouts.size() >= MAX_SPROUTS:
		return {}
	var combos = combos_now()
	if combos.is_empty():
		return {}
	combos.shuffle()
	for c in combos:
		if not found[c[0]]:
			var s = make_sprout(c[0])
			add_sprout(s)
			return {"sprout": s, "msg": "A wild %s was drawn to your %s and %s! It moved in." % [sp_name(s), D.CROPS[farm[c[1]]["c"]]["n"], D.CROPS[farm[c[2]]["c"]]["n"]], "new": true}
	if rng.randf() < 0.3:
		var s = make_sprout(combos[0][0])
		add_sprout(s)
		return {"sprout": s, "msg": "Another %s wandered in with new traits!" % sp_name(s), "new": false}
	return {}

func sleep_is_boss() -> bool:
	return day >= D.DAYS_PER_SEASON

func next_day() -> Array:
	var lg = night()
	day += 1
	lg.append_array(morning())
	save_game()
	return lg

func boss_lost() -> Array:
	hearts -= 1
	var lg = ["The blight tore a Heartroot from your farm. (%d left)" % hearts]
	if hearts > 0:
		lg.append_array(night())
		lg.append_array(morning())
		lg.append("It will return tonight. Prepare your sprouts!")
		save_game()
	else:
		delete_save()
	return lg

func festival_score() -> int:
	var fr = 0
	for s in sprouts:
		fr += int(s["fr"])
	var vh = 0
	for v in vhearts:
		vh += int(v)
	return harvested_season * 2 + fr + vh * 2 + sprouts.size() * 3

func ribbon_for(score: int) -> int:
	if score >= 70:
		return 0
	if score >= 40:
		return 1
	return 2

func begin_season(next: int) -> Array:
	var lg = []
	season = next
	day = 1
	harvested_season = 0
	var lost = 0
	for t in farm:
		if t["c"] >= 0 and D.CROPS[t["c"]]["s"] != season:
			t["c"] = -1
			t["g"] = 0
			t["w"] = false
			t["dead"] = false
			lost += 1
	if lost > 0:
		lg.append("%d out-of-season crops returned to the soil." % lost)
	lg.append_array(morning())
	_new_request()
	save_game()
	return lg

# ------------------------------------------------------------------ town
func _new_request() -> void:
	var opts = []
	for i in D.CROPS.size():
		if D.CROPS[i]["s"] == season:
			opts.append(i)
	var c = opts[rng.randi() % opts.size()]
	var q = rng.randi_range(2, 4)
	request = {"v": rng.randi() % 4, "crop": c, "qty": q, "gold": int(D.CROPS[c]["v"] * q * 1.6), "done": false}

func fill_request() -> bool:
	if request.is_empty() or request["done"]:
		return false
	if bag[request["crop"]] < request["qty"]:
		return false
	bag[request["crop"]] -= request["qty"]
	gold += request["gold"]
	vhearts[request["v"]] = mini(10, vhearts[request["v"]] + 2)
	request["done"] = true
	return true

func sell_all() -> int:
	var total = 0
	for i in bag.size():
		total += bag[i] * int(D.CROPS[i]["v"])
		bag[i] = 0
	gold += total
	return total

func bag_count() -> int:
	var n = 0
	for v in bag:
		n += v
	return n

func buy_seed(c: int, n: int = 1) -> bool:
	var cost = int(D.CROPS[c]["c"]) * n
	if gold < cost:
		return false
	gold -= cost
	seeds[c] += n
	return true

func buy_item(k: String) -> bool:
	if gold < int(D.ITEMS[k]["c"]):
		return false
	gold -= int(D.ITEMS[k]["c"])
	items[k] += 1
	return true

func buy_upgrade(u: Dictionary) -> String:
	if upgrades.has(u["id"]) and not u.get("repeat", false):
		return "Already built."
	if u.has("need") and not upgrades.has(u["need"]):
		return "Build the first expansion first."
	if u["id"] == "heart" and hearts >= 3:
		return "Your Heartroots are healthy."
	if gold < int(u["c"]):
		return "Not enough gold."
	gold -= int(u["c"])
	match u["id"]:
		"row1", "row2":
			expand()
		"heart":
			hearts += 1
	if not u.get("repeat", false):
		upgrades[u["id"]] = true
	return "ok"

# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	return {"v": 1, "season": season, "day": day, "dayno": dayno, "gold": gold, "energy": energy, "hearts": hearts, "rows": rows,
		"farm": farm, "seeds": seeds, "bag": bag, "items": items, "sprouts": sprouts, "upgrades": upgrades, "vhearts": vhearts,
		"request": request, "found": found, "hs": harvested_season, "ht": harvested_total, "bw": battles_won, "bosses": bosses,
		"bred": bred_day, "talked": talked, "next_id": next_id, "ribbons": ribbons}

func from_dict(d: Dictionary) -> void:
	reset()
	season = int(d["season"])
	day = int(d["day"])
	dayno = int(d["dayno"])
	gold = int(d["gold"])
	energy = int(d["energy"])
	hearts = int(d["hearts"])
	rows = int(d["rows"])
	farm = []
	for t in d["farm"]:
		farm.append({"t": bool(t["t"]), "c": int(t["c"]), "g": int(t["g"]), "w": bool(t["w"]), "dead": bool(t["dead"])})
	seeds = []
	for v in d["seeds"]:
		seeds.append(int(v))
	bag = []
	for v in d["bag"]:
		bag.append(int(v))
	items = {}
	for k in d["items"]:
		items[k] = int(d["items"][k])
	sprouts = []
	for s in d["sprouts"]:
		var n = {}
		for k in s:
			n[k] = s[k]
		for k in ["id", "sp", "lv", "xp", "hp", "fr", "pot", "gen", "pet"]:
			n[k] = int(n.get(k, 0))
		n["tr"] = Array(s["tr"])
		n["team"] = bool(s.get("team", true))
		sprouts.append(n)
	upgrades = d["upgrades"]
	vhearts = []
	for v in d["vhearts"]:
		vhearts.append(int(v))
	request = {}
	for k in d["request"]:
		request[k] = d["request"][k]
	for k in ["v", "crop", "qty", "gold"]:
		if request.has(k):
			request[k] = int(request[k])
	found = []
	for v in d["found"]:
		found.append(bool(v))
	harvested_season = int(d["hs"])
	harvested_total = int(d["ht"])
	battles_won = int(d["bw"])
	bosses = int(d["bosses"])
	bred_day = int(d["bred"])
	talked = []
	for v in d["talked"]:
		talked.append(int(v))
	next_id = int(d["next_id"])
	ribbons = []
	for v in d["ribbons"]:
		ribbons.append(int(v))

func save_game() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))
		f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("farm"):
		return false
	from_dict(d)
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func save_cfg() -> void:
	var f = FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"sound": sound_on, "best": best}))
		f.close()

func _load_cfg() -> void:
	if not FileAccess.file_exists(CFG_PATH):
		return
	var f = FileAccess.open(CFG_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		sound_on = bool(d.get("sound", true))
		if d.has("best"):
			for k in d["best"]:
				best[k] = int(d["best"][k])
