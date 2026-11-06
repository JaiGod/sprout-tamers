extends RefCounted
## Sprout Tamers - sprout roster, nursery (breeding) and the 16-sprout almanac.

var m
var tab: int = 0
var sel: int = -1
var pa: int = -1
var pb: int = -1

func _init(main) -> void:
	m = main

func open() -> void:
	sel = -1
	pa = -1
	pb = -1

func press(id: String) -> void:
	if id.begins_with("tab"):
		tab = int(id.substr(3))
		sel = -1
		return
	if id.begins_with("card"):
		sel = int(id.substr(4))
		return
	if id.begins_with("par"):
		var i = int(id.substr(3))
		if pa == i:
			pa = -1
		elif pb == i:
			pb = -1
		elif pa < 0:
			pa = i
		else:
			pb = i
		return
	match id:
		"close": sel = -1
		"pet":
			m.pet(G.sprouts[sel])
		"nectar":
			if G.items["nectar"] <= 0:
				m.toast("No Sweet Nectar. Tilly sells it.")
				return
			G.items["nectar"] -= 1
			G.befriend(G.sprouts[sel], 2)
			Sfx.play("pet")
			m.burst(Vector2(m.W / 2, m.H / 2), Color("ff9ab8"), 16, 60, -20)
			m.toast(G.sp_name(G.sprouts[sel]) + " loved the nectar! (%d/10)" % G.sprouts[sel]["fr"])
		"team":
			var s = G.sprouts[sel]
			if s["team"]:
				s["team"] = false
			else:
				var n = 0
				for o in G.sprouts:
					if o["team"]:
						n += 1
				if n >= 3:
					m.toast("Your battle team is full (3). Remove one first.")
					return
				s["team"] = true
		"breed": _breed()

func _breed() -> void:
	if pa < 0 or pb < 0:
		return
	if G.bred_day == G.dayno:
		m.toast("The nursery needs a day to rest.")
		return
	if G.sprouts.size() >= G.MAX_SPROUTS:
		m.toast("Your farm is full (8 sprouts).")
		return
	if G.gold < 60:
		m.toast("Breeding costs 60 gold.")
		return
	G.gold -= 60
	var c = G.breed(G.sprouts[pa], G.sprouts[pb])
	G.add_sprout(c)
	Sfx.play("sprout")
	m.shake = 3
	m.burst(Vector2(m.W / 2, m.H / 2), Color("ffe27a"), 30, 100)
	var lines = ["Juniper: A seedling sprout! It's a %s (generation %d)." % [G.sp_name(c), c["gen"]],
		"Juniper: It inherited %s and %s. Potential %d." % [c["tr"][0], c["tr"][1], c["pot"]]]
	if c.get("mut", false):
		lines.append("Juniper: Ooh, a mutation! That trait is brand new to the family.")
	m.say(lines)
	pa = -1
	pb = -1

func key(k: int) -> void:
	if k in [KEY_X, KEY_BACKSPACE]:
		if sel >= 0:
			sel = -1
		else:
			m.go("farm")
	elif k in [KEY_1, KEY_2, KEY_3]:
		press("tab%d" % (k - KEY_1))

func draw() -> void:
	var W = m.W
	var H = m.H
	m.draw_rect(Rect2(0, 0, W, H), Color("2a3a24"))
	m.grass(Rect2(0, 0, W, H), G.season)
	m.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.3))
	var names = ["Sprouts", "Nursery", "Almanac"] if m.narrow() else ["Sprouts [1]", "Nursery [2]", "Almanac [3]"]
	var fw = 44.0 if m.narrow() else 62.0
	var tw = minf(110.0, (W - 24 - fw) / 3.0 - 4)
	var ty = m.hud_h() + 5
	for k in 3:
		m.btn(Rect2(10 + k * (tw + 4), ty, tw, 18), names[k], "H:tab%d" % k, true, Color("ffe27a") if tab == k else Color("cfc3a0"), 8)
	m.btn(Rect2(W - fw - 10, ty, fw, 18), "Farm" if m.narrow() else "Farm [X]", "farm", true, Color("e8d8a8"), 8)
	var area = Rect2(10, ty + 23, W - 20, H - ty - 29)
	match tab:
		0: _roster(area)
		1: _nursery(area)
		2: _almanac(area)
	if sel >= 0 and sel < G.sprouts.size() and tab == 0:
		_detail()

func _card(r: Rect2, s: Dictionary, id: String, hl: bool) -> void:
	m.buttons.append({"r": r, "id": id, "en": true, "nav": true})
	var idx = m.buttons.size() - 1
	var foc = m.focus == idx or r.has_point(m.last_mouse)
	m.panel(r, Color("fff4d8") if hl else (Color("f4ead0").lightened(0.1) if foc else Color("f4ead0")), Color("d0a030") if hl else m.UI_EDGE)
	if m.focus == idx:
		m.draw_rect(r.grow(2), Color("ffe27a"), false, 1.5)
	var sd = D.SPROUTS[s["sp"]]
	m.spr_feet(Art.sprout(s["sp"]), r.position + Vector2(20, r.size.y - 8 - absf(sin(m.t * 4 + s["id"])) * 2), 1.5)
	m.txt(r.position + Vector2(40, 13), sd["n"], 9, m.UI_INK)
	m.txt(r.position + Vector2(40, 24), "Lv %d · %s" % [s["lv"], D.JOB_NAME[sd["job"]]], 7, Color("6a4a2a"))
	m.draw_circle(r.position + Vector2(r.size.x - 9, 9), 3, D.ELEM_COL[sd["e"]])
	for k in 10:
		m.heart(r.position + Vector2(42 + k * 6.5, 31), 1.6, Color("ff6a7a") if k < s["fr"] else Color("d8c8b0"))
	if s["team"]:
		m.txt(r.position + Vector2(r.size.x - 6, r.size.y - 5), "TEAM", 7, Color("3a7a2a"), 2)
	if s["gen"] > 1:
		m.txt(r.position + Vector2(40, r.size.y - 5), "Gen %d" % s["gen"], 7, Color("8a5ab0"))

func _grid(area: Rect2, n: int) -> Array:
	var cols = 4 if m.landscape() else 2
	if m.landscape() and area.size.x < 400:
		cols = 3
	var cw = (area.size.x - (cols - 1) * 6) / cols
	var ch = 46.0
	var out = []
	for i in n:
		out.append(Rect2(area.position.x + (i % cols) * (cw + 6), area.position.y + (i / cols) * (ch + 6), cw, ch))
	return out

func _roster(area: Rect2) -> void:
	var rects = _grid(area, G.sprouts.size())
	for i in G.sprouts.size():
		_card(rects[i], G.sprouts[i], "H:card%d" % i, false)
	var y = (rects[-1].end.y if not rects.is_empty() else area.position.y) + 14
	m.para(Rect2(area.position.x, y - 9, area.size.x, 30), "%d/%d sprouts · tap one for details. Team of 3 fights in battles." % [G.sprouts.size(), G.MAX_SPROUTS], 8, Color("e8f0d0"), 2)

func _detail() -> void:
	var W = m.W
	var H = m.H
	var s = G.sprouts[sel]
	var sd = D.SPROUTS[s["sp"]]
	m.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	m.buttons = []
	var nar = m.narrow()
	var w = minf(W - 16, 340)
	var h = minf(H - 34, 210 if not nar else 290)
	var r = Rect2(W / 2 - w / 2, 28 + (H - 34 - h) / 2, w, h)
	m.panel(r)
	var dy = 0.0
	var sx = 86.0
	if nar:
		dy = 60.0
		sx = 10.0
	m.draw_circle(r.position + Vector2(44, 62), 30, D.ELEM_COL[sd["e"]].lightened(0.5))
	m.spr_feet(Art.sprout(s["sp"]), r.position + Vector2(44, 88 - absf(sin(m.t * 4)) * 3), 3.0)
	m.txt(r.position + Vector2(86, 20), "%s  Lv %d" % [sd["n"], s["lv"]], 12, m.UI_INK)
	m.txt(r.position + Vector2(86, 32), "%s · %s" % [D.ELEM[sd["e"]], D.JOB_NAME[sd["job"]]] if nar else "%s · %s · Gen %d · Potential %d" % [D.ELEM[sd["e"]], D.JOB_NAME[sd["job"]], s["gen"], s["pot"]], 8, Color("6a4a2a"))
	if nar:
		m.txt(r.position + Vector2(86, 44), "Gen %d · Potential %d" % [s["gen"], s["pot"]], 8, Color("6a4a2a"))
	m.para(Rect2(r.position.x + sx, r.position.y + 35 + (35 if nar else 0), w - sx - 10, 30), sd["desc"], 8, Color("7a6a5a"), 2)
	var st = ["HP", "ATK", "DEF", "SPD"]
	for k in 4:
		var x = r.position.x + sx + (k % 2 * 70 if nar else k * 58)
		m.txt(Vector2(x, r.position.y + 60 + dy + (k / 2 * 12 if nar else 0)), "%s %d" % [st[k], G.stat(s, k)], 9, m.UI_INK)
	var xy = r.position.y + 74 + dy + (12 if nar else 0)
	m.txt(Vector2(r.position.x + sx, xy), "XP", 8, m.UI_INK)
	m.bar(Rect2(r.position.x + sx + 16, xy - 6, 100, 6), float(s["xp"]) / G.xp_next(s), Color("ffd34a"))
	m.txt(Vector2(r.position.x + sx + (0 if nar else 124), xy + (13 if nar else 0)), "Friendship %d/10" % s["fr"], 8, Color("c04a6a"))
	var dy2 = dy + (26 if nar else 0)
	for k in 2:
		var tn = s["tr"][k]
		var tr = Rect2(r.position.x + 10 + k * (w - 20) / 2.0, r.position.y + 104 + dy2, (w - 26) / 2.0, 30)
		if nar:
			tr = Rect2(r.position.x + 10, r.position.y + 104 + dy2 + k * 34, w - 20, 30)
		m.panel(tr, Color("fff8e0"))
		m.txt(tr.position + Vector2(6, 13), tn, 9, Color("3a6a2a"))
		m.txt(tr.position + Vector2(6, 24), D.TRAITS[tn], 7, Color("6a4a2a"))
	dy2 += 34 if nar else 0
	var job = {"water": "Waters 3+ plots each morning", "harvest": "Gathers 2+ ripe crops each morning", "guard": "Chases off blight mites at night"}[sd["job"]]
	if nar:
		m.para(Rect2(r.position.x + 10, r.position.y + 141 + dy2, w - 20, 30), "Job: " + job + (" (needs 3 friendship)" if s["fr"] < 3 else " (working!)"), 8, m.UI_INK, 2)
	else:
		m.txt(Vector2(r.position.x + 10, r.position.y + 150), "Job: " + job + (" (needs 3 friendship)" if s["fr"] < 3 else " (working!)"), 8, m.UI_INK)
	var bw = (w - 20 - 12) / 4.0
	var y = r.end.y - 30
	m.btn(Rect2(r.position.x + 10, y, bw, 20), "Pet", "H:pet", s["pet"] != G.dayno, Color("ffb8c8"), 8)
	m.btn(Rect2(r.position.x + 14 + bw, y, bw, 20), ("Treat %d" if nar else "Nectar (%d)") % G.items["nectar"], "H:nectar", G.items["nectar"] > 0 and s["fr"] < 10, Color("ffd8e8"), 8)
	m.btn(Rect2(r.position.x + 18 + bw * 2, y, bw, 20), ("- Team" if nar else "Leave team") if s["team"] else ("+ Team" if nar else "Join team"), "H:team", true, Color("9fd0ff"), 8)
	m.btn(Rect2(r.position.x + 22 + bw * 3, y, bw, 20), "Close", "H:close", true, Color("e8b8a0"), 8)

func _nursery(area: Rect2) -> void:
	var ok = []
	for i in G.sprouts.size():
		if G.can_breed(G.sprouts[i]):
			ok.append(i)
	m.panel(Rect2(area.position.x, area.position.y, area.size.x, 46), Color("fff4e8"))
	var info = "Pick two sprouts with 6+ friendship. The seedling takes the species of one parent, one trait from each, and +1 potential. Cost 60g, once a day."
	m.para(Rect2(area.position.x + 8, area.position.y + 4, area.size.x - 16, 40), info, 8, m.UI_INK, 3)
	var sub = Rect2(area.position.x, area.position.y + 52, area.size.x, area.size.y - 52)
	if ok.is_empty():
		m.para(Rect2(sub.position.x, sub.position.y + 6, sub.size.x, 40), "No sprout is close enough to you yet. Pet them daily, share Sweet Nectar and battle together to reach 6 friendship.", 9, Color("f0f8e0"), 3)
		return
	var rects = _grid(Rect2(sub.position.x, sub.position.y, sub.size.x, sub.size.y - 50), ok.size())
	for k in ok.size():
		_card(rects[k], G.sprouts[ok[k]], "H:par%d" % ok[k], ok[k] == pa or ok[k] == pb)
	var y = rects[-1].end.y + 8
	var label = "Choose parent A and parent B"
	if pa >= 0 and pb >= 0:
		var a = G.sprouts[pa]
		var b = G.sprouts[pb]
		label = "%s + %s: %s or %s seedling" % [G.sp_name(a), G.sp_name(b), G.sp_name(a), G.sp_name(b)]
	elif pa >= 0:
		label = G.sp_name(G.sprouts[pa]) + " + ?"
	m.txt(Vector2(area.position.x, y + 10), label, 9, Color("fff3c0"))
	var can = pa >= 0 and pb >= 0 and G.bred_day != G.dayno and G.gold >= 60 and G.sprouts.size() < G.MAX_SPROUTS
	m.btn(Rect2(area.end.x - 110, y, 110, 22), "Breed (60g)", "H:breed", can, Color("ffd8e8"), 9)
	if G.bred_day == G.dayno:
		m.txt(Vector2(area.position.x, y + 22), "The nursery is resting until tomorrow.", 8, Color("e0c0c0"))

func _almanac(area: Rect2) -> void:
	var ls = m.landscape()
	var cols = 8 if ls else 4
	var cw = (area.size.x - (cols - 1) * 4) / cols
	var ch = 50.0 if ls else 72.0
	var head = "Found %d / 16 · grow these crop pairs side by side, ripe, to attract each sprout." % G.found.count(true)
	m.para(Rect2(area.position.x, area.position.y - 1, area.size.x, 24), head, 8, Color("fff3c0"), 2)
	if not ls:
		area.position.y += 12
	for i in 16:
		var sd = D.SPROUTS[i]
		var r = Rect2(area.position.x + (i % cols) * (cw + 4), area.position.y + 14 + (i / cols) * (ch + 4), cw, ch)
		var f = G.found[i]
		m.draw_rect(r, Color(1, 1, 1, 0.85) if f else Color(0.1, 0.1, 0.1, 0.5))
		m.draw_rect(r, D.SEASON_TINT[sd["s"]], false, 1.5)
		m.spr_feet(Art.sprout(i), Vector2(r.get_center().x, r.position.y + (26 if ls else 34)), 1.1 if ls else 1.6, false, Color.WHITE if f else Color(0, 0, 0, 0.75))
		m.txt(Vector2(r.get_center().x, r.position.y + (35 if ls else 45)), sd["n"] if f else "???", 7, m.UI_INK if f else Color("c0c0c0"), 1)
		if sd["s"] <= G.season or f:
			var c = sd["combo"]
			m.spr(Art.crop(c[0], 3), Vector2(r.get_center().x - 8, r.end.y - 7), 0.7 if ls else 1.0)
			m.txt(Vector2(r.get_center().x, r.end.y - 3), "+", 8, m.UI_INK if f else Color.WHITE, 1)
			m.spr(Art.crop(c[1], 3), Vector2(r.get_center().x + 8, r.end.y - 7), 0.7 if ls else 1.0)
		else:
			m.txt(Vector2(r.get_center().x, r.end.y - 4), D.SEASONS[sd["s"]], 7, Color("a0a0a0"), 1)
	var y = area.position.y + 14 + 2 * (ch + 4) * (2 if not ls else 1) + 10
	if ls:
		y = area.position.y + 14 + 2 * (ch + 4) + 10
	else:
		y = area.position.y + 14 + 4 * (ch + 4) + 10
	var tip = "Tip: crop icons show each sprout's combo. Combos only work in their own season."
	m.para(Rect2(area.position.x, y, area.size.x, 30), tip, 8, Color("e8f0d0"), 2)
