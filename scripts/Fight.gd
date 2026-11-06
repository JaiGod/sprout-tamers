extends RefCounted
## Sprout Tamers - battle screen: plays battle events with juice and takes player input.

const Battle = preload("res://scripts/Battle.gd")

var m
var b = null
var events: Array = []
var cur = null
var ev_t: float = 0.0
var waiting: bool = false
var target: int = -1
var msg: String = ""
var anim: Dictionary = {}
var is_boss: bool = false
var area: int = 0
var done: Dictionary = {}

func _init(main) -> void:
	m = main

func start_wild(a: int) -> void:
	area = a
	is_boss = false
	b = Battle.new()
	b.setup(G.team(), Battle.wild_group(G.season, a, G.rng), false)
	_begin("Blight creatures leap out of the " + D.WOODS[a]["n"] + "!", "battle")

func start_boss() -> void:
	is_boss = true
	b = Battle.new()
	for s in G.team():
		s["hp"] = G.stat(s, 0)
	b.setup(G.team(), [Battle.make_boss(G.season, 3 - G.hearts)], true)
	_begin(D.BOSSES[G.season]["n"] + " attacks the farm!", "boss")

func _begin(text: String, music: String) -> void:
	m.go("battle")
	Sfx.play_music(music)
	Sfx.play("encounter")
	m.shake = 4.0
	events = [{"t": "msg", "s": text}]
	cur = null
	waiting = false
	done = {}
	anim = {}
	target = -1
	msg = ""

func auto_finish() -> void:
	if b == null or not done.is_empty():
		return
	b.auto_play()
	events = []
	cur = null
	waiting = false

# ------------------------------------------------------------------ flow
func update(delta: float) -> void:
	for k in anim:
		var a = anim[k]
		for f in a:
			a[f] = maxf(0.0, a[f] - delta)
	if not done.is_empty() or b == null:
		return
	if cur != null:
		ev_t -= delta
		if ev_t <= 0:
			cur = null
		return
	if not events.is_empty():
		cur = events.pop_front()
		ev_t = _show(cur)
		return
	if waiting:
		return
	if b.result != "":
		_finish()
		return
	var evs = b.start_turn()
	var i = b.current()
	if i < 0:
		return
	if b.u[i]["side"] == 1:
		evs.append_array(b.enemy_act())
	else:
		waiting = true
		msg = "What will %s do?" % b.u[i]["name"]
		var foes = b.alive(1)
		if not foes.has(target) and not foes.is_empty():
			target = foes[0]
	events.append_array(evs)

func _an(i: int) -> Dictionary:
	if not anim.has(i):
		anim[i] = {"lunge": 0.0, "flash": 0.0, "faint": 0.0, "glow": 0.0}
	return anim[i]

func _show(e: Dictionary) -> float:
	match e["t"]:
		"msg":
			msg = e["s"]
			if e.has("skill"):
				var i = b.current()
				_an(i)["glow"] = 0.5
				m.burst(unit_pos(i), D.ELEM_COL[e["skill"]], 16, 60, -20)
				Sfx.play("buff")
			if e.get("surge", false):
				m.shake = 6.0
				Sfx.play("debuff")
			return 0.75 if e.has("skill") or e.get("surge", false) else 0.6
		"hit":
			_an(e["src"])["lunge"] = 0.25
			_an(e["dst"])["flash"] = 0.3
			var p = unit_pos(e["dst"])
			m.float_text(p + Vector2(0, -34), str(e["dmg"]) + ("!" if e["crit"] else ""), Color("ffe27a") if e["eff"] > 1 else Color.WHITE)
			if e["eff"] > 1:
				m.float_text(p + Vector2(0, -46), "Super effective!", Color("ffb03a"))
				Sfx.play("super")
			elif e["eff"] < 1:
				m.float_text(p + Vector2(0, -46), "Not very effective", Color("a0b0c0"))
				Sfx.play("weak")
			else:
				Sfx.play("hit")
			m.shake = 5.0 if e["crit"] else 2.5
			m.burst(p + Vector2(0, -14), Color("d070ff") if b.u[e["src"]]["side"] == 1 else D.ELEM_COL[b.u[e["src"]]["e"]], 12, 70)
			return 0.5
		"heal":
			m.float_text(unit_pos(e["dst"]) + Vector2(0, -36), "+%d" % e["amt"], Color("8affa0"))
			m.burst(unit_pos(e["dst"]) + Vector2(0, -12), Color("8affa0"), 8, 30, -40)
			Sfx.play("heal")
			return 0.4
		"guard":
			_an(e["src"])["glow"] = 0.5
			Sfx.play("buff")
			return 0.3
		"faint":
			_an(e["dst"])["faint"] = 0.6
			Sfx.play("faint")
			m.burst(unit_pos(e["dst"]) + Vector2(0, -12), Color("3a1a3a") if b.u[e["dst"]]["side"] == 1 else Color("ffffff"), 18, 80)
			return 0.55
	return 0.2

func act(action: String) -> void:
	if not waiting or cur != null or not events.is_empty() or not done.is_empty():
		return
	var evs = b.player_act(action, target)
	if not evs.is_empty() and evs[0].get("fail", false):
		msg = evs[0]["s"]
		Sfx.play("bump")
		return
	waiting = false
	events.append_array(evs)

func _finish() -> void:
	var lines = []
	var title = ""
	var team = []
	for x in b.u:
		if x["side"] == 0:
			team.append(x)
	match b.result:
		"win":
			title = "Victory!"
			var rw = b.rewards()
			G.gold += rw["gold"]
			G.battles_won += 1
			lines.append("+%d gold   +%d XP each" % [rw["gold"], rw["xp"]])
			b.sync_back()
			for x in team:
				var s = x["ref"]
				G.befriend(s, 1)
				if G.gain_xp(s, rw["xp"]):
					lines.append("%s grew to Lv %d!" % [x["name"], s["lv"]])
					Sfx.play("level")
			var opts = m.season_seeds()
			var c = opts[G.rng.randi() % opts.size()]
			var n = G.rng.randi_range(1, 2)
			G.seeds[c] += n
			lines.append("Found %d %s seeds in the brush." % [n, D.CROPS[c]["n"]])
			if is_boss:
				G.bosses += 1
				G.best["bosses"] = maxi(int(G.best["bosses"]), G.bosses)
				G.save_cfg()
				lines.append("The season's blight is broken!")
			Sfx.play_music("victory")
		"lose":
			title = "Defeated..."
			for x in team:
				x["ref"]["hp"] = 1
			if is_boss:
				lines.append_array(G.boss_lost())
			else:
				lines.append("Your sprouts limped home to rest.")
			Sfx.play_music("")
			Sfx.play("faint")
		"flee":
			title = "Escaped!"
			for x in team:
				x["ref"]["hp"] = maxi(1, x["hp"])
			lines.append("You made it back to the trail.")
	done = {"title": title, "lines": lines}

func press(id: String) -> void:
	match id:
		"attack", "skill", "guard", "tonic", "flee":
			act(id)
		"done":
			var res = b.result
			if res == "win" and is_boss:
				m.open_festival()
			elif res == "lose" and is_boss:
				if G.hearts <= 0:
					m.go("lose")
				else:
					m.go("farm")
					m.toast("The blight will return tonight. Train in the woods and try again!", 5)
			elif is_boss:
				m.go("farm")
			else:
				m.go("woods")
				G.save_game()
		_:
			if id.begins_with("t"):
				target = int(id.substr(1))

func key(k: int) -> void:
	if not done.is_empty():
		if k in [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			press("done")
		return
	match k:
		KEY_1, KEY_Z: act("attack")
		KEY_2, KEY_X: act("skill")
		KEY_3, KEY_G: act("guard")
		KEY_4, KEY_T: act("tonic")
		KEY_5, KEY_R: act("flee")
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_TAB, KEY_A, KEY_D:
			var foes = b.alive(1)
			if foes.is_empty():
				return
			var j = foes.find(target)
			var dir = -1 if k in [KEY_LEFT, KEY_UP, KEY_A] else 1
			target = foes[(j + dir + foes.size()) % foes.size()]
			Sfx.play("blip")

func click(p: Vector2) -> void:
	if b == null:
		return
	for i in b.alive(1):
		if unit_pos(i).distance_to(p + Vector2(0, 16)) < 26:
			target = i
			Sfx.play("blip")

# ------------------------------------------------------------------ drawing
func unit_pos(i: int) -> Vector2:
	var x = b.u[i]
	var side: int = x["side"]
	var idx = 0
	var n = 0
	for j in b.u.size():
		if b.u[j]["side"] == side:
			if j < i:
				idx += 1
			n += 1
	var W = m.W
	var H = m.H
	if m.landscape():
		var top = 50.0
		var bot = H - 80.0
		var y = top + (bot - top) * (idx + 1) / (n + 1) + 16
		var xx = W * (0.26 if side == 0 else 0.72) + [0, -46, 46][idx % 3] * (1 if side == 0 else -1)
		return Vector2(xx, y)
	var yy = H * (0.58 if side == 0 else 0.34)
	return Vector2(W * (idx + 1) / (n + 1), yy + (idx % 2) * 12)

func draw() -> void:
	var W = m.W
	var H = m.H
	if b == null:
		return
	# backdrop
	if is_boss:
		m.draw_rect(Rect2(0, 0, W, H), Color("2a1a3a"))
		m.draw_rect(Rect2(0, 0, W, H * 0.4), Color("4a1a3a"))
		m.draw_circle(Vector2(W * 0.82, 40), 16, Color("ff9a7a", 0.7))
		m.grass(Rect2(0, H * 0.4, W, H * 0.6), G.season)
		m.draw_rect(Rect2(0, H * 0.4, W, H * 0.6), Color(0.15, 0.02, 0.2, 0.5))
		for x in range(0, int(W), 14):
			m.draw_rect(Rect2(x, H * 0.4 - 6, 3, 14), Color("4a2e1e"))
		m.draw_rect(Rect2(0, H * 0.4 - 2, W, 2), Color("4a2e1e"))
	else:
		m.draw_rect(Rect2(0, 0, W, H), Color("16301e"))
		m.grass(Rect2(0, H * 0.35, W, H * 0.65), G.season)
		m.draw_rect(Rect2(0, H * 0.35, W, H * 0.65), Color(0.0, 0.1, 0.05, 0.45))
		for i in 12:
			m.spr_feet(Art.tree(G.season, i % 2), Vector2(fmod(i * 47.0, W + 20) - 10, H * 0.35 + (i % 3) * 6), 1.5, false, Color(0.5, 0.65, 0.55))
	for i in 16:
		var p = Vector2(fmod(i * 83.0 + m.t * 9, W), fmod(i * 41.0 + sin(m.t + i) * 9, H))
		m.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(0.8, 0.5, 1.0, 0.35) if is_boss else Color(0.9, 1, 0.6, 0.35))
	# units
	var curi = b.current() if b.result == "" else -1
	for i in b.u.size():
		_draw_unit(i, curi)
	_draw_panel()
	if not done.is_empty():
		_draw_done()

func _draw_unit(i: int, curi: int) -> void:
	var x = b.u[i]
	var a = _an(i)
	var p = unit_pos(i)
	var dead = x["hp"] <= 0
	if dead and a["faint"] <= 0:
		return
	var side: int = x["side"]
	var off = Vector2.ZERO
	if a["lunge"] > 0:
		off.x = sin(a["lunge"] / 0.25 * PI) * (14 if side == 0 else -14) * (1 if m.landscape() else 0)
		off.y = sin(a["lunge"] / 0.25 * PI) * (0 if m.landscape() else (-12 if side == 0 else 12))
	var mod = Color.WHITE
	if a["flash"] > 0 and int(a["flash"] * 30) % 2 == 0:
		mod = Color(3, 3, 3)
	if dead:
		mod = Color(1, 1, 1, a["faint"] / 0.6)
	var bob = sin(m.t * 3 + i) * 1.5
	var tex
	var sc = 2.0
	if side == 0:
		tex = Art.sprout(x["kind"])
	else:
		tex = Art.blight(x["kind"], x["boss"])
		sc = 2.4 if x["boss"] else 1.9
	if a["glow"] > 0:
		m.draw_circle(p + off + Vector2(0, -16), 20, Color(D.ELEM_COL[clampi(x["e"], 0, 2)].r, D.ELEM_COL[clampi(x["e"], 0, 2)].g, D.ELEM_COL[clampi(x["e"], 0, 2)].b, a["glow"]))
	if x["guard"] and not dead:
		m.draw_arc(p + Vector2(0, -16), 20, 0, TAU, 20, Color("9fd0ff", 0.7), 2)
	m.spr_feet(tex, p + off + Vector2(0, bob), sc, side == 1, mod, sin(m.t * 5 + i) * 0.03)
	if dead:
		return
	# label + hp
	var h = tex.get_size().y * sc
	var ly = p.y + 8
	var w = 54.0
	var lx = p.x - w / 2
	m.draw_rect(Rect2(lx - 2, ly - 1, w + 4, 22 if side == 0 else 16), Color(0, 0, 0, 0.45))
	m.draw_circle(Vector2(lx + 3, ly + 5), 2.5, D.ELEM_COL[clampi(x["e"], 0, 2)])
	m.txt(Vector2(lx + 8, ly + 8), x["name"], 8, Color.WHITE)
	m.bar(Rect2(lx, ly + 10, w, 5), float(x["hp"]) / x["mhp"], Color("7fe05a") if x["hp"] > x["mhp"] * 0.3 else Color("ff6a4a"))
	if side == 0:
		for k in Battle.MAX_SP:
			m.draw_rect(Rect2(lx + k * 7, ly + 17, 5, 3), Color("ffd34a") if k < x["sp"] else Color("4a4030"))
		m.txt(Vector2(lx + w, ly + 21), "%d/%d" % [x["hp"], x["mhp"]], 7, Color.WHITE, 2)
	if i == curi and waiting:
		var ay = p.y - h - 6 + sin(m.t * 8) * 2
		m.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 4, ay), Vector2(p.x + 4, ay), Vector2(p.x, ay + 5)]), Color("ffe27a"))
	if side == 1 and i == target and waiting:
		var r = Rect2(p.x - 18, p.y - h - 2, 36, h + 6)
		var c = Color("ff6a5a", 0.6 + 0.4 * sin(m.t * 8))
		for corner in [r.position, Vector2(r.end.x - 6, r.position.y), Vector2(r.position.x, r.end.y - 6), r.end - Vector2(6, 6)]:
			m.draw_rect(Rect2(corner, Vector2(6, 6)), c, false, 1.5)

func _draw_panel() -> void:
	var W = m.W
	var H = m.H
	var ls = m.landscape()
	var ph = 62.0 if ls else 118.0
	var r = Rect2(6, H - ph - 6, W - 12, ph)
	m.panel(r)
	m.para(Rect2(r.position.x + 10, r.position.y + 4, r.size.x - 20, 24), msg, 9, m.UI_INK, 2)
	if not waiting or cur != null or not events.is_empty() or not done.is_empty():
		return
	var x = b.u[b.current()]
	var sk = Battle.SKILLS[x["e"]]
	var acts = [["Attack [1]", "attack", Color("f0e0a0"), true],
		[sk["n"] + " 3SP [2]", "skill", D.ELEM_COL[x["e"]], x["sp"] >= Battle.SKILL_COST],
		["Guard [3]", "guard", Color("9fd0ff"), true],
		["Tonic x%d [4]" % G.items.get("tonic", 0), "tonic", Color("8affa0"), G.items.get("tonic", 0) > 0 and x["hp"] < x["mhp"]],
		["Flee [5]", "flee", Color("e8b8a0"), b.can_flee]]
	if ls:
		var bw = (r.size.x - 20 - 16) / 5.0
		for k in acts.size():
			m.btn(Rect2(r.position.x + 10 + k * (bw + 4), r.end.y - 28, bw, 22), acts[k][0], "F:" + acts[k][1], acts[k][3], acts[k][2], 8, false)
	else:
		var bw = (r.size.x - 20 - 8) / 3.0
		for k in acts.size():
			acts[k][0] = acts[k][0].split(" [")[0].replace(" 3SP", "")
			m.btn(Rect2(r.position.x + 10 + (k % 3) * (bw + 4), r.position.y + 36 + (k / 3) * 38, bw, 32), acts[k][0], "F:" + acts[k][1], acts[k][3], acts[k][2], 9, false)
	if not m.narrow():
		m.txt(Vector2(r.end.x - 10, r.position.y + 14), sk["desc"], 7, Color("7a6a5a"), 2)
	else:
		m.txt(Vector2(r.position.x + 10, r.position.y + 30), "Skill: " + sk["desc"] + " (3 SP)", 7, Color("7a6a5a"))
	# invisible target buttons over enemies (for touch)
	for i in b.alive(1):
		var p = unit_pos(i)
		m.buttons.append({"r": Rect2(p.x - 22, p.y - 44, 44, 50), "id": "F:t%d" % i, "en": true, "nav": false})

func _draw_done() -> void:
	var W = m.W
	var H = m.H
	m.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	var w = minf(W - 20, 300)
	var h = 70.0 + done["lines"].size() * 12
	var r = Rect2(W / 2 - w / 2, H / 2 - h / 2 - 10, w, h)
	m.panel(r)
	var col = Color("3a7a2a") if b.result == "win" else (Color("8a2a3a") if b.result == "lose" else Color("3a5a8a"))
	m.txt(Vector2(W / 2, r.position.y + 22), done["title"], 15, col, 1)
	for k in done["lines"].size():
		m.txt(Vector2(W / 2, r.position.y + 40 + k * 12), done["lines"][k], 8, m.UI_INK, 1)
	m.btn(Rect2(W / 2 - 55, r.end.y - 28, 110, 22), "Continue", "F:done", true, Color("ffd34a"), 10)
