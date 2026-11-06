extends RefCounted
## Sprout Tamers - turn-based battle rules (pure logic, no drawing).
## Units: side 0 = your sprouts, side 1 = blight creatures.

const SKILLS = [
	{"n": "Vine Lash", "desc": "Strong hit, heals you a little"},
	{"n": "Splash Wave", "desc": "Hits every enemy"},
	{"n": "Sun Flare", "desc": "Huge single hit"},
]
const SKILL_COST = 3
const MAX_SP = 6

var u: Array = []
var queue: Array = []
var turn: int = 0
var round_no: int = 0
var result: String = ""
var boss: bool = false
var boss_turns: int = 0
var can_flee: bool = true
var rng := RandomNumberGenerator.new()
var level: int = 1

func setup(team: Array, enemies: Array, is_boss: bool) -> void:
	rng.randomize()
	u = []
	boss = is_boss
	can_flee = not is_boss
	for s in team:
		var sd = D.SPROUTS[s["sp"]]
		u.append({"name": sd["n"], "side": 0, "e": sd["e"], "hp": maxi(1, int(s["hp"])), "mhp": G.stat(s, 0),
			"atk": G.stat(s, 1), "def": G.stat(s, 2), "spd": G.stat(s, 3), "sp": 2, "ref": s, "kind": s["sp"],
			"guard": false, "job": sd["job"], "sunny": s["tr"].has("Sunny"), "boss": false})
	for e in enemies:
		u.append(e)
	_new_round()

static func make_enemy(idx: int, lv: int) -> Dictionary:
	var b = D.BLIGHTS[idx]
	var m = 1.0 + 0.16 * (lv - 1)
	var hp = int(b["b"][0] * m)
	return {"name": b["n"], "side": 1, "e": b["e"], "hp": hp, "mhp": hp, "atk": int(b["b"][1] * m), "def": int(b["b"][2] * m),
		"spd": int(b["b"][3] + lv * 0.4), "sp": 0, "ref": null, "kind": idx, "guard": false, "job": "", "sunny": false, "boss": false, "lv": lv}

static func make_boss(season: int, tries: int = 0) -> Dictionary:
	var b = D.BOSSES[season]
	var e = b["e"]
	var hp = int(b["b"][0] * (1.0 - 0.06 * tries))
	return {"name": b["n"], "side": 1, "e": e if e >= 0 else 0, "hp": hp, "mhp": hp, "atk": b["b"][1], "def": b["b"][2],
		"spd": b["b"][3], "sp": 0, "ref": null, "kind": season, "guard": false, "job": "", "sunny": false, "boss": true, "shift": e < 0, "lv": season * 3 + 5}

static func wild_group(season: int, area: int, rng2: RandomNumberGenerator) -> Array:
	var pool = []
	for i in D.BLIGHTS.size():
		if D.BLIGHTS[i]["s"] <= season and D.BLIGHTS[i]["s"] >= season - 1:
			pool.append(i)
	var n = [rng2.randi_range(1, 2), rng2.randi_range(2, 3), 3][area]
	var lv = 1 + season * 3 + int(D.WOODS[area]["lv"])
	var out = []
	for k in n:
		out.append(make_enemy(pool[rng2.randi() % pool.size()], lv + rng2.randi_range(0, 1)))
	return out

func alive(side: int) -> Array:
	var out = []
	for i in u.size():
		if u[i]["side"] == side and u[i]["hp"] > 0:
			out.append(i)
	return out

func _new_round() -> void:
	round_no += 1
	queue = []
	for i in u.size():
		if u[i]["hp"] > 0:
			queue.append(i)
	queue.sort_custom(func(a, b): return u[a]["spd"] > u[b]["spd"])
	turn = 0

func current() -> int:
	while turn < queue.size() and u[queue[turn]]["hp"] <= 0:
		turn += 1
	if turn >= queue.size():
		_new_round()
		return current() if not queue.is_empty() else -1
	return queue[turn]

func start_turn() -> Array:
	## call when a unit's turn begins: guard wears off, SP regenerates, Sunny heals
	var ev = []
	var i = current()
	if i < 0:
		return ev
	var a = u[i]
	a["guard"] = false
	if a["side"] == 0:
		a["sp"] = mini(MAX_SP, a["sp"] + 1)
		if a["sunny"]:
			for j in alive(0):
				var amt = mini(3, u[j]["mhp"] - u[j]["hp"])
				if amt > 0:
					u[j]["hp"] += amt
					ev.append({"t": "heal", "dst": j, "amt": amt})
	if a.get("shift", false):
		a["e"] = (a["e"] + 1) % 3
		ev.append({"t": "msg", "s": "The Hollow Rot shifts to " + D.ELEM[a["e"]] + "!"})
	return ev

func damage(a: Dictionary, d: Dictionary, power: float) -> Dictionary:
	var eff = D.adv(a["e"], d["e"])
	var crit = rng.randf() < 0.08
	var raw = a["atk"] * power * eff * rng.randf_range(0.88, 1.05) * (1.5 if crit else 1.0)
	var dmg = raw * (14.0 / (14.0 + d["def"])) * 1.6
	if d["guard"]:
		dmg *= 0.5
	if d["job"] == "guard":
		dmg *= 0.85
	return {"dmg": maxi(1, int(round(dmg))), "eff": eff, "crit": crit}

func _hit(src: int, dst: int, power: float, ev: Array) -> int:
	var r = damage(u[src], u[dst], power)
	u[dst]["hp"] = maxi(0, u[dst]["hp"] - r["dmg"])
	ev.append({"t": "hit", "src": src, "dst": dst, "dmg": r["dmg"], "eff": r["eff"], "crit": r["crit"]})
	if u[dst]["hp"] <= 0:
		ev.append({"t": "faint", "dst": dst})
	return r["dmg"]

func player_act(action: String, target: int) -> Array:
	var ev = []
	var i = current()
	var a = u[i]
	var foes = alive(1)
	if foes.is_empty():
		return ev
	if not foes.has(target):
		target = foes[0]
	match action:
		"attack":
			ev.append({"t": "msg", "s": a["name"] + " attacks!"})
			_hit(i, target, 1.0, ev)
		"skill":
			if a["sp"] < SKILL_COST:
				return [{"t": "msg", "s": "Not enough SP!", "fail": true}]
			a["sp"] -= SKILL_COST
			var sk = SKILLS[a["e"]]
			ev.append({"t": "msg", "s": a["name"] + " uses " + sk["n"] + "!", "skill": a["e"]})
			match a["e"]:
				0:
					var d = _hit(i, target, 1.5, ev)
					var amt = mini(int(d * 0.35) + 1, a["mhp"] - a["hp"])
					if amt > 0:
						a["hp"] += amt
						ev.append({"t": "heal", "dst": i, "amt": amt})
				1:
					for f in foes:
						_hit(i, f, 0.85, ev)
				2:
					_hit(i, target, 2.0, ev)
		"guard":
			a["guard"] = true
			a["sp"] = mini(MAX_SP, a["sp"] + 1)
			ev.append({"t": "guard", "src": i})
			ev.append({"t": "msg", "s": a["name"] + " braces itself."})
		"tonic":
			if G.items.get("tonic", 0) <= 0:
				return [{"t": "msg", "s": "No Dew Tonics left!", "fail": true}]
			G.items["tonic"] -= 1
			var amt = mini(25, a["mhp"] - a["hp"])
			a["hp"] += amt
			ev.append({"t": "msg", "s": a["name"] + " drinks a Dew Tonic."})
			ev.append({"t": "heal", "dst": i, "amt": amt})
		"flee":
			if not can_flee:
				return [{"t": "msg", "s": "You can't run from a season boss!", "fail": true}]
			if rng.randf() < 0.65:
				ev.append({"t": "msg", "s": "You slipped away into the trees."})
				result = "flee"
				return ev
			ev.append({"t": "msg", "s": "Couldn't get away!"})
	_end_turn()
	return ev

func enemy_act() -> Array:
	var ev = []
	var i = current()
	var a = u[i]
	var mine = alive(0)
	if mine.is_empty():
		return ev
	var target = mine[rng.randi() % mine.size()]
	if rng.randf() < 0.45:
		for j in mine:
			if u[j]["hp"] < u[target]["hp"]:
				target = j
	if a["boss"]:
		boss_turns += 1
		if boss_turns % 3 == 0:
			ev.append({"t": "msg", "s": a["name"] + " unleashes a Blight Surge!", "surge": true})
			for j in mine:
				_hit(i, j, 0.75, ev)
			_end_turn()
			return ev
	ev.append({"t": "msg", "s": a["name"] + " strikes!"})
	_hit(i, target, 1.0, ev)
	_end_turn()
	return ev

func _end_turn() -> void:
	if alive(1).is_empty():
		result = "win"
	elif alive(0).is_empty():
		result = "lose"
	turn += 1

func rewards() -> Dictionary:
	var gold = 0
	var xp = 0
	for x in u:
		if x["side"] == 1:
			gold += 8 + int(x.get("lv", 1)) * 4 + (120 if x["boss"] else 0)
			xp += 5 + int(x.get("lv", 1)) * 3 + (40 if x["boss"] else 0)
	return {"gold": gold, "xp": xp}

func auto_play(max_steps: int = 400) -> String:
	## used by the smoke test: simple AI plays both sides until the battle ends
	var steps = 0
	while result == "" and steps < max_steps:
		start_turn()
		var i = current()
		if i < 0:
			break
		if u[i]["side"] == 0:
			var foes = alive(1)
			var act = "skill" if u[i]["sp"] >= SKILL_COST else "attack"
			player_act(act, foes[0])
		else:
			enemy_act()
		steps += 1
	return result

func sync_back() -> void:
	## copy battle hp back to the sprout records
	for x in u:
		if x["side"] == 0 and x["ref"] != null:
			x["ref"]["hp"] = maxi(1, x["hp"]) if result == "win" else x["ref"]["hp"]
