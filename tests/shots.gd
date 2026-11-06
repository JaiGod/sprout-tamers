extends Node
## Captures README screenshots (needs a display, e.g. xvfb-run). SHOTS=<dir>, PORTRAIT=1 for the phone layout.
var main
var out := "user://"
var portrait := false

func _ready() -> void:
	out = OS.get_environment("SHOTS") if OS.get_environment("SHOTS") != "" else "user://"
	portrait = OS.get_environment("PORTRAIT") == "1"
	_run.call_deferred()

func f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var w := 900 if not portrait else 420
	var j: Image = img.duplicate()
	j.resize(w, int(float(w) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	j.save_jpg(out + "/" + name + ".jpg", 0.72)
	print("[shot] ", name)

func stage_farm() -> void:
	G.new_game()
	G.gold = 640
	G.day = 3
	G.dayno = 2
	var plan = {7: [0, 2], 8: [0, 2], 9: [2, 2], 10: [2, 1], 11: [1, 3], 14: [1, 1], 15: [0, 0], 16: [0, 1], 17: [2, 0], 18: [1, 2],
		21: [2, 2], 22: [1, 3], 23: [0, 2], 24: [2, 1]}
	for i in plan:
		G.farm[i] = {"t": true, "c": plan[i][0], "g": plan[i][1], "w": i % 3 != 0, "dead": false}
	G.farm[1]["t"] = true
	G.farm[2]["t"] = true
	G.farm[25] = {"t": true, "c": 1, "g": 1, "w": false, "dead": true}
	for sp in [0, 2, 3]:
		var s = G.make_sprout(sp)
		s["fr"] = 5
		G.add_sprout(s)
	G.seeds = [6, 3, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for s in G.sprouts:
		s["lv"] = 4
		s["hp"] = G.stat(s, 0)

func _run() -> void:
	get_window().size = Vector2i(390, 844) if portrait else Vector2i(1280, 720)
	G.sound_on = false
	G.best = {"found": 9, "bosses": 3, "wins": 1}
	for i in 16:
		G.found[i] = i < 9
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await f(30)
	if portrait:
		main.start_new()
		main.dialog = []
		stage_farm()
		main.go("farm")
		main.cursor = 9
		await get_tree().create_timer(1.5).timeout
		await snap("mobile")
		main.press("woods")
		main.press("explore0")
		await get_tree().create_timer(2.6).timeout
		await snap("mobile_battle")
		get_tree().quit()
		return
	await get_tree().create_timer(1.0).timeout
	await snap("title")
	main.start_new()
	main.dialog = []
	stage_farm()
	main.go("farm")
	main.cursor = 9
	await get_tree().create_timer(2.0).timeout
	await snap("farm")
	# battle
	G.season = 1
	main.fight.start_wild(1)
	var t0 = 0
	while not main.fight.waiting and t0 < 300:
		await f(1)
		t0 += 1
	main.fight.act("skill")
	await get_tree().create_timer(0.7).timeout
	await snap("battle")
	main.fight.auto_finish()
	await get_tree().create_timer(0.5).timeout
	G.season = 0
	# town market
	main.go("town")
	await f(5)
	await snap("town")
	main.town.panel = 1
	await f(5)
	await snap("market")
	# sprouts + almanac
	G.sprouts[1]["fr"] = 7
	G.sprouts[2]["fr"] = 6
	main.go("herd")
	main.herd.tab = 2
	await f(10)
	await snap("almanac")
	main.herd.tab = 0
	main.herd.sel = 1
	await f(10)
	await snap("sprout")
	# boss
	main.go("farm")
	G.season = 2
	main.fight.start_boss()
	t0 = 0
	while not main.fight.waiting and t0 < 400:
		await f(1)
		t0 += 1
	await snap("boss")
	# festival
	G.season = 0
	G.harvested_season = 22
	main.open_festival()
	await get_tree().create_timer(1.6).timeout
	await snap("festival")
	get_tree().quit()
