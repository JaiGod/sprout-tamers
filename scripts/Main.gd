extends "res://scripts/UIKit.gd"
## Sprout Tamers - main loop, immediate-mode UI, title, farm, woods, festival and endings.
## Everything on screen is drawn in code each frame; buttons are re-registered every draw.

const Fight = preload("res://scripts/Fight.gd")
const Town = preload("res://scripts/Town.gd")
const Herd = preload("res://scripts/Herd.gd")

func _ready() -> void:
	font = ThemeDB.fallback_font
	fight = Fight.new(self)
	town = Town.new(self)
	herd = Herd.new(self)
	Sfx.play_music("title")
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(_js_cmd)
		JavaScriptBridge.get_interface("window").stCmd = _js_cb

# ------------------------------------------------------------------ web test hooks
func _js_cmd(args: Array) -> void:
	var c = str(args[0]) if args.size() > 0 else ""
	match c:
		"newgame": start_new()
		"skipday": G.next_day()
		"combo": debug_combo()
		"woods": fight.start_wild(0)
		"boss": fight.start_boss()
		"auto": fight.auto_finish()
		"town": go("town")
		"herd": go("herd")

func debug_combo() -> void:
	var sp = D.SPROUTS[G.season * 4]
	for k in 2:
		var tl = G.farm[k]
		tl["t"] = true
		tl["dead"] = false
		tl["c"] = sp["combo"][k]
		tl["g"] = D.CROPS[tl["c"]]["d"]

func _publish_state() -> void:
	var st = {"mode": mode, "season": G.season, "day": G.day, "gold": G.gold, "energy": G.energy, "hearts": G.hearts,
		"sprouts": G.sprouts.size(), "paused": paused, "dialog": dialog.size(), "result": fight.b.result if fight.b else "", "t": t}
	JavaScriptBridge.eval("window.stState=" + JSON.stringify(st), true)

# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var ws = get_window().size
	var want = Vector2i(260, 260) if ws.y > ws.x * 1.15 else Vector2i(400, 260)
	if get_window().content_scale_size != want:
		get_window().content_scale_size = want
	var vs = get_viewport_rect().size
	W = vs.x
	H = vs.y
	if not paused:
		t += delta
		_tick_fx(delta)
		if mode == "battle":
			fight.update(delta)
		if mode == "farm":
			_tick_farm(delta)
	if not trans.is_empty():
		trans["t"] += delta
		if not trans["fired"] and trans["t"] >= trans["dur"] * 0.5:
			trans["fired"] = true
			trans["cb"].call()
		if trans["t"] >= trans["dur"]:
			trans = {}
	if OS.has_feature("web"):
		_js_t += delta
		if _js_t > 0.25:
			_js_t = 0.0
			_publish_state()
	queue_redraw()

func _tick_fx(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 20.0)
	for p in parts:
		p["life"] -= delta
		p["v"].y += p["g"] * delta
		p["p"] += p["v"] * delta
	parts = parts.filter(func(p): return p["life"] > 0)
	for f in floats:
		f["life"] -= delta
		f["p"].y -= 22 * delta
	floats = floats.filter(func(f): return f["life"] > 0)
	for m in toasts:
		m["life"] -= delta
	toasts = toasts.filter(func(m): return m["life"] > 0)

func say(lines: Array, cb = null) -> void:
	dialog = lines.duplicate()
	dialog_cb = cb

func transition(cb: Callable, dur: float = 1.0, label: String = "") -> void:
	trans = {"t": 0.0, "dur": dur, "cb": cb, "fired": false, "label": label}

func go(m: String) -> void:
	mode = m
	focus = -1
	match m:
		"farm": Sfx.play_music("winter" if G.season == 3 else "farm")
		"town": Sfx.play_music("town")
		"woods": Sfx.play_music("woods")
		"title": Sfx.play_music("title")
		"festival": Sfx.play_music("festival")
		"win": Sfx.play_music("victory")
		"lose": Sfx.play_music("")
	if m == "town":
		town.open()
	if m == "herd":
		herd.open()

func start_new() -> void:
	G.new_game()
	wander = {}
	cursor = 8
	seed_sel = 0
	go("farm")
	ppos = Vector2.ZERO
	say(["Juniper: Welcome to Willowmere, new farmer! This field is yours now.",
		"Juniper: This is Mossling, a sprout. Sprouts are plant spirits. Treat them kindly and they help you farm.",
		"Juniper: Tap a plot (or press Z) to till, plant, water and harvest. One button does it all.",
		"Juniper: Grow two crops side by side and when both are ripe, new sprouts may move in overnight!",
		"Juniper: Beware: blight creatures lurk in the woods. On the last night of each season their boss attacks. Good luck!"])

func continue_game() -> void:
	if G.load_game():
		wander = {}
		go("farm")
		toast("Welcome back! " + D.SEASONS[G.season] + ", day %d." % G.day)

# ------------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var p = get_global_mouse_position()
		last_mouse = p
		_click(p)
	elif ev is InputEventMouseMotion:
		last_mouse = get_global_mouse_position()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev.keycode)

func _click(p: Vector2) -> void:
	if not trans.is_empty():
		return
	if not dialog.is_empty():
		_advance_dialog()
		return
	for i in range(buttons.size() - 1, -1, -1):
		var b = buttons[i]
		if b["r"].has_point(p):
			if b["en"]:
				Sfx.play("blip")
				press(b["id"])
			else:
				Sfx.play("bump")
			return
	if paused:
		return
	match mode:
		"farm": _farm_click(p)
		"battle": fight.click(p)

func _advance_dialog() -> void:
	Sfx.play("blip")
	dialog.pop_front()
	if dialog.is_empty() and dialog_cb != null:
		var cb = dialog_cb
		dialog_cb = null
		cb.call()

func _key(k: int) -> void:
	if not trans.is_empty():
		return
	if not dialog.is_empty():
		if k in [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_X, KEY_ESCAPE]:
			_advance_dialog()
		return
	if k == KEY_M:
		press("sound")
		return
	if k == KEY_ESCAPE and mode in ["farm", "town", "herd", "woods", "battle", "festival"]:
		if mode == "town" and town.panel >= 0:
			town.panel = -1
			return
		if mode == "herd" and herd.sel >= 0:
			herd.sel = -1
			return
		press("pause")
		return
	if paused or mode not in ["farm", "battle"]:
		if _menu_nav(k):
			return
	if paused:
		return
	match mode:
		"farm": _farm_key(k)
		"battle": fight.key(k)
		"town": town.key(k)
		"herd": herd.key(k)
		"woods":
			if k in [KEY_1, KEY_2, KEY_3]:
				press("explore%d" % (k - KEY_1))
			elif k in [KEY_X, KEY_BACKSPACE]:
				press("farm")
		"howto":
			if k in [KEY_X, KEY_BACKSPACE]:
				press("back")

func _menu_nav(k: int) -> bool:
	var en = []
	for i in buttons.size():
		if buttons[i]["en"] and buttons[i].get("nav", true):
			en.append(i)
	if en.is_empty():
		return false
	if k in [KEY_DOWN, KEY_RIGHT, KEY_S, KEY_D, KEY_TAB]:
		var pos = en.find(focus)
		focus = en[(pos + 1) % en.size()]
		Sfx.play("blip")
		return true
	if k in [KEY_UP, KEY_LEFT, KEY_W, KEY_A]:
		var pos = en.find(focus)
		focus = en[(pos - 1 + en.size()) % en.size()] if pos >= 0 else en[en.size() - 1]
		Sfx.play("blip")
		return true
	if k in [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and focus >= 0 and focus < buttons.size():
		Sfx.play("select")
		press(buttons[focus]["id"])
		return true
	return false

func press(id: String) -> void:
	focus = -1 if id != "sound" else focus
	match id:
		"sound":
			G.sound_on = not G.sound_on
			Sfx.music.stream_paused = not G.sound_on
			G.save_cfg()
			toast("Sound " + ("on" if G.sound_on else "off"), 1.5)
		"pause": paused = not paused
		"resume": paused = false
		"quit":
			paused = false
			if mode != "battle":
				G.save_game()
			go("title")
		"new":
			if G.has_save():
				say(["Starting a new farm will replace your saved farm. Tap again on New Game to confirm."], func(): pass)
				buttons_confirm_new = true
				return
			start_new()
		"new_ok": start_new()
		"continue": continue_game()
		"howto":
			howto_page = 0
			go("howto")
		"hnext": howto_page = (howto_page + 1) % HOWTO.size()
		"back": go("title")
		"farm": go("farm")
		"town": go("town")
		"herd": go("herd")
		"woods": go("woods")
		"sleep": do_sleep()
		"compost":
			if G.use_compost():
				Sfx.play("sprout")
				toast("Glow Compost! Every crop grew a day.")
				burst(Vector2(W * 0.3, H * 0.4), Color("b0ff7a"), 30, 120)
			else:
				toast("No Glow Compost. Tilly sells it.")
		"pet": pet_next()
		"fest_go": fest_continue()
		"title": go("title")
		"retry": start_new()
		_:
			if id.begins_with("seed"):
				seed_sel = int(id.substr(4))
			elif id.begins_with("explore"):
				var a = int(id.substr(7))
				if G.energy < int(D.WOODS[a]["cost"]):
					toast("Not enough energy to explore. Sleep first.")
				elif G.team().is_empty():
					toast("You need a sprout to explore the woods.")
				else:
					G.energy -= int(D.WOODS[a]["cost"])
					fight.start_wild(a)
			elif id.begins_with("T:"):
				town.press(id.substr(2))
			elif id.begins_with("H:"):
				herd.press(id.substr(2))
			elif id.begins_with("F:"):
				fight.press(id.substr(2))

var buttons_confirm_new: bool = false

# ------------------------------------------------------------------ draw root
func _draw() -> void:
	buttons = []
	draw_set_transform(_shake_off(), 0, Vector2.ONE)
	match mode:
		"title": _draw_title()
		"howto": _draw_howto()
		"farm": _draw_farm()
		"woods": _draw_woods()
		"battle": fight.draw()
		"town": town.draw()
		"herd": herd.draw()
		"festival": _draw_festival()
		"win", "lose": _draw_end()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for p in parts:
		var a = clampf(p["life"] / 0.5, 0, 1)
		var c: Color = p["col"]
		draw_rect(Rect2(p["p"] - Vector2.ONE * p["sz"] / 2, Vector2.ONE * p["sz"]), Color(c.r, c.g, c.b, a))
	for f in floats:
		txt(f["p"], f["s"], 10, Color(f["col"].r, f["col"].g, f["col"].b, clampf(f["life"] * 2, 0, 1)), 1, 3)
	if mode in ["farm", "town", "herd", "woods"]:
		_draw_hud()
	_draw_toasts()
	if paused:
		_draw_pause()
	if not dialog.is_empty():
		_draw_dialog()
	if not trans.is_empty():
		var k = trans["t"] / trans["dur"]
		var a = 1.0 - absf(k * 2.0 - 1.0)
		a = clampf(a * 1.6, 0, 1)
		draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.16, a))
		if trans["label"] != "":
			for i in 30:
				var sx = fmod(i * 97.3, W)
				var sy = fmod(i * 41.7, H * 0.7)
				draw_rect(Rect2(sx, sy, 1.5, 1.5), Color(1, 1, 0.8, a * (0.5 + 0.5 * sin(t * 3 + i))))
			txt(Vector2(W / 2, H / 2), trans["label"], 16, Color(1, 0.95, 0.8, a), 1, 4)

func _draw_toasts() -> void:
	var y = H - (58.0 if mode == "farm" and landscape() else 14.0)
	if mode == "battle":
		y = 40
	for i in range(toasts.size() - 1, -1, -1):
		var m = toasts[i]
		var a = clampf(m["life"] * 2, 0, 1)
		var tw = font.get_string_size(m["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var w = minf(W - 12, tw + 16)
		var two = tw + 16 > W - 12
		var hh = 27.0 if two else 16.0
		var r = Rect2(W / 2 - w / 2, y - hh + 2, w, hh)
		draw_rect(r, Color(0.1, 0.08, 0.05, 0.78 * a))
		if two:
			draw_multiline_string(font, r.position + Vector2(6, 11), m["s"], HORIZONTAL_ALIGNMENT_CENTER, w - 12, 9, 2, Color(1, 0.96, 0.85, a))
		else:
			txt(Vector2(W / 2, y - 3), m["s"], 9, Color(1, 0.96, 0.85, a), 1)
		y -= hh + 2

func _draw_dialog() -> void:
	var w = minf(W - 16, 440)
	var h = 62.0
	var r = Rect2(W / 2 - w / 2, H - h - 8, w, h)
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.25))
	panel(r)
	var line: String = dialog[0]
	var who = ""
	var idx = line.find(": ")
	if idx > 0 and idx < 18:
		who = line.substr(0, idx)
		line = line.substr(idx + 2)
	var x0 = r.position.x + 10
	if who != "":
		var vi = -1
		for i in D.VILLAGERS.size():
			if D.VILLAGERS[i]["n"] == who:
				vi = i
		if vi >= 0:
			spr(Art.villager(vi), Vector2(x0 + 16, r.position.y + 30), 2.6)
			x0 += 38
		txt(Vector2(x0, r.position.y + 14), who, 9, Color("a0522d"))
	para(Rect2(x0, r.position.y + (17 if who != "" else 8), r.end.x - x0 - 10, 40), line, 9, UI_INK, 3)
	if int(t * 2) % 2 == 0:
		txt(Vector2(r.end.x - 10, r.end.y - 6), "v", 9, UI_EDGE, 2)

func _draw_hud() -> void:
	var hh = hud_h()
	var r = Rect2(0, 0, W, hh)
	draw_rect(r, Color(0.1, 0.12, 0.08, 0.82))
	draw_rect(Rect2(0, hh, W, 1), Color("ffe27a", 0.3))
	var sc = D.SEASON_TINT[G.season]
	draw_circle(Vector2(11, 11), 6, sc)
	txt(Vector2(21, 15), "%s  Day %d/%d" % [D.SEASONS[G.season], G.day, D.DAYS_PER_SEASON], 9, Color.WHITE)
	coin(Vector2(118, 11))
	txt(Vector2(125, 15), str(G.gold), 9, Color("ffe27a"))
	var ex = 160.0
	var ey = 0.0
	if narrow():
		ex = 8.0
		ey = 16.0
	txt(Vector2(ex, 15 + ey), "Energy", 8, Color("c8e8a8"))
	bar(Rect2(ex + 32, 7 + ey, 56, 8), float(G.energy) / G.max_energy, Color("8fe05a"))
	txt(Vector2(ex + 60, 14.5 + ey), "%d" % G.energy, 7, Color.WHITE, 1)
	for i in 3:
		heart(Vector2(ex + 100 + i * 13, 9.5 + ey), 3.6, Color("ff5a6a") if i < G.hearts else Color("4a3a3a"))
	btn(Rect2(W - 48, 3, 21, 16), "II", "pause", true, Color("e8d8a8"), 8, false)
	btn(Rect2(W - 24, 3, 21, 16), "", "sound", true, Color("e8d8a8") if G.sound_on else Color("b89a8a"), 9, false)
	note_icon(Vector2(W - 14.5, 10.5), Color("1e2a14"))
	if not G.sound_on:
		draw_line(Vector2(W - 21, 5), Vector2(W - 7, 17), Color("a02a2a"), 1.5)

func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	var r = Rect2(W / 2 - 90, H / 2 - 80, 180, 160)
	panel(r)
	txt(Vector2(W / 2, r.position.y + 22), "Paused", 14, UI_INK, 1)
	btn(Rect2(r.position.x + 20, r.position.y + 34, 140, 24), "Resume", "resume")
	btn(Rect2(r.position.x + 20, r.position.y + 64, 140, 24), "Sound: " + ("On" if G.sound_on else "Off"), "sound", true, Color("9fd0f0"))
	btn(Rect2(r.position.x + 20, r.position.y + 94, 140, 24), "Save & quit to title", "quit", true, Color("f0b07a"))
	txt(Vector2(W / 2, r.end.y - 12), "Esc resume · M sound", 8, Color("7a6a5a"), 1)

# ------------------------------------------------------------------ title
func _draw_title() -> void:
	var sky = Color("8fd0f0")
	draw_rect(Rect2(0, 0, W, H), sky)
	for i in 6:
		var cx = fmod(i * 120.0 + t * (6 + i), W + 80) - 40
		_ellipse(Vector2(cx, 30 + i * 9 % 40), 26, 7, Color(1, 1, 1, 0.75))
	var hy = H * 0.62
	for i in 9:
		_ellipse(Vector2(i * W / 8.0, hy + 4), W / 9.0, 22, Color("6fb85a"))
	grass(Rect2(0, hy, W, H - hy), 0)
	for i in 7:
		spr_feet(Art.tree(0, i % 2), Vector2(20 + i * W / 6.5, hy + 6), 1.6)
	# parade of sprouts
	for i in 16:
		var x = fmod(i * 46.0 + t * 20.0, W + 60) - 30
		if not G.found[i] and G.best["found"] == 0 and i > 5:
			continue
		var bob = absf(sin(t * 6 + i)) * 3
		spr_feet(Art.sprout(i), Vector2(x, H - 22 - (i % 3) * 14 - bob), 1.6, false, Color.WHITE, sin(t * 12 + i) * 0.05)
	_petals(Color("ffb8d8"))
	# logo
	var ly = H * 0.2 if landscape() else H * 0.16
	var wob = sin(t * 2) * 2
	var ls2 = 30 if not narrow() else 23
	txt(Vector2(W / 2 + 2, ly + 4 + wob), "SPROUT TAMERS", ls2, Color("2a4a1a"), 1)
	txt(Vector2(W / 2, ly + wob), "SPROUT TAMERS", ls2, Color("fff3c0"), 1, 8, Color("3a6a2a"))
	txt(Vector2(W / 2, ly + 18), "farm  ·  befriend  ·  breed  ·  defend", 9, Color("2a3a1a"), 1)
	var bw = 150.0
	var x = W / 2 - bw / 2
	var y = ly + 32
	if G.has_save():
		btn(Rect2(x, y, bw, 22), "Continue", "continue", true, Color("ffd34a"), 10)
		y += 27
	btn(Rect2(x, y, bw, 22), "New Game", "new_ok" if buttons_confirm_new or not G.has_save() else "new", true, UI_ACC, 10)
	y += 27
	btn(Rect2(x, y, bw, 22), "How to Play", "howto", true, Color("9fd0f0"), 10)
	y += 27
	btn(Rect2(x, y, bw, 22), "Sound: " + ("On" if G.sound_on else "Off"), "sound", true, Color("e8d8a8"), 10)
	y += 30
	var b = G.best
	if narrow():
		txt(Vector2(W / 2, y + 4), "Best: %d/16 sprouts found" % b["found"], 8, Color("1a2a10"), 1, 3, Color(1, 1, 1, 0.6))
		txt(Vector2(W / 2, y + 15), "%d bosses beaten · %d full years" % [b["bosses"], b["wins"]], 8, Color("1a2a10"), 1, 3, Color(1, 1, 1, 0.6))
	else:
		txt(Vector2(W / 2, y + 4), "Best: %d/16 sprouts found · %d bosses beaten · %d full years" % [b["found"], b["bosses"], b["wins"]], 8, Color("1a2a10"), 1, 3, Color(1, 1, 1, 0.6))

const HOWTO = [
	["Farming", "Tap a plot (or move with Arrows/WASD and press Z/Space) to do the next job: till, plant the selected seed, water, then harvest when ripe. Watered crops grow one day each night. Pick seeds in the seed bar (or Q/E). Energy refills when you sleep (N)."],
	["Sprouts", "When two ripe crops sit side by side, a matching sprout may move in overnight. There are 16 to find; the Almanac lists the crop pairs. Each sprout has a job: Waterers water plots, Harvesters gather ripe crops, Guardians chase off blight mites. They only work at 3+ friendship."],
	["Friendship & Breeding", "Tap a sprout on the farm (or press P) to pet it once a day. Sweet Nectar and winning battles help too. Two sprouts with 6+ friendship can breed at the Nursery: the seedling takes one trait from each parent, better potential, and sometimes a brand-new trait."],
	["Battles", "Explore the Wild Woods (F) to fight blight creatures for gold and XP. Leaf beats Dew, Dew beats Ember, Ember beats Leaf. Skills cost 3 SP; Guard halves damage. On the last night of each season the blight boss attacks your farm. Lose and a Heartroot is torn out; lose all three and the farm withers."],
	["Town & Festival", "Visit Willowmere (T): sell crops and buy seeds at Tilly's, build upgrades at Bram's, heal at Juniper's clinic and fill Mayor Olwen's requests. Beat the boss to hold the season festival, where your harvest, friendships and town hearts earn a ribbon. Survive all four seasons to win!"],
]

func _draw_howto() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("2f4a2a"))
	grass(Rect2(0, 0, W, H), 0)
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.25))
	var w = minf(W - 20, 420)
	var h = minf(H - 20, 230)
	var r = Rect2(W / 2 - w / 2, H / 2 - h / 2, w, h)
	panel(r)
	var pg = HOWTO[howto_page]
	txt(Vector2(W / 2, r.position.y + 22), "How to Play  ·  " + pg[0], 13, UI_INK, 1)
	txt(Vector2(W / 2, r.position.y + 36), "page %d / %d" % [howto_page + 1, HOWTO.size()], 8, Color("8a6a4a"), 1)
	para(Rect2(r.position.x + 16, r.position.y + 44, w - 32, h - 90), pg[1], 10, UI_INK)
	for i in 3:
		spr_feet(Art.sprout([1, 0, 4, 12, 9][howto_page] + i), Vector2(r.position.x + 30 + i * 26, r.end.y - 40 + absf(sin(t * 5 + i)) * -3), 1.3)
	btn(Rect2(r.end.x - 196, r.end.y - 32, 88, 22), "Next page", "hnext", true, Color("9fd0f0"))
	btn(Rect2(r.end.x - 100, r.end.y - 32, 88, 22), "Back", "back", true, Color("f0b07a"))

# ------------------------------------------------------------------ farm
func farm_layout() -> Dictionary:
	var L = {}
	if landscape():
		var side = 138.0
		var ts = floor(minf((W - side - 40) / G.COLS, (H - 22 - 44 - 20) / G.rows))
		ts = clampf(ts, 16, 30)
		L["ts"] = ts
		L["grid"] = Rect2(floor((W - side - ts * G.COLS) / 2), 32 + floor((H - 22 - 44 - 10 - ts * G.rows) / 2), ts * G.COLS, ts * G.rows)
		L["side"] = Rect2(W - side - 6, 28, side, H - 28 - 46)
		L["bar"] = Rect2(6, H - 42, W - 12, 38)
		L["zone"] = Rect2(8, 30, W - side - 22, H - 80)
	else:
		var ts = floor(minf((W - 24) / G.COLS, 54))
		L["ts"] = ts
		var gy = hud_h() + 14.0
		L["grid"] = Rect2(floor((W - ts * G.COLS) / 2), gy, ts * G.COLS, ts * G.rows)
		var by = gy + ts * G.rows + 30
		L["bar"] = Rect2(6, by, W - 12, 44)
		L["side"] = Rect2(6, by + 52, W - 12, H - by - 60)
		L["zone"] = Rect2(8, 26, W - 16, by - 34)
	return L

func tile_rect(L: Dictionary, i: int) -> Rect2:
	var ts = L["ts"]
	return Rect2(L["grid"].position + Vector2((i % G.COLS) * ts, (i / G.COLS) * ts), Vector2(ts, ts))

func season_seeds() -> Array:
	var out = []
	for i in D.CROPS.size():
		if D.CROPS[i]["s"] == G.season:
			out.append(i)
	return out

func _tick_farm(delta: float) -> void:
	var L = farm_layout()
	var target = tile_rect(L, clampi(cursor, 0, G.farm.size() - 1)).get_center() + Vector2(0, L["ts"] * 0.3)
	if ppos == Vector2.ZERO:
		ppos = target
	ppos = ppos.lerp(target, minf(1.0, delta * 12.0))
	var zone: Rect2 = L["zone"]
	for s in G.sprouts:
		var w = wander.get(s["id"])
		if w == null or not zone.has_point(w["p"]):
			w = {"p": zone.position + Vector2(randf() * zone.size.x, randf() * zone.size.y), "tgt": Vector2.ZERO, "wait": randf() * 2, "flip": false}
			wander[s["id"]] = w
		if w["wait"] > 0:
			w["wait"] -= delta
			if w["wait"] <= 0:
				w["tgt"] = zone.position + Vector2(randf() * zone.size.x, 10 + randf() * (zone.size.y - 10))
		else:
			var d: Vector2 = w["tgt"] - w["p"]
			if d.length() < 2:
				w["wait"] = randf_range(1.0, 3.5)
			else:
				w["p"] += d.normalized() * 22 * delta
				w["flip"] = d.x < 0

func _draw_farm() -> void:
	var L = farm_layout()
	grass(Rect2(0, 0, W, H), G.season)
	var g: Rect2 = L["grid"]
	var ts: float = L["ts"]
	# fence & trees
	var fence = g.grow(6)
	draw_rect(fence, Color("8a5a32"), false, 2)
	for x in range(int(fence.position.x), int(fence.end.x) + 1, 12):
		draw_rect(Rect2(x - 1, fence.position.y - 3, 3, 6), Color("6a4228"))
		draw_rect(Rect2(x - 1, fence.end.y - 3, 3, 6), Color("6a4228"))
	if landscape():
		for i in 4:
			spr_feet(Art.tree(G.season, i % 2), Vector2(14 + i * 9, H - 50 - i * 30), 1.2)
	var combos = G.combos_now()
	var combo_tiles = {}
	for c in combos:
		combo_tiles[c[1]] = c[0]
		combo_tiles[c[2]] = c[0]
	for i in G.farm.size():
		var r = tile_rect(L, i)
		var tl = G.farm[i]
		var st = G.tile_state(i)
		if st != "wild":
			var soil = Color("7a4e2e") if not tl["w"] else Color("4e3020")
			if G.season == 3:
				soil = soil.lerp(Color("8a8aa0"), 0.25)
			draw_rect(r.grow(-1), soil)
			for k in 3:
				draw_rect(Rect2(r.position.x + 3, r.position.y + ts * (0.25 + k * 0.25), ts - 6, 1), soil.darkened(0.25))
			if tl["w"]:
				draw_rect(Rect2(r.position.x + 2, r.position.y + 2, 3, 2), Color("8ad0ff", 0.7))
		else:
			draw_rect(r.grow(-1), Color(0, 0, 0, 0.06))
			draw_rect(Rect2(r.position.x + ts * 0.4, r.position.y + ts * 0.5, 2, 3), Color(0.2, 0.35, 0.1, 0.4))
		if tl["c"] >= 0:
			var stage = 4 if tl["dead"] else (3 if st == "ripe" else clampi(int(3.0 * tl["g"] / D.CROPS[tl["c"]]["d"]), 0, 2))
			var sway = sin(t * 2 + i) * 0.03 if st == "ripe" else 0.0
			draw_set_transform(r.get_center() + Vector2(0, ts * 0.5) + _shake_off(), sway, Vector2.ONE)
			var tex = Art.crop(tl["c"], stage)
			var sc = ts / 16.0
			draw_texture_rect(tex, Rect2(Vector2(-8 * sc, -16 * sc), Vector2(16 * sc, 16 * sc)), false)
			draw_set_transform(_shake_off(), 0, Vector2.ONE)
			if st == "ripe" and int(t * 3 + i) % 5 == 0:
				draw_rect(Rect2(r.position.x + ts * 0.7, r.position.y + 2, 2, 2), Color(1, 1, 0.8))
		if combo_tiles.has(i):
			var col = D.ELEM_COL[D.SPROUTS[combo_tiles[i]]["e"]]
			draw_rect(r.grow(-1), Color(col.r, col.g, col.b, 0.5 + 0.4 * sin(t * 4)), false, 1.5)
	# combo hint marks
	for c in combos:
		var a = tile_rect(L, c[1]).get_center()
		var b = tile_rect(L, c[2]).get_center()
		var m = (a + b) / 2 + Vector2(0, -ts * 0.4 + sin(t * 3) * 2)
		draw_circle(m, 5, Color(1, 1, 1, 0.9))
		if G.found[c[0]]:
			heart(m + Vector2(0, -1), 2.2, D.ELEM_COL[D.SPROUTS[c[0]]["e"]].darkened(0.3))
		else:
			txt(m + Vector2(0, 3.5), "!", 9, D.ELEM_COL[D.SPROUTS[c[0]]["e"]].darkened(0.3), 1)
	# cursor
	var cr = tile_rect(L, clampi(cursor, 0, G.farm.size() - 1))
	var pulse = 1.0 + sin(t * 6) * 1.0
	draw_rect(cr.grow(pulse), Color("ffe27a"), false, 1.5)
	# sprouts + farmer, sorted by y
	var actors = []
	for s in G.sprouts:
		var w = wander.get(s["id"])
		if w != null:
			actors.append([w["p"].y, s, w])
	actors.append([ppos.y, null, null])
	actors.sort_custom(func(a, b): return a[0] < b[0])
	for a in actors:
		if a[1] == null:
			spr_feet(Art.farmer(), ppos, ts / 16.0 * 1.05, false, Color.WHITE, 0.0)
		else:
			var s = a[1]
			var w = a[2]
			var moving = w["wait"] <= 0
			var hop = absf(sin(t * 10 + s["id"])) * 2.5 if moving else 0.0
			spr_feet(Art.sprout(s["sp"]), w["p"] - Vector2(0, hop), 1.2 if landscape() else 1.8, w["flip"], Color.WHITE, sin(t * 4 + s["id"]) * 0.04)
			if s["pet"] != G.dayno:
				heart(w["p"] + Vector2(0, -27 if landscape() else -40), 2.2, Color(1, 0.5, 0.6, 0.5 + 0.4 * sin(t * 4)))
	if G.season == 3:
		_snow()
	elif G.season == 0:
		_petals(Color("ffc0dc", 0.8))
	elif G.season == 2:
		_petals(Color("e08a3a", 0.8))
	_draw_seedbar(L)
	_draw_side(L)

func _draw_seedbar(L: Dictionary) -> void:
	var r: Rect2 = L["bar"]
	panel(r, Color("e8dcb8"))
	var opts = season_seeds()
	if not opts.has(seed_sel):
		seed_sel = opts[0]
	var cw = 58.0 if narrow() else 70.0
	var w = (r.size.x - 16 - cw) / 3.0
	var nx = 18.0 if narrow() else 24.0
	var fs = 7 if narrow() else 8
	for k in opts.size():
		var c = opts[k]
		var br = Rect2(r.position.x + 6 + k * (w + 2), r.position.y + 5, w, r.size.y - 10)
		var sel = c == seed_sel
		btn(br, "", "seed%d" % c, true, Color("ffe27a") if sel else Color("cfc3a0"), 9, false)
		spr(Art.crop(c, 3), br.position + Vector2(nx / 2, br.size.y / 2), 1.2 if not narrow() else 0.9)
		txt(br.position + Vector2(nx, br.size.y / 2 - 1), D.CROPS[c]["n"], fs, UI_INK)
		txt(br.position + Vector2(nx, br.size.y / 2 + 9), "x%d  %dd" % [G.seeds[c], D.CROPS[c]["d"]], fs, Color("6a4a2a"))
	btn(Rect2(r.end.x - cw - 2, r.position.y + 5, cw - 4, r.size.y - 10), "Compost x%d" % G.items["compost"], "compost", G.items["compost"] > 0, Color("b0e07a"), fs, false)

func _draw_side(L: Dictionary) -> void:
	var r: Rect2 = L["side"]
	var ls = landscape()
	var bh = 22.0 if ls else 28.0
	var labels = [["Sleep  [N]", "sleep", Color("a8b8f0")], ["Wild Woods  [F]", "woods", Color("f0a07a")], ["Town  [T]", "town", Color("ffd34a")], ["Sprouts  [C]", "herd", Color("b0e07a")]]
	if G.sleep_is_boss():
		labels[0] = ["Face the Blight!", "sleep", Color("ff7a7a")]
	var y = r.position.y
	if ls:
		for l in labels:
			btn(Rect2(r.position.x, y, r.size.x, bh), l[0], l[1], true, l[2], 9, false)
			y += bh + 4
	else:
		var bw = (r.size.x - 6) / 2
		for k in labels.size():
			btn(Rect2(r.position.x + (k % 2) * (bw + 6), y + (k / 2) * (bh + 6), bw, bh), labels[k][0].split("  [")[0], labels[k][1], true, labels[k][2], 10, false)
		y += 2 * (bh + 6)
	var ir = Rect2(r.position.x, y + 2, r.size.x, r.end.y - y - 2)
	if ir.size.y < 30:
		return
	panel(ir, Color("f4ead0"))
	var x0 = ir.position.x + 6
	var yy = ir.position.y + 13
	var i = clampi(cursor, 0, G.farm.size() - 1)
	var tl = G.farm[i]
	var st = G.tile_state(i)
	var info = {"wild": "Wild grass. Tap to till (1 energy).", "tilled": "Tilled soil. Tap to plant " + D.CROPS[seed_sel]["n"] + ".",
		"dead": "Wilted by blight. Tap to clear.", "ripe": "Ripe! Tap to harvest.", "growing": ""}
	if st == "growing":
		var cd = D.CROPS[tl["c"]]
		info["growing"] = "%s: day %d/%d. %s" % [cd["n"], tl["g"], cd["d"], "Watered." if tl["w"] else "Needs water!"]
	para(Rect2(x0, yy - 10, ir.size.x - 12, 30), info[st], 8, UI_INK, 2)
	yy += 22
	if G.request.size() > 0 and ir.size.y > 70:
		var rq = G.request
		var s = "Request: %s wants %d %s (%d/%d)" % [D.VILLAGERS[rq["v"]]["n"], rq["qty"], D.CROPS[rq["crop"]]["n"], G.bag[rq["crop"]], rq["qty"]]
		if rq["done"]:
			s = "Request done! New one tomorrow."
		para(Rect2(x0, yy - 10, ir.size.x - 12, 30), s, 8, Color("6a3a1a"), 2)
		yy += 22
	if ir.size.y > 100:
		txt(Vector2(x0, yy), "Basket: %d crops   Tonics: %d" % [G.bag_count(), G.items["tonic"]], 8, UI_INK)
		yy += 11
		var unp = 0
		for s in G.sprouts:
			if s["pet"] != G.dayno:
				unp += 1
		if unp > 0:
			btn(Rect2(x0, yy, ir.size.x - 12, 16), "Pet sprouts (%d)  [P]" % unp, "pet", true, Color("ffb8c8"), 8, false)
		yy += 20
	if ir.size.y > 130 and not ls:
		para(Rect2(x0, yy, ir.size.x - 12, 80), "Tip: ripe pairs glow when they form a sprout combo. Leave them standing overnight! Tap a sprout to pet it.", 8, Color("5a7a3a"), 4)

func _farm_hit_sprout(p: Vector2) -> Dictionary:
	var best = {}
	var bd = 16.0 if landscape() else 24.0
	for s in G.sprouts:
		var w = wander.get(s["id"])
		if w == null:
			continue
		var d = (w["p"] + Vector2(0, -10)).distance_to(p)
		if d < bd:
			bd = d
			best = s
	return best

func _farm_click(p: Vector2) -> void:
	var s = _farm_hit_sprout(p)
	if not s.is_empty():
		pet(s)
		return
	var L = farm_layout()
	if L["grid"].has_point(p):
		var rel = p - L["grid"].position
		var i = int(rel.y / L["ts"]) * G.COLS + int(rel.x / L["ts"])
		if i >= 0 and i < G.farm.size():
			cursor = i
			farm_act()

func _farm_key(k: int) -> void:
	var x = cursor % G.COLS
	var y = cursor / G.COLS
	match k:
		KEY_LEFT, KEY_A: x = maxi(0, x - 1)
		KEY_RIGHT, KEY_D: x = mini(G.COLS - 1, x + 1)
		KEY_UP, KEY_W: y = maxi(0, y - 1)
		KEY_DOWN, KEY_S: y = mini(G.rows - 1, y + 1)
		KEY_Z, KEY_SPACE, KEY_ENTER: farm_act()
		KEY_Q, KEY_E:
			var o = season_seeds()
			var j = o.find(seed_sel)
			seed_sel = o[(j + (1 if k == KEY_E else o.size() - 1)) % o.size()]
			Sfx.play("blip")
		KEY_1, KEY_2, KEY_3:
			seed_sel = season_seeds()[k - KEY_1]
		KEY_N: press("sleep")
		KEY_F: press("woods")
		KEY_T: press("town")
		KEY_C: press("herd")
		KEY_P: press("pet")
		KEY_G: press("compost")
	cursor = y * G.COLS + x

func farm_act() -> void:
	var L = farm_layout()
	var r = tile_rect(L, cursor)
	var res = G.act_tile(cursor, seed_sel)
	if not res["ok"]:
		Sfx.play("bump")
		toast(res["msg"], 2.2)
		return
	match res.get("fx", ""):
		"till":
			Sfx.play("till")
			burst(r.get_center(), Color("8a5a32"), 8, 40)
		"plant":
			Sfx.play("plant")
			burst(r.get_center(), Color("7fd85a"), 6, 30)
		"water":
			Sfx.play("water")
			burst(r.get_center() + Vector2(0, -6), Color("7fd0ff"), 10, 40, 200)
		"harvest":
			Sfx.play("harvest")
			burst(r.get_center(), D.CROPS[res["crop"]]["col"], 12, 70)
			float_text(r.get_center() + Vector2(0, -8), res["msg"], Color("fff3a0"))
			return
	if res["msg"] != "":
		toast(res["msg"], 2.0)

func pet(s: Dictionary) -> void:
	var w = wander.get(s["id"], {"p": Vector2(W / 2, H / 2)})
	if s["pet"] == G.dayno:
		toast(G.sp_name(s) + " already got pets today. (%d/10 friendship)" % s["fr"], 2)
		burst(w["p"] + Vector2(0, -12), Color("ffb8c8"), 3, 20)
		return
	s["pet"] = G.dayno
	G.befriend(s, 1)
	Sfx.play("pet")
	burst(w["p"] + Vector2(0, -14), Color("ff7a9a"), 10, 40, -30)
	float_text(w["p"] + Vector2(0, -24), "Friendship %d" % s["fr"], Color("ffb8c8"))
	if s["fr"] == 3:
		toast(G.sp_name(s) + " trusts you now and will help on the farm!")
	elif s["fr"] == 6:
		toast(G.sp_name(s) + " adores you! It can now breed at the Nursery.")

func pet_next() -> void:
	for s in G.sprouts:
		if s["pet"] != G.dayno:
			pet(s)
			return
	toast("Every sprout got pets today.", 1.6)

func do_sleep() -> void:
	if G.sleep_is_boss():
		say([D.BOSSES[G.season]["line"], "Your team: " + ", ".join(PackedStringArray(G.team().map(func(s): return G.sp_name(s) + " Lv%d" % s["lv"]))) + ". Fight!"], func(): fight.start_boss())
		return
	Sfx.play("sleep")
	transition(_sleep_cb, 1.6, "%s · Day %d" % [D.SEASONS[G.season], G.day + 1])

func _sleep_cb() -> void:
	var lg = G.next_day()
	for l in lg:
		toast(l, 4.5)

# ------------------------------------------------------------------ woods
func _draw_woods() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("1e3a24"))
	for i in 18:
		var x = fmod(i * 61.0, W + 20) - 10
		var y = 40 + (i * 37) % int(maxf(60, H - 90))
		spr_feet(Art.tree(G.season, 1), Vector2(x, y + 30), 1.4, false, Color(0.55, 0.7, 0.6))
	for i in 14:
		var x = fmod(i * 97.0 + sin(t + i) * 8, W)
		var y = fmod(i * 53.0 + t * 6, H)
		draw_circle(Vector2(x, y), 1.2, Color(0.9, 1, 0.6, 0.5 + 0.5 * sin(t * 3 + i)))
	var w = minf(W - 20, 430)
	var x0 = W / 2 - w / 2
	var tyy = hud_h() + 20
	txt(Vector2(W / 2, tyy), "The Wild Woods", 16, Color("e8f8c0"), 1, 4, Color("10200c"))
	txt(Vector2(W / 2, tyy + 13), "Win for gold, XP, seeds and friendship." if narrow() else "Blight creatures roam here. Win for gold, XP and friendship.", 8, Color("c0d8a0"), 1)
	var ls = landscape()
	var cw = (w - 16) / 3.0 if ls else w
	var ch = 120.0 if ls else 92.0
	for a in 3:
		var area = D.WOODS[a]
		var r = Rect2(x0 + a * (cw + 8), 64, cw, ch) if ls else Rect2(x0, tyy + 22 + a * (ch + 8), cw, ch)
		panel(r, Color("e8e0c0"))
		txt(Vector2(r.position.x + 8, r.position.y + 16), area["n"], 10, UI_INK)
		para(Rect2(r.position.x + 8, r.position.y + 20, r.size.x - 16, 30), area["desc"], 8, Color("5a4a3a"), 2)
		var lv = 1 + G.season * 3 + int(area["lv"])
		txt(Vector2(r.position.x + 8, r.position.y + 54), "Blight Lv %d-%d · %d energy" % [lv, lv + 1, area["cost"]], 8, Color("8a3a2a"))
		for k in [1, 2, 3][a]:
			spr_feet(Art.blight((G.season * 2 + k + a) % 8), Vector2(r.end.x - 20 - k * 20, r.position.y + 78), 1.0)
		btn(Rect2(r.position.x + 8, r.end.y - 28, r.size.x - 16, 20), "Explore  [%d]" % (a + 1), "explore%d" % a, G.energy >= int(area["cost"]), Color("f0a07a"))
	var tm = G.team()
	var ty = (64 + ch + 14) if ls else (tyy + 22 + 3 * (ch + 8) + 6)
	var sp = 60.0 if narrow() else 70.0
	txt(Vector2(x0, ty + 8), "Team:", 9, Color("e8f8c0"))
	for k in tm.size():
		var s = tm[k]
		spr_feet(Art.sprout(s["sp"]), Vector2(x0 + 44 + k * sp, ty + 20), 1.0)
		txt(Vector2(x0 + 56 + k * sp, ty + 8), "Lv%d" % s["lv"], 8, Color.WHITE)
		bar(Rect2(x0 + 56 + k * sp, ty + 11, 30, 4), float(s["hp"]) / G.stat(s, 0), Color("7fe05a"))
	btn(Rect2(W / 2 - 60, minf(H - 30, ty + 30), 120, 22), "Back to farm  [X]", "farm", true, Color("e8d8a8"))

# ------------------------------------------------------------------ festival
func open_festival() -> void:
	var score = G.festival_score()
	var rib = G.ribbon_for(score)
	var prize = [300, 180, 100][rib]
	G.gold += prize
	G.ribbons.append(rib)
	fest = {"score": score, "rib": rib, "prize": prize, "season": G.season}
	G.save_game()
	go("festival")

func fest_continue() -> void:
	if fest["season"] >= 3:
		G.best["wins"] = int(G.best["wins"]) + 1
		G.save_cfg()
		G.delete_save()
		go("win")
		return
	transition(_season_cb, 1.8, D.SEASONS[fest["season"] + 1] + " begins")

func _season_cb() -> void:
	var lg = G.begin_season(fest["season"] + 1)
	go("farm")
	for l in lg:
		toast(l, 4.5)
	toast("Welcome to " + D.SEASONS[G.season] + "! New seeds at Tilly's market.", 5)

func _draw_festival() -> void:
	var f = D.FESTIVALS[fest["season"]]
	var col: Color = f["col"]
	draw_rect(Rect2(0, 0, W, H), Color("141a3a"))
	for i in 40:
		draw_rect(Rect2(fmod(i * 83.1, W), fmod(i * 37.7, H * 0.5), 1.5, 1.5), Color(1, 1, 1, 0.4 + 0.4 * sin(t * 2 + i)))
	grass(Rect2(0, H * 0.62, W, H * 0.38), fest["season"])
	draw_rect(Rect2(0, H * 0.62, W, H * 0.38), Color(0.05, 0.05, 0.2, 0.35))
	# lantern strings
	for k in 2:
		var y0 = 24 + k * 26
		for i in 14:
			var x = i * W / 13.0
			var y = y0 + sin(i * 0.9 + k) * 6
			draw_line(Vector2(x, y), Vector2(x + W / 13.0, y0 + sin((i + 1) * 0.9 + k) * 6), Color("3a3020"), 1)
			var lc = [col, Color("ffe27a"), Color("7fd0ff"), Color("b0ff8a")][(i + k) % 4]
			draw_circle(Vector2(x, y + 5), 3.5, lc)
			draw_circle(Vector2(x, y + 5), 6 + sin(t * 3 + i) * 1.2, Color(lc.r, lc.g, lc.b, 0.18))
	# fireworks
	if randf() < 0.05:
		burst(Vector2(randf_range(40, W - 40), randf_range(30, H * 0.4)), [col, Color("ffe27a"), Color("ffffff")][randi() % 3], 26, 90, 30, 2)
	# villagers + sprouts dancing
	var gy = H * 0.62 + 30
	for i in 4:
		spr_feet(Art.villager(i), Vector2(W * (0.12 + i * 0.07), gy + (i % 2) * 6), 1.6)
	for k in G.sprouts.size():
		var s = G.sprouts[k]
		var x = W * 0.5 + (k - G.sprouts.size() / 2.0) * 26 + 40
		spr_feet(Art.sprout(s["sp"]), Vector2(x, gy + 10 - absf(sin(t * 6 + k)) * 6), 1.3, k % 2 == 1)
	spr_feet(Art.farmer(), Vector2(W * 0.42, gy + 8), 1.6)
	var w = minf(W - 20, 300)
	var r = Rect2(W / 2 - w / 2, maxf(28, H * 0.62 - 132), w, 124)
	panel(r, Color("fbf0d8", 0.96))
	txt(Vector2(W / 2, r.position.y + 18), "The " + f["n"] + "!", 14, col.darkened(0.4), 1)
	txt(Vector2(W / 2, r.position.y + 31), D.BOSSES[fest["season"]]["n"] + " was driven off!", 8, UI_INK, 1)
	var fr = 0
	for s in G.sprouts:
		fr += int(s["fr"])
	txt(Vector2(r.position.x + 14, r.position.y + 45), "Crops harvested: %d   Sprouts: %d" % [G.harvested_season, G.sprouts.size()], 8, UI_INK)
	txt(Vector2(r.position.x + 14, r.position.y + 57), "Sprout friendship: %d" % fr, 8, UI_INK)
	txt(Vector2(r.position.x + 14, r.position.y + 71), "Contest score: %d" % fest["score"], 9, UI_INK)
	var rn = ["Gold", "Silver", "Bronze"][fest["rib"]]
	var rc = [Color("e8b830"), Color("b8c0c8"), Color("c07a3a")][fest["rib"]]
	draw_circle(Vector2(r.end.x - 34, r.position.y + 58), 12, rc)
	draw_circle(Vector2(r.end.x - 34, r.position.y + 58), 8, rc.lightened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 42, r.position.y + 66), Vector2(r.end.x - 36, r.position.y + 66), Vector2(r.end.x - 44, r.position.y + 82)]), Color("d04a4a"))
	draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 32, r.position.y + 66), Vector2(r.end.x - 26, r.position.y + 66), Vector2(r.end.x - 24, r.position.y + 82)]), Color("d04a4a"))
	txt(Vector2(r.position.x + 14, r.position.y + 85), "%s ribbon! Prize: %d gold" % [rn, fest["prize"]], 9, rc.darkened(0.4))
	var nxt = "Finish the year" if fest["season"] >= 3 else "Continue to " + D.SEASONS[fest["season"] + 1]
	btn(Rect2(W / 2 - 75, r.end.y - 28, 150, 22), nxt, "fest_go", true, Color("ffd34a"), 10)

# ------------------------------------------------------------------ endings
func _draw_end() -> void:
	var win = mode == "win"
	draw_rect(Rect2(0, 0, W, H), Color("8fd0f0") if win else Color("2a2030"))
	grass(Rect2(0, H * 0.6, W, H * 0.4), 0 if win else 2)
	if not win:
		draw_rect(Rect2(0, 0, W, H), Color(0.2, 0.05, 0.2, 0.45))
	else:
		_petals(Color("ffb8d8"))
		if randf() < 0.06:
			burst(Vector2(randf_range(40, W - 40), randf_range(30, H * 0.4)), Color(randf(), randf(), 1.0), 26, 90, 30, 2)
	for k in G.sprouts.size():
		var s = G.sprouts[k]
		var bob = absf(sin(t * 5 + k)) * 5 if win else 0.0
		spr_feet(Art.sprout(s["sp"]), Vector2(W / 2 + (k - G.sprouts.size() / 2.0 + 0.5) * 30, H * 0.6 + 34 - bob), 1.5, false, Color.WHITE if win else Color(0.6, 0.5, 0.6))
	var title = "The Woods Bloom Again!" if win else "The Farm Has Withered..."
	txt(Vector2(W / 2, H * 0.2), title, 20, Color("fff3c0") if win else Color("e0c0e0"), 1, 6, Color("2a3a1a") if win else Color("1a0a1a"))
	var lines = ["You protected Willowmere all year." if win else "The blight took your last Heartroot.",
		"Sprouts found: %d/16 · Crops: %d" % [G.found.count(true), G.harvested_total], "Battles won: %d" % G.battles_won,
		"Bosses beaten: %d · Ribbons: %s" % [G.bosses, " ".join(PackedStringArray(G.ribbons.map(func(r): return ["Gold", "Silver", "Bronze"][r]))) if not G.ribbons.is_empty() else "none"]]
	for i in lines.size():
		txt(Vector2(W / 2, H * 0.2 + 22 + i * 13), lines[i], 9, Color.WHITE, 1, 3, Color(0, 0, 0, 0.6))
	btn(Rect2(W / 2 - 115, H * 0.2 + 80, 110, 22), "New farm", "retry", true, UI_ACC, 10)
	btn(Rect2(W / 2 + 5, H * 0.2 + 80, 110, 22), "Title screen", "title", true, Color("e8d8a8"), 10)
