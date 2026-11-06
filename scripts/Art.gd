extends Node
## Sprout Tamers - every sprite is painted pixel by pixel at startup. Autoloaded as "Art".

var cache: Dictionary = {}

func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, shade: bool = false, ymax: int = 999) -> void:
	for y in mini(img.get_height(), ymax):
		for x in img.get_width():
			var dx = (x + 0.5 - cx) / rx
			var dy = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var col = c
				if shade:
					if dy > 0.35:
						col = c.darkened(0.18)
					elif dx < -0.2 and dy < -0.2:
						col = c.lightened(0.22)
				img.set_pixel(x, y, col)

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)

func _outline(img: Image, oc: Color) -> void:
	var src = img.duplicate()
	var w = img.get_width()
	var h = img.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx = x + d.x
				var ny = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.1:
					img.set_pixel(x, y, oc)
					break

func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

func _map(rows: Array, pal: Dictionary) -> Image:
	var img = _img(rows[0].length(), rows.size())
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			var ch = r[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return img

# ------------------------------------------------------------------ sprouts
func sprout(i: int) -> ImageTexture:
	var key = "s%d" % i
	if cache.has(key):
		return cache[key]
	var s = D.SPROUTS[i]
	var img = _img(20, 20)
	var c: Color = s["col"]
	var c2: Color = s["col2"]
	var cy = 13.0
	match int(s["shape"]):
		0:
			_ell(img, 10, 13.5, 6.5, 5.5, c, true)
		1:
			_ell(img, 10, 13, 5, 6.5, c, true)
			cy = 12.0
		2:
			_ell(img, 10, 14.5, 8, 4.6, c, true)
			cy = 14.0
		3:
			_ell(img, 10, 14, 6, 5, c, true)
			_ell(img, 10, 10.5, 3.5, 3.5, c, false)
			cy = 13.0
	# feet
	_px(img, 7, 19, c.darkened(0.45)); _px(img, 8, 19, c.darkened(0.45))
	_px(img, 12, 19, c.darkened(0.45)); _px(img, 13, 19, c.darkened(0.45))
	# top decoration
	match int(s["top"]):
		0:
			_rect(img, 10, 5, 1, 4, c2.darkened(0.2))
			_ell(img, 7.5, 5, 2.6, 1.6, c2, false)
			_ell(img, 12.5, 4, 2.6, 1.6, c2.lightened(0.15), false)
		1:
			_rect(img, 10, 6, 1, 3, Color("3d9a3a"))
			for a in 5:
				var ang = a * TAU / 5.0
				_ell(img, 10.5 + cos(ang) * 2.2, 4.5 + sin(ang) * 2.2, 1.6, 1.6, c2, false)
			_ell(img, 10.5, 4.5, 1.2, 1.2, Color("ffe066"), false)
		2:
			_ell(img, 10, 8.5, 7.5, 4.6, c2, true, 9)
			_px(img, 7, 6, Color.WHITE); _px(img, 12, 5, Color.WHITE); _px(img, 14, 7, Color.WHITE); _px(img, 6, 8, Color.WHITE)
		3:
			_rect(img, 10, 4, 1, 4, Color("3d7a3a"))
			_ell(img, 8, 5, 1.8, 1.8, c2, true); _ell(img, 12, 5, 1.8, 1.8, c2, true); _ell(img, 10, 3, 1.8, 1.8, c2.lightened(0.15), true)
		4:
			_ell(img, 10, 5.5, 2.8, 3.4, c2.darkened(0.1), false)
			_ell(img, 10, 6, 1.6, 2.2, Color("fff3b0"), false)
			_px(img, 10, 1, c2)
		5:
			for y in 6:
				var hw = 3 - absi(y - 3)
				_rect(img, 10 - hw, 2 + y, hw * 2 + 1, 1, c2 if y < 3 else c2.darkened(0.15))
			_px(img, 9, 3, Color.WHITE)
		6:
			for y in 6:
				_rect(img, 10 - y / 2, 2 + y, y + 1, 1, c2 if y % 2 == 0 else c2.lightened(0.15))
		7:
			_ell(img, 10, 5, 2.2, 4, c2.lerp(Color("f5d34a"), 0.5), true)
			_ell(img, 7, 7, 1.4, 3, c2, false); _ell(img, 13, 7, 1.4, 3, c2, false)
		8:
			_rect(img, 10, 4, 1, 5, c2.darkened(0.15))
			_px(img, 11, 3, c2); _px(img, 12, 3, c2); _px(img, 12, 4, c2); _px(img, 9, 5, c2); _px(img, 8, 5, c2)
		9:
			for a in 6:
				var ang = a * TAU / 6.0 - PI / 2
				var col = [Color("ff8ad8"), Color("7fffd0"), Color("9fd0ff"), Color("ffe07a"), Color("c8a0ff"), Color("8affa0")][a]
				_ell(img, 10.5 + cos(ang) * 2.6, 4.5 + sin(ang) * 2.6, 1.5, 1.5, col, false)
			_ell(img, 10.5, 4.5, 1.2, 1.2, Color.WHITE, false)
	# face
	var ey = int(cy)
	var dark = Color("2a1e2e")
	_px(img, 7, ey, dark); _px(img, 7, ey + 1, dark); _px(img, 13, ey, dark); _px(img, 13, ey + 1, dark)
	_px(img, 7, ey, Color.WHITE)
	_px(img, 13, ey, Color.WHITE)
	_px(img, 6, ey + 2, Color("ff8a9a", 0.8)); _px(img, 14, ey + 2, Color("ff8a9a", 0.8))
	_px(img, 9, ey + 2, dark); _px(img, 10, ey + 3, dark); _px(img, 11, ey + 2, dark)
	_outline(img, c.darkened(0.6))
	cache[key] = _tex(img)
	return cache[key]

# ------------------------------------------------------------------ blights
func blight(i: int, is_boss: bool = false) -> ImageTexture:
	var key = ("B%d" if is_boss else "b%d") % i
	if cache.has(key):
		return cache[key]
	var sz = 36 if is_boss else 20
	var col: Color = D.BOSSES[i]["col"] if is_boss else D.BLIGHTS[i]["col"]
	var r = RandomNumberGenerator.new()
	r.seed = i * 977 + (5 if is_boss else 1)
	var img = _img(sz, sz)
	var c = sz / 2.0
	var rr = sz * 0.34
	# thorns
	for k in (14 if is_boss else 8):
		var ang = r.randf() * TAU
		var ln = rr + r.randf_range(2, sz * 0.16)
		for t in int(ln):
			_px(img, int(c + cos(ang) * t), int(c + 1 + sin(ang) * t), col.darkened(0.35))
	_ell(img, c, c + 1, rr, rr * 0.9, col, true)
	# blotches
	for k in 5:
		_ell(img, c + r.randf_range(-rr * 0.6, rr * 0.6), c + r.randf_range(-rr * 0.4, rr * 0.6), 1.6, 1.3, col.lightened(0.25), false)
	# glowing eyes + jagged mouth
	var eye = Color("ffdf3a") if not is_boss else Color("ff3a5a")
	var ex = int(rr * 0.45)
	var ey = int(c - 1)
	var es = 2 if is_boss else 1
	_rect(img, int(c) - ex - es, ey, es + 1, es + 1, eye)
	_rect(img, int(c) + ex, ey, es + 1, es + 1, eye)
	_px(img, int(c) - ex - es - 1, ey - 1, Color("1a0a1a")); _px(img, int(c) + ex + es + 1, ey - 1, Color("1a0a1a"))
	for x in range(int(c - rr * 0.45), int(c + rr * 0.45) + 1):
		_px(img, x, int(c + rr * 0.35) + (x % 2), Color("1a0a1a"))
	_outline(img, Color("140814"))
	cache[key] = _tex(img)
	return cache[key]

# ------------------------------------------------------------------ crops
func crop(i: int, stage: int) -> ImageTexture:
	## stage 0 seedling, 1 young, 2 grown, 3 ripe, 4 wilted
	var key = "c%d_%d" % [i, stage]
	if cache.has(key):
		return cache[key]
	var img = _img(16, 16)
	var cd = D.CROPS[i]
	var col: Color = cd["col"]
	var leaf = Color("4caf3e") if cd["s"] != 3 else Color("3a9a7a")
	if stage == 4:
		leaf = Color("6a5a3a")
	match stage:
		0:
			_px(img, 7, 13, leaf); _px(img, 8, 12, leaf); _px(img, 9, 13, leaf)
		1:
			_rect(img, 8, 9, 1, 5, leaf.darkened(0.2))
			_ell(img, 6, 9.5, 2.2, 1.3, leaf, false)
			_ell(img, 10.5, 8.5, 2.2, 1.3, leaf.lightened(0.1), false)
		2, 3, 4:
			_rect(img, 8, 5, 1, 9, leaf.darkened(0.2))
			_ell(img, 5.5, 9.5, 2.8, 1.5, leaf, true)
			_ell(img, 11, 8, 2.8, 1.5, leaf, true)
			_ell(img, 8.5, 4.5, 2, 2.4, leaf.lightened(0.1), true)
	if stage == 3:
		match cd["k"]:
			"pods":
				_ell(img, 5, 11, 1.4, 2.8, col, true); _ell(img, 11.5, 10, 1.4, 2.8, col, true)
			"round":
				_ell(img, 8.5, 12, 3.6, 3.2, col, true)
			"leafy":
				_ell(img, 8.5, 8, 5, 4, col, true); _ell(img, 8.5, 7, 2.5, 2, col.lightened(0.3), false)
			"big":
				_ell(img, 8.5, 11.5, 6, 4.2, col, true)
				_rect(img, 8, 7, 1, 2, Color("5a3a1a"))
				if cd["n"] == "Bubblemelon":
					for x in [5, 8, 11]:
						_rect(img, x, 9, 1, 5, col.darkened(0.25))
			"tall":
				_ell(img, 8.5, 6, 2.2, 4.5, col, true)
				_rect(img, 8, 1, 1, 2, leaf)
			"cluster":
				for p in [Vector2(6, 9), Vector2(10, 9), Vector2(8, 11), Vector2(5, 12), Vector2(11, 12), Vector2(8, 7)]:
					_ell(img, p.x, p.y, 1.6, 1.6, col, true)
	_outline(img, Color("1e2a14", 0.85))
	cache[key] = _tex(img)
	return cache[key]

# ------------------------------------------------------------------ people
const PERSON = [
	"....hhhhhh....",
	"...hhhhhhhh...",
	"..HHHHHHHHHH..",
	"....ssssss....",
	"....sEssEs....",
	"....ssssss....",
	".....smms.....",
	"...cccccccc...",
	"..sccccccccs..",
	"..sccccccccs..",
	"...pppppppp...",
	"...pppppppp...",
	"....pp..pp....",
	"....bb..bb....",
]

func person(hair: Color, shirt: Color, skin: Color, hat: bool) -> ImageTexture:
	var key = "p" + hair.to_html() + shirt.to_html() + str(hat)
	if cache.has(key):
		return cache[key]
	var hc = Color("e8c35a") if hat else hair
	var pal = {"h": hc, "H": hc.darkened(0.15) if hat else hair, "s": skin, "E": Color("2a1e2e"), "m": skin.darkened(0.25),
		"c": shirt, "p": Color("3a5aa8") if hat else shirt.darkened(0.35), "b": Color("4a2e1e")}
	var img = _map(PERSON, pal)
	if hat:
		_rect(img, 1, 2, 12, 1, Color("c89a3a"))
		_rect(img, 4, 7, 1, 3, Color("3a5aa8")); _rect(img, 9, 7, 1, 3, Color("3a5aa8"))
	_outline(img, Color("1a1420"))
	cache[key] = _tex(img)
	return cache[key]

func farmer() -> ImageTexture:
	return person(Color("6a3a1a"), Color("e86a5a"), Color("f2c9a0"), true)

func villager(i: int) -> ImageTexture:
	var v = D.VILLAGERS[i]
	return person(v["hair"], v["shirt"], v["skin"], false)

# ------------------------------------------------------------------ misc
func tree(season: int, variant: int) -> ImageTexture:
	var key = "t%d_%d" % [season, variant]
	if cache.has(key):
		return cache[key]
	var img = _img(24, 32)
	_rect(img, 10, 20, 4, 11, Color("6a4428"))
	var leaf = [Color("3f9a45"), Color("2f8a3a"), Color("d0702a"), Color("e8f0f4")][season]
	if variant == 1:
		for y in 20:
			var hw = int(y * 0.55) + 1
			_rect(img, 12 - hw, 2 + y, hw * 2, 1, leaf if y % 4 != 3 else leaf.darkened(0.15))
	else:
		_ell(img, 12, 11, 10, 9, leaf, true)
		_ell(img, 8, 8, 4, 3, leaf.lightened(0.15), false)
	if season == 0 and variant == 0:
		for p in [Vector2i(7, 12), Vector2i(15, 8), Vector2i(12, 15), Vector2i(17, 13)]:
			_px(img, p.x, p.y, Color("ff9ac8"))
	_outline(img, Color("1a2414"))
	cache[key] = _tex(img)
	return cache[key]

func icon_crop(i: int) -> ImageTexture:
	return crop(i, 3)
