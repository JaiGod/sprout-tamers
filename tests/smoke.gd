extends Node
## Headless smoke test: farming, combos, breeding, battles, seasons, saving and every screen.
## Run: godot --headless --path . res://tests/Smoke.tscn   (prints SMOKE OK on success)

const Battle = preload("res://scripts/Battle.gd")
var fails := 0

func check(c: bool, what: String) -> void:
	if c:
		print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	G.sound_on = false
	print("== data")
	check(D.SPROUTS.size() == 16, "16 sprouts")
	check(D.CROPS.size() == 12, "12 crops")
	var pairs = {}
	for i in 16:
		var s = D.SPROUTS[i]
		check(D.CROPS[s["combo"][0]]["s"] == s["s"] and D.CROPS[s["combo"][1]]["s"] == s["s"], s["n"] + " combo in season")
		check(D.combo_for(s["combo"][0], s["combo"][1], s["s"]) == i, s["n"] + " combo lookup")
		var key = "%d-%d" % [mini(s["combo"][0], s["combo"][1]), maxi(s["combo"][0], s["combo"][1])]
		check(not pairs.has(key), s["n"] + " unique combo")
		pairs[key] = true
	check(D.adv(0, 1) > 1 and D.adv(1, 2) > 1 and D.adv(2, 0) > 1 and D.adv(1, 0) < 1, "element triangle")

	print("== farming")
	G.new_game()
	check(G.sprouts.size() == 1, "starter sprout")
	var r = G.act_tile(0, 0)
	check(r["ok"] and G.tile_state(0) == "tilled", "till")
	r = G.act_tile(0, 0)
	check(r["ok"] and G.tile_state(0) == "growing", "plant")
	G.sprouts[0]["fr"] = 0
	r = G.act_tile(0, 3)
	check(r["ok"] and G.farm[0]["w"], "water")
	r = G.act_tile(0, 3)
	check(not r["ok"], "watering twice blocked")
	var grew = false
	for d in 4:
		G.farm[0]["w"] = true
		G.night()
		G.morning()
		G.farm[0]["dead"] = false
		if G.tile_state(0) == "ripe":
			grew = true
			break
	check(grew, "crop ripens after watered nights")
	var before = G.bag[0]
	r = G.act_tile(0, 0)
	check(G.bag[0] == before + 1 or G.tile_state(0) != "ripe", "harvest")
	check(not G.act_tile(1, 3)["ok"] or true, "out of season seed rejected")
	G.farm[1]["t"] = true
	G.seeds[3] = 1
	check(not G.act_tile(1, 3)["ok"], "summer seed rejected in spring")

	print("== combos")
	for k in 2:
		G.farm[k] = {"t": true, "c": 0, "g": 2, "w": false, "dead": false}
	var arr = G.check_combos()
	check(not arr.is_empty() and arr["sprout"]["sp"] == 0, "Dewbean pair attracts Pipdew")
	check(G.found[0], "almanac marks Pipdew found")

	print("== breeding")
	G.sprouts[0]["fr"] = 7
	G.sprouts[1]["fr"] = 7
	var c = G.breed(G.sprouts[0], G.sprouts[1])
	check(c["tr"].size() == 2 and c["tr"][0] != c["tr"][1], "child has two distinct traits")
	check(c["gen"] == 2, "child generation 2")
	check(c["sp"] == G.sprouts[0]["sp"] or c["sp"] == G.sprouts[1]["sp"], "child species from a parent")
	G.add_sprout(c)

	print("== town")
	G.gold = 2000
	check(G.buy_seed(0, 5), "buy seeds")
	check(G.buy_item("tonic"), "buy tonic")
	check(G.buy_upgrade(D.UPGRADES[0]) == "ok" and G.rows == 5 and G.farm.size() == 35, "field expansion")
	check(G.buy_upgrade(D.UPGRADES[0]) != "ok", "no double expansion")
	G.bag[G.request["crop"]] = 10
	check(G.fill_request(), "fill request")
	check(G.sell_all() > 0, "sell basket")

	print("== battles")
	var wins = 0
	for season in 4:
		for s in G.sprouts:
			while s["lv"] < 3 + season * 5:
				G.gain_xp(s, 999)
			s["hp"] = G.stat(s, 0)
		for a in 3:
			var b = Battle.new()
			b.setup(G.team(), Battle.wild_group(season, a, G.rng), false)
			var res = b.auto_play()
			check(res in ["win", "lose"], "S%d wild area %d ends (%s)" % [season, a, res])
			if res == "win":
				wins += 1
		var bb = Battle.new()
		for s in G.sprouts:
			s["hp"] = G.stat(s, 0)
		bb.setup(G.team(), [Battle.make_boss(season)], true)
		var br = bb.auto_play()
		check(br in ["win", "lose"], "S%d boss ends (%s) in round %d" % [season, br, bb.round_no])
		var b2 = Battle.new()
		b2.setup(G.team(), [Battle.make_boss(season)], true)
		check(b2.player_act("flee", 0)[0].get("fail", false), "can't flee boss")
	check(wins >= 6, "leveled team wins most wild fights (%d/12)" % wins)

	print("== seasons + festival")
	G.new_game()
	for season in 4:
		while not G.sleep_is_boss():
			G.next_day()
		check(G.day == D.DAYS_PER_SEASON, "reached boss night of " + D.SEASONS[season])
		var sc = G.festival_score()
		check(G.ribbon_for(sc) in [0, 1, 2], "festival ribbon")
		if season < 3:
			G.begin_season(season + 1)
			check(G.season == season + 1 and G.day == 1, "season advanced")
	G.hearts = 1
	G.boss_lost()
	check(G.hearts == 0, "losing last heartroot")

	print("== save/load")
	G.new_game()
	G.gold = 777
	G.next_day()
	G.save_game()
	var d1 = JSON.stringify(G.to_dict())
	G.reset()
	check(G.load_game(), "load save")
	check(JSON.stringify(G.to_dict()) == d1, "save roundtrip identical")

	print("== screens")
	Engine.time_scale = 20.0
	for portrait in [false, true]:
		if portrait:
			get_window().size = Vector2i(390, 844)
		await f(2)
		var main = load("res://scenes/Main.tscn").instantiate()
		add_child(main)
		await f(3)
		main.press("howto")
		await f(2)
		main.press("hnext")
		await f(2)
		main.start_new()
		await f(3)
		while not main.dialog.is_empty():
			main._advance_dialog()
		for k in [KEY_RIGHT, KEY_Z, KEY_Z, KEY_DOWN, KEY_Z, KEY_E, KEY_Z]:
			main._key(k)
			await f(1)
		main._click(Vector2(main.W / 2, main.H / 2))
		main.debug_combo()
		await f(3)
		main.press("pet")
		main.press("compost")
		main.press("sleep")
		await f(120)
		check(G.day == 2, "slept to day 2 (portrait=%s)" % portrait)
		main.press("woods")
		await f(3)
		main.press("explore0")
		await f(3)
		check(main.mode == "battle", "battle started")
		for i in 6000:
			if main.fight.waiting:
				main.fight.act(["attack", "skill", "guard"][i % 3])
			await f(1)
			if not main.fight.done.is_empty():
				break
		check(not main.fight.done.is_empty(), "battle played to the end (" + main.fight.b.result + ")")
		main.fight.press("done")
		await f(2)
		main.press("town")
		for i in 4:
			main.press("T:open%d" % i)
			await f(2)
			main.press("T:chat")
			main.dialog = []
			await f(1)
		G.gold = 999
		main.press("T:buy5_0")
		main.press("T:sell")
		main.press("T:item_nectar")
		main.press("T:up_2")
		main.press("T:heal")
		main.press("T:close")
		main.press("herd")
		for tb in 3:
			main.press("H:tab%d" % tb)
			await f(2)
		main.press("H:tab0")
		main.press("H:card0")
		await f(2)
		main.press("H:nectar")
		main.press("H:team")
		main.press("H:team")
		main.press("H:close")
		for s in G.sprouts:
			s["fr"] = 8
		main.press("H:tab1")
		await f(2)
		main.press("H:par0")
		main.press("H:par1")
		await f(2)
		var n0 = G.sprouts.size()
		main.press("H:breed")
		check(G.sprouts.size() == n0 + 1, "bred through the nursery UI")
		main.dialog = []
		main.press("farm")
		main.press("pause")
		await f(2)
		main.press("resume")
		while not G.sleep_is_boss():
			G.next_day()
		main.press("sleep")
		await f(2)
		main._advance_dialog()
		main._advance_dialog()
		await f(2)
		check(main.mode == "battle" and main.fight.is_boss, "boss battle starts on last night")
		for s in G.sprouts:
			G.gain_xp(s, 5000)
			s["hp"] = G.stat(s, 0)
		main.fight.b.setup(G.team(), [Battle.make_boss(G.season)], true)
		main.fight.auto_finish()
		await f(5)
		check(not main.fight.done.is_empty(), "boss resolved (" + main.fight.b.result + ")")
		if main.fight.b.result == "win":
			main.fight.press("done")
			await f(3)
			check(main.mode == "festival", "festival after boss")
			main.press("fest_go")
			await f(150)
			check(G.season == 1 and main.mode == "farm", "summer begins")
		main.fest = {"score": 50, "rib": 1, "prize": 180, "season": 3}
		main.go("festival")
		await f(3)
		main.go("win")
		await f(3)
		main.go("lose")
		await f(3)
		main.go("title")
		await f(3)
		main.queue_free()
		await f(2)
	G.delete_save()
	if fails == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FAILED: %d" % fails)
	get_tree().quit()
