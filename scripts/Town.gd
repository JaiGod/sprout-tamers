extends RefCounted
## Sprout Tamers - the town of Willowmere: market, workshop, clinic, mayor's requests.

var m
var panel: int = -1

func _init(main) -> void:
	m = main

func open() -> void:
	panel = -1

func _chat(i: int) -> void:
	var v = D.VILLAGERS[i]
	var line = v["lines"][(G.dayno + i) % v["lines"].size()]
	var extra = []
	if G.talked[i] != G.dayno:
		G.talked[i] = G.dayno
		G.vhearts[i] = mini(10, G.vhearts[i] + 1)
		extra.append(v["n"] + ": (Friendship with " + v["n"] + " grew! %d/10)" % G.vhearts[i])
	m.say([v["n"] + ": " + line] + extra)

func press(id: String) -> void:
	if id.begins_with("open"):
		panel = int(id.substr(4))
		Sfx.play("door")
		return
	match id:
		"close":
			panel = -1
		"chat":
			_chat(panel)
		"deliver":
			var rq = G.request
			if G.fill_request():
				Sfx.play("coin")
				m.toast("Delivered! +%d gold. %s is grateful." % [rq["gold"], D.VILLAGERS[rq["v"]]["n"]])
				m.burst(Vector2(m.W / 2, m.H / 2), Color("ffd34a"), 20, 90)
			else:
				m.toast("You don't have enough yet.")
		"sell":
			var n = G.bag_count()
			var g = G.sell_all()
			if n > 0:
				Sfx.play("coin")
				m.toast("Sold %d crops for %d gold!" % [n, g])
				m.burst(Vector2(m.W / 2, m.H / 2), Color("ffd34a"), 24, 90)
			else:
				m.toast("Your basket is empty.")
		"heal":
			if G.gold < 15:
				m.toast("Not enough gold.")
				return
			G.gold -= 15
			for s in G.sprouts:
				s["hp"] = G.stat(s, 0)
			Sfx.play("heal")
			m.toast("Juniper patched up all your sprouts.")
		"nursery":
			m.go("herd")
			m.herd.tab = 1
		_:
			if id.begins_with("buy"):
				var parts = id.substr(3).split("_")
				var n = int(parts[0])
				var c = int(parts[1])
				if G.buy_seed(c, n):
					Sfx.play("coin")
					m.toast("Bought %d %s seeds." % [n, D.CROPS[c]["n"]], 1.8)
				else:
					m.toast("Not enough gold.")
			elif id.begins_with("item_"):
				var k = id.substr(5)
				if G.buy_item(k):
					Sfx.play("coin")
					m.toast("Bought " + D.ITEMS[k]["n"] + ".", 1.8)
				else:
					m.toast("Not enough gold.")
			elif id.begins_with("up_"):
				var u = D.UPGRADES[int(id.substr(3))]
				var r = G.buy_upgrade(u)
				if r == "ok":
					Sfx.play("level")
					m.toast("Bram built the " + u["n"] + "!")
					m.shake = 3
				else:
					m.toast(r)

func key(k: int) -> void:
	if k in [KEY_1, KEY_2, KEY_3, KEY_4] and panel < 0:
		press("open%d" % (k - KEY_1))
	elif k in [KEY_X, KEY_BACKSPACE]:
		if panel >= 0:
			panel = -1
		else:
			m.go("farm")

func _house(r: Rect2, i: int) -> void:
	var roof = [Color("5a6ad0"), Color("4fae5a"), Color("a8603a"), Color("b05ab0")][i]
	var wall = [Color("f0e0c0"), Color("f8f0d8"), Color("d8c0a0"), Color("f0e8f8")][i]
	var body = Rect2(r.position.x + 4, r.position.y + r.size.y * 0.38, r.size.x - 8, r.size.y * 0.62)
	m.draw_rect(Rect2(body.position + Vector2(3, 3), body.size), Color(0, 0, 0, 0.25))
	m.draw_rect(body, wall)
	m.draw_rect(body, wall.darkened(0.4), false, 1)
	m.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 2, body.position.y + 2), Vector2(r.end.x + 2, body.position.y + 2), Vector2(r.get_center().x, r.position.y)]), roof)
	m.draw_polyline(PackedVector2Array([Vector2(r.position.x - 2, body.position.y + 2), Vector2(r.get_center().x, r.position.y), Vector2(r.end.x + 2, body.position.y + 2)]), roof.darkened(0.4), 1.5)
	var dw = body.size.x * 0.22
	m.draw_rect(Rect2(body.get_center().x - dw / 2, body.end.y - body.size.y * 0.5, dw, body.size.y * 0.5), Color("6a4228"))
	for wx in [body.position.x + body.size.x * 0.18, body.end.x - body.size.x * 0.18 - 10]:
		m.draw_rect(Rect2(wx, body.position.y + 8, 10, 9), Color("ffe9a0") if int(m.t * 0.5 + i) % 7 != 0 else Color("9ac8e0"))
		m.draw_rect(Rect2(wx, body.position.y + 8, 10, 9), Color("4a3020"), false, 1)
	if i == 1:
		for k in 5:
			m.draw_rect(Rect2(body.position.x + k * body.size.x / 5, body.position.y - 2, body.size.x / 5, 5), Color("e85a5a") if k % 2 == 0 else Color.WHITE)
	m.txt(Vector2(r.get_center().x, body.position.y - 4 - (3 if i == 1 else 0)), D.VILLAGERS[i]["role"], 8, Color.WHITE, 1, 3, Color(0, 0, 0, 0.7))

func draw() -> void:
	var W = m.W
	var H = m.H
	m.draw_rect(Rect2(0, 0, W, H), D.SEASON_SKY[G.season])
	for i in 5:
		m._ellipse(Vector2(fmod(i * 140.0 + m.t * 5, W + 80) - 40, 40 + i * 13 % 30), 30, 8, Color(1, 1, 1, 0.7))
	var ls = m.landscape()
	var gy = H * 0.5 if ls else H * 0.2
	m.grass(Rect2(0, gy, W, H - gy), G.season)
	var road = Rect2(0, gy + (H - gy) * 0.45 if ls else gy + 330, W, 26)
	m.draw_rect(road, Color("c8a878"))
	for x in range(0, int(W), 18):
		m.draw_rect(Rect2(x + 4, road.position.y + 12, 8, 2), Color("b0905e"))
	var ty = m.hud_h() + 16
	m.txt(Vector2(W / 2, ty), "Willowmere", 16, Color("fff3c0"), 1, 4, Color("3a4a2a"))
	m.txt(Vector2(W / 2, ty + 12), "Tap a villager" if m.narrow() else "Tap a villager (1-4) · X back to farm", 8, Color("2a3a1a"), 1)
	var n = 4
	for i in n:
		var r: Rect2
		if ls:
			var hw = minf(96.0, (W - 30) / 4.0 - 8)
			r = Rect2(15 + i * (W - 30) / 4.0 + ((W - 30) / 4.0 - hw) / 2, gy - 62, hw, 74)
		else:
			var hw = (W - 40) / 2.0
			r = Rect2(14 + (i % 2) * (hw + 12), gy + 10 + (i / 2) * 150, hw, 84)
		_house(r, i)
		var vp = Vector2(r.get_center().x + (r.size.x * 0.3), r.end.y + 22)
		var bob = absf(sin(m.t * 2 + i)) * 1.5
		m.spr_feet(Art.villager(i), vp - Vector2(0, bob), 1.6 if ls else 2.4)
		var hi = G.request.size() > 0 and not G.request["done"] and G.request["v"] == i
		if hi:
			m.txt(vp + Vector2(0, -32 if ls else -44), "!", 12, Color("ffd34a"), 1, 3)
		m.txt(Vector2(r.get_center().x, r.end.y + 34 if ls else r.end.y + 40), D.VILLAGERS[i]["n"], 8, Color.WHITE, 1, 3, Color(0, 0, 0, 0.7))
		m.buttons.append({"r": Rect2(r.position.x, r.position.y, r.size.x, r.size.y + 42), "id": "T:open%d" % i, "en": true, "nav": true})
	m.btn(Rect2(W / 2 - 60, H - 30, 120, 22), "Back to farm  [X]", "farm", true, Color("e8d8a8"))
	if panel >= 0:
		_draw_panel()

func _draw_panel() -> void:
	var W = m.W
	var H = m.H
	var v = D.VILLAGERS[panel]
	m.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.4))
	m.buttons = []
	var w = minf(W - 16, 380)
	var top = m.hud_h() + 6
	var h = minf(H - top - 6, 226 if not m.narrow() else 250)
	var r = Rect2(W / 2 - w / 2, top + (H - top - 6 - h) / 2, w, h)
	var nar = m.narrow()
	m.panel(r)
	m.spr(Art.villager(panel), r.position + Vector2(24, 26), 2.4)
	m.txt(r.position + Vector2(46, 18), v["n"] + ("" if nar else " · " + v["role"]), 11, m.UI_INK)
	for k in 10:
		m.heart(r.position + Vector2(50 + k * 9, 28), 2.3, Color("ff6a7a") if k < G.vhearts[panel] else Color("d8c8b0"))
	var by = r.position.y + 8 if not nar else r.end.y - 26
	m.btn(Rect2(r.end.x - 58, by, 50, 18), "Close", "T:close", true, Color("e8b8a0"), 8)
	m.btn(Rect2(r.end.x - 112, by, 50, 18), "Chat", "T:chat", true, Color("ffd8e8"), 8)
	var x0 = r.position.x + 10
	var y = r.position.y + 46
	var cw = r.size.x - 20
	match panel:
		0:
			var rq = G.request
			m.para(Rect2(x0, y, cw, 30), "\"Every season the blight creeps closer. Help the town and we'll help you.\"", 9, m.UI_INK, 2)
			y += 32
			if rq.is_empty() or rq["done"]:
				m.txt(Vector2(x0, y + 10), "No request today. Come back tomorrow!", 9, Color("5a7a3a"))
			else:
				m.panel(Rect2(x0, y, cw, 54), Color("fff8e0"))
				m.spr(Art.crop(rq["crop"], 3), Vector2(x0 + 20, y + 27), 2)
				m.txt(Vector2(x0 + 40, y + 16), "%s needs %d %s" % [D.VILLAGERS[rq["v"]]["n"], rq["qty"], D.CROPS[rq["crop"]]["n"]], 9, m.UI_INK)
				m.txt(Vector2(x0 + 40, y + 29), "You have %d · Reward %d gold + 2 hearts" % [G.bag[rq["crop"]], rq["gold"]], 8, Color("6a4a2a"))
				m.btn(Rect2(x0 + 40, y + 33, 100, 17), "Deliver", "T:deliver", G.bag[rq["crop"]] >= rq["qty"], m.UI_ACC, 8)
			y += 62
			m.para(Rect2(x0, y, cw, 40), "Town hearts add to your festival score. Chat with everyone each day!", 8, Color("7a6a5a"), 2)
		1:
			var opts = m.season_seeds()
			for k in opts.size():
				var c = opts[k]
				var cd = D.CROPS[c]
				var ry = y + k * 30
				m.spr(Art.crop(c, 3), Vector2(x0 + 10, ry + 10), 1.4)
				m.txt(Vector2(x0 + 24, ry + 9), ("%s %dg" if nar else "%s seeds  %dg") % [cd["n"], cd["c"]], 9, m.UI_INK)
				if nar:
					m.txt(Vector2(x0 + 24, ry + 20), "%dd · sells %dg · have %d" % [cd["d"], cd["v"], G.seeds[c]], 7, Color("6a4a2a"))
				else:
					m.txt(Vector2(x0 + 24, ry + 20), "%d days · sells %dg · %s · have %d" % [cd["d"], cd["v"], D.ELEM[cd["e"]], G.seeds[c]], 7, Color("6a4a2a"))
				var bw2 = 34.0 if nar else 46.0
				m.btn(Rect2(r.end.x - 12 - bw2 * 2 - 4, ry + 2, bw2, 20), "+1" if nar else "Buy 1", "T:buy1_%d" % c, G.gold >= cd["c"], m.UI_ACC, 8)
				m.btn(Rect2(r.end.x - 12 - bw2, ry + 2, bw2, 20), "+5" if nar else "Buy 5", "T:buy5_%d" % c, G.gold >= cd["c"] * 5, m.UI_ACC, 8)
			y += 92
			var val = 0
			for i in G.bag.size():
				val += G.bag[i] * int(D.CROPS[i]["v"])
			m.btn(Rect2(x0, y, cw, 22), "Sell basket: %d for %dg" % [G.bag_count(), val], "T:sell", G.bag_count() > 0, Color("ffd34a"), 9)
			y += 28
			var half = (cw - 6) / 2
			m.btn(Rect2(x0, y, half, 20), ("Nectar 25g (%d)" if nar else "Sweet Nectar 25g (%d)") % G.items["nectar"], "T:item_nectar", G.gold >= 25, Color("ffb8c8"), 8)
			m.btn(Rect2(x0 + half + 6, y, half, 20), ("Compost 45g (%d)" if nar else "Glow Compost 45g (%d)") % G.items["compost"], "T:item_compost", G.gold >= 45, Color("b0e07a"), 8)
		2:
			for k in D.UPGRADES.size():
				var u = D.UPGRADES[k]
				var ry = y + k * 30
				var owned = G.upgrades.has(u["id"]) and not u.get("repeat", false)
				m.txt(Vector2(x0, ry + 9), u["n"] + ("  (built)" if owned else "  %dg" % u["c"]), 9, m.UI_INK if not owned else Color("5a8a3a"))
				m.txt(Vector2(x0, ry + 20), u["desc"], 7, Color("6a4a2a"))
				var ok = not owned and G.gold >= int(u["c"]) and (not u.has("need") or G.upgrades.has(u["need"])) and (u["id"] != "heart" or G.hearts < 3)
				m.btn(Rect2(r.end.x - 70, ry + 2, 60, 20), "Built" if owned else "Build", "T:up_%d" % k, ok, Color("f0b07a"), 8)
		3:
			m.para(Rect2(x0, y, cw, 30), "\"Happy sprouts work hard and fight harder. Bring them by any time.\"", 9, m.UI_INK, 2)
			y += 32
			m.btn(Rect2(x0, y, cw, 22), "Heal all sprouts (15g)", "T:heal", G.gold >= 15, Color("8affa0"), 9)
			y += 28
			m.btn(Rect2(x0, y, cw, 22), "Dew Tonic 30g (have %d)" % G.items["tonic"], "T:item_tonic", G.gold >= 30, Color("9fd0ff"), 9)
			y += 28
			m.btn(Rect2(x0, y, cw, 22), "Open the Sprout Nursery", "T:nursery", true, Color("ffd8e8"), 9)
			y += 30
			m.para(Rect2(x0, y, cw, 40), "Breeding: two sprouts with 6+ friendship share a seed. The child inherits one trait from each parent.", 8, Color("7a6a5a"), 2)
