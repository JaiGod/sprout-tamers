extends Node2D
## Sprout Tamers - shared state and immediate-mode drawing helpers (Main.gd extends this).

var font: Font
var mode: String = "title"
var buttons: Array = []
var focus: int = -1
var t: float = 0.0
var W: float = 462.0
var H: float = 260.0
var shake: float = 0.0
var parts: Array = []
var floats: Array = []
var toasts: Array = []
var dialog: Array = []
var dialog_cb = null
var paused: bool = false
var trans: Dictionary = {}
var cursor: int = 8
var seed_sel: int = 0
var ppos: Vector2 = Vector2.ZERO
var wander: Dictionary = {}
var fest: Dictionary = {}
var fight
var town
var herd
var howto_page: int = 0
var last_mouse: Vector2 = Vector2(-99, -99)
var _js_cb = null
var _js_t: float = 0.0

const UI_BG = Color("20301e")
const UI_PANEL = Color("f4ead0")
const UI_EDGE = Color("6a4a2a")
const UI_INK = Color("3a2a1a")
const UI_ACC = Color("7fc95a")

func burst(p: Vector2, col: Color, n: int = 10, spd: float = 60.0, g: float = 140.0, sz: float = 2.0) -> void:
	for i in n:
		var a = randf() * TAU
		var s = randf_range(0.3, 1.0) * spd
		parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * s + Vector2(0, -spd * 0.4), "life": randf_range(0.35, 0.8), "max": 0.8, "col": col, "g": g, "sz": sz})

func float_text(p: Vector2, s: String, col: Color) -> void:
	floats.append({"p": p, "s": s, "col": col, "life": 1.1})

func toast(s: String, dur: float = 3.2) -> void:
	if s == "":
		return
	toasts.append({"s": s, "life": dur})
	while toasts.size() > 4:
		toasts.pop_front()

# ------------------------------------------------------------------ drawing helpers
func txt(p: Vector2, s: String, size: int = 10, col: Color = Color.WHITE, align: int = 0, outline: int = 0, ocol: Color = Color("1a1410")) -> void:
	var pos = p
	var w = -1.0
	var al = HORIZONTAL_ALIGNMENT_LEFT
	if align == 1:
		pos = Vector2(p.x - 600, p.y)
		w = 1200.0
		al = HORIZONTAL_ALIGNMENT_CENTER
	elif align == 2:
		pos = Vector2(p.x - 1200, p.y)
		w = 1200.0
		al = HORIZONTAL_ALIGNMENT_RIGHT
	if outline > 0:
		draw_string_outline(font, pos, s, al, w, size, outline, ocol)
	draw_string(font, pos, s, al, w, size, col)

func para(r: Rect2, s: String, size: int = 9, col: Color = UI_INK, lines: int = -1) -> void:
	draw_multiline_string(font, r.position + Vector2(0, size), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, size, lines, col)

func panel(r: Rect2, fill: Color = UI_PANEL, edge: Color = UI_EDGE) -> void:
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
	draw_rect(r, edge)
	draw_rect(r.grow(-2), fill)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), fill.lightened(0.25))

func btn(r: Rect2, label: String, id: String, en: bool = true, col: Color = UI_ACC, size: int = 9, nav: bool = true) -> void:
	var idx = buttons.size()
	buttons.append({"r": r, "id": id, "en": en, "nav": nav})
	var hov = r.has_point(last_mouse) and en
	var foc = focus == idx
	var c = col if en else Color("8a8578")
	if hov or foc:
		c = c.lightened(0.18)
	var off = Vector2(0, 1) if hov else Vector2.ZERO
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size), c.darkened(0.5))
	draw_rect(Rect2(r.position + off, r.size), c.darkened(0.35))
	draw_rect(Rect2(r.position + off + Vector2(1, 1), r.size - Vector2(2, 2)), c)
	draw_rect(Rect2(r.position + off + Vector2(2, 2), Vector2(r.size.x - 4, 1)), c.lightened(0.3))
	if foc:
		draw_rect(r.grow(2), Color("ffe27a"), false, 1.5)
	var ink = Color("1e2a14") if en else Color("4a463e")
	txt(Vector2(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2 + size * 0.38) + off, label, size, ink, 1)

func spr(tex: Texture2D, center: Vector2, sc: float, flip: bool = false, mod: Color = Color.WHITE) -> void:
	var sz = tex.get_size() * sc
	var r = Rect2(center - sz / 2, sz)
	if flip:
		draw_set_transform(center, 0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false, mod)
		draw_set_transform(_shake_off(), 0, Vector2.ONE)
	else:
		draw_texture_rect(tex, r, false, mod)

func spr_feet(tex: Texture2D, feet: Vector2, sc: float, flip: bool = false, mod: Color = Color.WHITE, squash: float = 0.0) -> void:
	## draws a sprite standing on `feet`, with a soft shadow and optional squash/stretch
	var sz = tex.get_size() * sc
	draw_set_transform(Vector2.ZERO + _shake_off(), 0, Vector2.ONE)
	_ellipse(feet + Vector2(0, -1), sz.x * 0.36, sz.x * 0.11, Color(0, 0, 0, 0.22))
	var s = Vector2((-1.0 if flip else 1.0) * (1.0 + squash), 1.0 - squash)
	draw_set_transform(feet + _shake_off(), 0, s)
	draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2, -sz.y), sz), false, mod)
	draw_set_transform(_shake_off(), 0, Vector2.ONE)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for i in 16:
		var a = i * TAU / 16
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.5, 0), s * 0.55, col)
	draw_circle(c + Vector2(s * 0.5, 0), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.04, s * 0.18), c + Vector2(s * 1.04, s * 0.18), c + Vector2(0, s * 1.3)]), col)

func bar(r: Rect2, frac: float, col: Color, back: Color = Color("2a2018")) -> void:
	draw_rect(r, back)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(maxf(0, (r.size.x - 2) * clampf(frac, 0, 1)), r.size.y - 2)), col)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(maxf(0, (r.size.x - 2) * clampf(frac, 0, 1)), 1)), col.lightened(0.35))

func coin(c: Vector2, r: float = 3.5) -> void:
	draw_circle(c, r, Color("b8862a"))
	draw_circle(c + Vector2(-0.4, -0.4), r - 1, Color("ffd34a"))

func _shake_off() -> Vector2:
	if shake <= 0:
		return Vector2.ZERO
	return Vector2(sin(t * 91.0), cos(t * 77.0)) * shake

func landscape() -> bool:
	return W >= H

func narrow() -> bool:
	return W < 330

func hud_h() -> float:
	return 34.0 if narrow() else 22.0

func note_icon(c: Vector2, col: Color) -> void:
	draw_circle(c + Vector2(-2, 3), 2.2, col)
	draw_rect(Rect2(c.x - 0.2, c.y - 5, 1.4, 8), col)
	draw_rect(Rect2(c.x - 0.2, c.y - 5, 4, 1.6), col)

# ------------------------------------------------------------------ backgrounds
func grass(r: Rect2, season: int) -> void:
	var base = D.SEASON_TINT[season]
	if season == 3:
		base = Color("dfe9f2")
	draw_rect(r, base.darkened(0.18))
	var s = 16
	for y in range(int(r.position.y), int(r.end.y), s):
		for x in range(int(r.position.x), int(r.end.x), s):
			var h = (x * 73 + y * 151) % 7
			if h < 2:
				draw_rect(Rect2(x, y, s, s), base.darkened(0.12))
			if h == 3:
				draw_rect(Rect2(x + 5, y + 7, 1, 3), base.darkened(0.32))
				draw_rect(Rect2(x + 7, y + 6, 1, 4), base.darkened(0.32))
			if h == 5 and season == 0:
				draw_rect(Rect2(x + 9, y + 4, 2, 2), Color("ff9ac8"))
			if h == 5 and season == 1:
				draw_rect(Rect2(x + 9, y + 4, 2, 2), Color("fff07a"))
			if h == 5 and season == 2:
				draw_rect(Rect2(x + 3, y + 10, 3, 2), Color("c8502a"))
			if h == 6 and season == 3:
				draw_rect(Rect2(x + 4, y + 3, 6, 2), Color.WHITE)

func _snow(a: float = 1.0) -> void:
	for i in 40:
		var x = fmod(i * 53.7 + sin(t + i) * 10 + t * 8, W)
		var y = fmod(i * 31.3 + t * (18 + i % 5 * 4), H)
		draw_rect(Rect2(x, y, 2, 2), Color(1, 1, 1, 0.8 * a))

func _petals(col: Color) -> void:
	for i in 18:
		var x = fmod(i * 71.3 + t * 14 + sin(t * 0.7 + i) * 18, W)
		var y = fmod(i * 47.9 + t * (10 + i % 4 * 3), H)
		draw_rect(Rect2(x, y, 2, 1.5), col)

