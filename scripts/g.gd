extends Node
## Constantes, dados de balanceamento e funções de desenho cartunesco compartilhadas.

const TILE := 72.0
const PIECE_LIFE := 60.0           # cada peça afunda 60 s depois de anexada
const CRACK_AT := 45.0             # rachaduras aparecem aos 45 s
const UNSAFE_LEFT := PIECE_LIFE - CRACK_AT  # peça rachada (últimos 15 s): o Tobé não pisa nela
const WORLD_TIME := 80.0           # segundos por mundo no modo arcade

# Giro e movimento: tocar à esquerda/direita gira E leva a ilha para aquele lado.
# Toque curto gira um passo suave; segurar acelera (com limite) e, ao soltar,
# a ilha termina o giro devagar e ainda desliza um pouco antes de parar.
const SPIN_STEP := PI / 2.0        # a ilha sempre para alinhada de 90 em 90 graus (regra das cores)
const SPIN_MIN := 3.0              # rad/s no começo do toque
const SPIN_MAX := 5.0              # rad/s no máximo, segurando (limite: não vira um pião)
const SPIN_ACCEL := 14.0           # rad/s² — quão rápido o giro ganha ou perde velocidade
const HOLD_RAMP := 1.0             # segundos segurando até chegar na velocidade máxima
const MOVE_MIN := 90.0             # px/s logo que toca
const MOVE_MAX := 240.0            # px/s segurando
const MOVE_ACCEL := 520.0          # px/s² para ganhar velocidade
const MOVE_FRICTION := 2.2         # quanto maior, mais rápido a ilha para depois de soltar

# Elementos: Folha, Brasa, Gota, Raio
const ELEM := [Color("5cc85a"), Color("ff8f2e"), Color("3d8bff"), Color("ffd447")]
const ELEM_DARK := [Color("23722f"), Color("a64a07"), Color("1a4fa8"), Color("a57a06")]
const ELEM_NAMES := ["Folha", "Brasa", "Gota", "Raio"]
const GOLD := Color("ffe066")
const GOLD_DARK := Color("b8860b")

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
# Ilha inicial: cima verde, direita laranja, baixo azul, esquerda amarelo
const HOME_EDGE := [0, 1, 2, 3]

const SAND := Color("f6dca2")
const SAND_DARK := Color("c08f4c")
const GRASS := Color("8fd66a")
const GRASS_DARK := Color("4f9a37")

const WORLDS := [
	{"name": "Mar Calmo", "sea": Color("38c6d9"), "sea2": Color("1f8fb8"),
		"ipm": [12.0, 18.0], "speed": 95.0, "monster": 0.1, "item": 0.38,
		"monsters": ["gorila"], "current": false, "night": 0.0, "storm": false, "choice": false},
	{"name": "Correntes", "sea": Color("2fb5b0"), "sea2": Color("17788f"),
		"ipm": [16.0, 24.0], "speed": 110.0, "monster": 0.2, "item": 0.36,
		"monsters": ["gorila", "hiena"], "current": true, "night": 0.0, "storm": false, "choice": true},
	{"name": "Mar Noturno", "sea": Color("1d4f8c"), "sea2": Color("0d2550"),
		"ipm": [20.0, 28.0], "speed": 120.0, "monster": 0.26, "item": 0.34,
		"monsters": ["gorila", "hiena", "mapinguari"], "current": true, "night": 0.75, "storm": false, "choice": true},
	{"name": "Tempestade", "sea": Color("47607a"), "sea2": Color("1e2c3d"),
		"ipm": [26.0, 40.0], "speed": 135.0, "monster": 0.3, "item": 0.32,
		"monsters": ["gorila", "hiena", "mapinguari", "boitata"], "current": true, "night": 0.35, "storm": true, "choice": true},
]

const MONSTERS := {
	"gorila": {"size": 1.0, "speed": 1.5, "color": Color("8a5a9e"), "dark": Color("4a2a5c"), "score": 250},
	"hiena": {"size": 1.0, "speed": 2.5, "color": Color("d9a441"), "dark": Color("7a5512"), "score": 300},
	"mapinguari": {"size": 1.3, "speed": 0.95, "color": Color("7b5b3a"), "dark": Color("3d2a17"), "score": 350},
	"boitata": {"size": 1.0, "speed": 2.0, "color": Color("ff5a36"), "dark": Color("8f1d07"), "score": 400},
}

# Poderes do Tobé: cada um tem uma barrinha. Orbes de poder nas ilhas enchem a barra;
# cada encaixe certo também enche um pouco. Barra cheia: toque no ícone (ou tecla 1-4).
const POWERS := ["ima", "coracao", "soco", "conserto"]
const POWER_INFO := {
	"ima": {"name": "Magnetismo", "dur": 10.0, "color": Color("4da3ff"), "dark": Color("1a4fa8")},
	"coracao": {"name": "Vida", "dur": 0.0, "color": Color("ff5c8a"), "dark": Color("9e1030")},
	"soco": {"name": "Super soco", "dur": 8.0, "color": Color("ff8f2e"), "dark": Color("a64a07")},
	"conserto": {"name": "Conserto", "dur": 8.0, "color": Color("5cc85a"), "dark": Color("23722f")},
}
const POWER_PICKUP := 0.5          # um orbe enche meia barra
const POWER_PER_ATTACH := 0.04     # cada encaixe certo enche um pouquinho de todas
const MAX_HEARTS := 5

const ITEMS := ["tesouro", "comida", "vida", "ancora", "escudo"]
const ITEM_WEIGHTS := [45, 25, 15, 8, 7]

var textures := {}
var dot_tex: Texture2D
var font: Font


func _ready() -> void:
	_setup_input()
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			img.set_pixel(x, y, Color(1, 1, 1, clamp(15.0 - d, 0.0, 1.0)))
	dot_tex = ImageTexture.create_from_image(img)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Fredoka", "Fredoka One", "Baloo 2", "Nunito", "Ubuntu", "Noto Sans", "sans-serif"])
	sf.font_weight = 800
	font = sf
	for key in ["tobe", "gorila", "hiena", "mapinguari", "boitata", "tesouro", "comida", "vida", "ancora", "escudo",
			"peixe", "poder_ima", "poder_coracao", "poder_soco", "poder_conserto",
			"sombra_tubarao", "sombra_baleia", "sombra_peixe"]:
		var path := "res://assets/sprites/%s.png" % key
		if ResourceLoader.exists(path):
			textures[key] = load(path)


func tex(key: String) -> Texture2D:
	return textures.get(key, null)


func label_settings(size: int, color: Color, outline: Color, outline_size: int) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_color = outline
	ls.outline_size = outline_size
	ls.shadow_color = Color(0, 0, 0, 0.25)
	ls.shadow_offset = Vector2(0, 4)
	ls.shadow_size = 0
	return ls


func _setup_input() -> void:
	var map := {
		"rot_left": [KEY_LEFT, KEY_A, KEY_Q, KEY_Z], "rot_right": [KEY_RIGHT, KEY_D, KEY_E, KEY_X],
		"pause": [KEY_ESCAPE, KEY_P], "confirm": [KEY_SPACE, KEY_ENTER],
		"power_1": [KEY_1], "power_2": [KEY_2], "power_3": [KEY_3], "power_4": [KEY_4],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func dir_index(d: Vector2i) -> int:
	return DIRS.find(d)


## Índice do lado (0 cima, 1 direita, 2 baixo, 3 esquerda) mais perto da direção v.
func dir_from_vec(v: Vector2) -> int:
	if abs(v.x) >= abs(v.y):
		return 1 if v.x > 0.0 else 3
	return 2 if v.y > 0.0 else 0


## As 4 cores em ordem sorteada, uma por lado.
func random_edges() -> Array:
	var e := [0, 1, 2, 3]
	e.shuffle()
	return e


## Faixa colorida de um lado da peça (centro da peça, lado, meia largura).
func draw_edge_band(ci: CanvasItem, center: Vector2, d: Vector2i, h: float, col: int, gold := false) -> void:
	var th := 14.0
	var rect: Rect2
	match d:
		Vector2i(0, -1): rect = Rect2(center + Vector2(-h + 6, -h - 4), Vector2(h * 2 - 12, th))
		Vector2i(0, 1): rect = Rect2(center + Vector2(-h + 6, h - th + 4), Vector2(h * 2 - 12, th))
		Vector2i(-1, 0): rect = Rect2(center + Vector2(-h - 4, -h + 6), Vector2(th, h * 2 - 12))
		_: rect = Rect2(center + Vector2(h - th + 4, -h + 6), Vector2(th, h * 2 - 12))
	if gold:
		rounded_box(ci, rect, GOLD, GOLD_DARK, 3, 7)
		draw_symbol(ci, -1, rect.get_center(), 8, Color.WHITE, GOLD_DARK, 2)
	else:
		rounded_box(ci, rect, ELEM[col], ELEM_DARK[col], 3, 7)
		draw_symbol(ci, col, rect.get_center(), 8, Color.WHITE, ELEM_DARK[col], 2)


func pick_weighted(options: Array, weights: Array) -> Variant:
	var total := 0
	for w in weights:
		total += w
	var r := randi() % total
	for i in options.size():
		r -= weights[i]
		if r < 0:
			return options[i]
	return options[0]


# ---------- desenho cartunesco ----------

func rounded_box(ci: CanvasItem, rect: Rect2, fill: Color, border: Color, bw: float, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(bw))
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.draw(ci.get_canvas_item(), rect)


func outlined_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, width, true)


func outlined_circle(ci: CanvasItem, pos: Vector2, r: float, fill: Color, line: Color, width: float) -> void:
	ci.draw_circle(pos, r + width * 0.5, line)
	ci.draw_circle(pos, r - width * 0.5, fill)


func symbol_points(elem: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match elem:
		0: # folha
			for i in 13:
				var t := float(i) / 12.0
				pts.append(Vector2(sin(t * PI) * r * 0.55, -r + t * 2.0 * r))
			for i in range(11, 0, -1):
				var t := float(i) / 12.0
				pts.append(Vector2(-sin(t * PI) * r * 0.55, -r + t * 2.0 * r))
			var rot := PackedVector2Array()
			for p in pts:
				rot.append(p.rotated(0.6))
			return rot
		1: # chama
			pts = PackedVector2Array([Vector2(0, -r), Vector2(r * 0.35, -r * 0.35), Vector2(r * 0.6, r * 0.25),
				Vector2(r * 0.4, r * 0.8), Vector2(0, r), Vector2(-r * 0.4, r * 0.8), Vector2(-r * 0.6, r * 0.25),
				Vector2(-r * 0.25, -r * 0.1), Vector2(-r * 0.05, -r * 0.45)])
		2: # gota
			pts.append(Vector2(0, -r))
			for i in 15:
				var a := -0.35 * PI + float(i) / 14.0 * 1.7 * PI
				pts.append(Vector2(cos(a), sin(a)) * r * 0.62 + Vector2(0, r * 0.32))
		3: # raio
			pts = PackedVector2Array([Vector2(r * 0.25, -r), Vector2(-r * 0.55, r * 0.12), Vector2(-r * 0.05, r * 0.12),
				Vector2(-r * 0.3, r), Vector2(r * 0.6, -r * 0.2), Vector2(r * 0.08, -r * 0.2)])
		_: # estrela (dourada)
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


func draw_symbol(ci: CanvasItem, elem: int, pos: Vector2, r: float, fill: Color, line: Color, width := 3.0) -> void:
	var pts := symbol_points(elem, r)
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + pos)
	outlined_poly(ci, moved, fill, line, width)


func heart_points(pos: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := float(i) / 32.0 * TAU
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(pos + Vector2(x, y) * r / 16.0)
	return pts


## Itens desenhados à mão quando não há sprite.
func draw_item(ci: CanvasItem, kind: String, pos: Vector2, s: float) -> void:
	if POWER_INFO.has(kind):
		draw_power(ci, kind, pos, s * 1.1)
		return
	if kind == "peixe" and not tex("peixe"):
		draw_fish(ci, pos, s)
		return
	var t := tex(kind)
	if t:
		var sz := t.get_size()
		var k: float = s * 1.6 / max(sz.x, sz.y)
		ci.draw_texture_rect(t, Rect2(pos - sz * k * 0.5, sz * k), false)
		return
	match kind:
		"tesouro":
			rounded_box(ci, Rect2(pos + Vector2(-s * 0.7, -s * 0.35), Vector2(s * 1.4, s * 0.95)), Color("c97a32"), Color("6e3a10"), 4, 6)
			rounded_box(ci, Rect2(pos + Vector2(-s * 0.75, -s * 0.7), Vector2(s * 1.5, s * 0.45)), Color("e0953f"), Color("6e3a10"), 4, 8)
			ci.draw_rect(Rect2(pos + Vector2(-s * 0.12, -s * 0.45), Vector2(s * 0.24, s * 0.4)), Color("ffd447"))
			ci.draw_circle(pos + Vector2(0, -s * 0.85), s * 0.16, Color("fff3a8"))
		"comida":
			outlined_circle(ci, pos + Vector2(0, s * 0.1), s * 0.62, Color("ff6b5a"), Color("9e2414"), 4)
			ci.draw_circle(pos + Vector2(-s * 0.2, -s * 0.1), s * 0.16, Color(1, 1, 1, 0.6))
			outlined_poly(ci, PackedVector2Array([pos + Vector2(0, -s * 0.5), pos + Vector2(s * 0.45, -s * 0.85),
				pos + Vector2(s * 0.15, -s * 0.45)]), Color("6ccf4f"), Color("23722f"), 3)
		"vida":
			outlined_poly(ci, heart_points(pos, s * 0.75), Color("ff4d6d"), Color("9e1030"), 4)
			ci.draw_circle(pos + Vector2(-s * 0.3, -s * 0.25), s * 0.13, Color(1, 1, 1, 0.7))
		"ancora":
			ci.draw_line(pos + Vector2(0, -s * 0.6), pos + Vector2(0, s * 0.6), Color("2a3f5f"), 9, true)
			ci.draw_line(pos + Vector2(0, -s * 0.6), pos + Vector2(0, s * 0.6), Color("9fb7d6"), 5, true)
			ci.draw_arc(pos + Vector2(0, s * 0.15), s * 0.55, 0.15 * PI, 0.85 * PI, 16, Color("2a3f5f"), 9, true)
			ci.draw_arc(pos + Vector2(0, s * 0.15), s * 0.55, 0.15 * PI, 0.85 * PI, 16, Color("9fb7d6"), 5, true)
			outlined_circle(ci, pos + Vector2(0, -s * 0.7), s * 0.2, Color("9fb7d6"), Color("2a3f5f"), 3)
		"escudo":
			var pts := PackedVector2Array([pos + Vector2(-s * 0.6, -s * 0.6), pos + Vector2(s * 0.6, -s * 0.6),
				pos + Vector2(s * 0.55, s * 0.1), pos + Vector2(0, s * 0.75), pos + Vector2(-s * 0.55, s * 0.1)])
			outlined_poly(ci, pts, Color("7fd3ff"), Color("1a5f8f"), 4)
			draw_symbol(ci, -1, pos, s * 0.3, Color.WHITE, Color("1a5f8f"), 2)


## Peixe colorido (o que pula do cardume e restaura vida). Nariz para +x.
func draw_fish(ci: CanvasItem, pos: Vector2, s: float) -> void:
	var t := tex("peixe")
	if t:
		var sz := t.get_size()
		var k: float = s * 1.8 / max(sz.x, sz.y)
		ci.draw_texture_rect(t, Rect2(pos - sz * k * 0.5, sz * k), false)
		return
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(pos + Vector2(cos(a) * s * 0.7, sin(a) * s * 0.42))
	outlined_poly(ci, PackedVector2Array([pos + Vector2(-s * 0.5, 0), pos + Vector2(-s * 1.05, -s * 0.45),
		pos + Vector2(-s * 1.05, s * 0.45)]), Color("ff9e3d"), Color("a64a07"), 3)
	outlined_poly(ci, body, Color("ffb347"), Color("a64a07"), 3)
	ci.draw_arc(pos + Vector2(s * 0.05, 0), s * 0.3, -1.1, 1.1, 8, Color("e07b1f"), 3, true)
	ci.draw_circle(pos + Vector2(s * 0.38, -s * 0.08), s * 0.11, Color.WHITE)
	ci.draw_circle(pos + Vector2(s * 0.41, -s * 0.08), s * 0.06, Color("1d2b4a"))


func _rot_pts(pts: Array, pos: Vector2, ang: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(pos + Vector2(p).rotated(ang))
	return out


## Ícone de poder: medalha redonda com o desenho (ou o PNG poder_<id> se existir).
func draw_power(ci: CanvasItem, id: String, pos: Vector2, s: float, dim := false) -> void:
	var info: Dictionary = POWER_INFO[id]
	var col: Color = info["color"]
	var dark: Color = info["dark"]
	if dim:
		col = col.lerp(Color(0.55, 0.6, 0.68), 0.45)
		dark = dark.lerp(Color(0.25, 0.3, 0.38), 0.45)
	var t := tex("poder_" + id)
	outlined_circle(ci, pos, s, col, dark, max(3.0, s * 0.12))
	ci.draw_circle(pos + Vector2(-s * 0.35, -s * 0.38), s * 0.16, Color(1, 1, 1, 0.45))
	if t:
		var sz := t.get_size()
		var k: float = s * 1.5 / max(sz.x, sz.y)
		ci.draw_texture_rect(t, Rect2(pos - sz * k * 0.5, sz * k), false, Color(1, 1, 1, 0.55) if dim else Color.WHITE)
		return
	var ink := Color("1d2b4a") if not dim else Color(0.3, 0.33, 0.4)
	var a := s * 0.62
	match id:
		"ima":
			# ímã de ferradura (U vermelho com pontas prateadas)
			var red := Color("e8413a") if not dim else Color("b06a66")
			var c := pos + Vector2(0, a * 0.05)
			ci.draw_arc(c, a * 0.55, 0, PI, 18, ink, a * 0.5, true)
			ci.draw_arc(c, a * 0.55, 0, PI, 18, red, a * 0.32, true)
			for sx in [-1.0, 1.0]:
				var x: float = sx * a * 0.55
				ci.draw_line(c + Vector2(x, 0), c + Vector2(x, -a * 0.75), ink, a * 0.5)
				ci.draw_line(c + Vector2(x, 0), c + Vector2(x, -a * 0.35), red, a * 0.32)
				ci.draw_line(c + Vector2(x, -a * 0.38), c + Vector2(x, -a * 0.72), Color("e6eef7"), a * 0.32)
		"coracao":
			outlined_poly(ci, heart_points(pos + Vector2(0, a * 0.05), a * 0.85), Color("fff0f4"), ink, 3)
			ci.draw_rect(Rect2(pos + Vector2(-a * 0.09, -a * 0.38), Vector2(a * 0.18, a * 0.62)), col)
			ci.draw_rect(Rect2(pos + Vector2(-a * 0.31, -a * 0.16), Vector2(a * 0.62, a * 0.18)), col)
		"soco":
			# luva de boxe
			var glove := Color("e8413a") if not dim else Color("b06a66")
			rounded_box(ci, Rect2(pos + Vector2(-a * 0.5, -a * 0.62), Vector2(a * 1.05, a * 0.85)), glove, ink, 3, a * 0.38)
			outlined_circle(ci, pos + Vector2(-a * 0.5, -a * 0.05), a * 0.24, glove, ink, 3)
			rounded_box(ci, Rect2(pos + Vector2(-a * 0.36, a * 0.2), Vector2(a * 0.78, a * 0.42)), Color("fff3e0"), ink, 3, a * 0.12)
			ci.draw_circle(pos + Vector2(-a * 0.15, -a * 0.4), a * 0.12, Color(1, 1, 1, 0.6))
		"conserto":
			# martelo inclinado
			var ang := -PI / 4.0
			outlined_poly(ci, _rot_pts([Vector2(-a * 0.11, -a * 0.2), Vector2(a * 0.11, -a * 0.2), Vector2(a * 0.11, a * 0.85),
				Vector2(-a * 0.11, a * 0.85)], pos, ang), Color("c08f4c"), ink, 3)
			outlined_poly(ci, _rot_pts([Vector2(-a * 0.55, -a * 0.62), Vector2(a * 0.45, -a * 0.62), Vector2(a * 0.45, -a * 0.18),
				Vector2(-a * 0.55, -a * 0.18)], pos, ang), Color("b7c3d0"), ink, 3)


## Monstro: sprite se existir, senão um bicho redondo desenhado.
func draw_monster(ci: CanvasItem, kind: String, pos: Vector2, s: float, weak: int, t: float) -> void:
	var info: Dictionary = MONSTERS[kind]
	s *= info["size"]
	var tx := tex(kind)
	if tx == null and kind != "gorila":
		tx = tex("gorila")
	# anel do ponto fraco no chão
	ci.draw_arc(pos + Vector2(0, s * 0.55), s * 0.75, 0, TAU, 28, ELEM[weak], 5, true)
	var top := pos.y - s * 0.9
	if tx:
		var sz := tx.get_size()
		var k: float = s * 2.0 / max(sz.x, sz.y)
		var squash := 1.0 + sin(t * 9.0) * 0.05
		var size := Vector2(sz.x * k / squash, sz.y * k * squash)
		var mod := Color.WHITE
		if kind != "gorila" and tex(kind) == null:
			mod = info["color"].lightened(0.3)
		ci.draw_texture_rect(tx, Rect2(pos - Vector2(size.x * 0.5, size.y * 0.75), size), false, mod)
		top = pos.y - size.y * 0.75
	else:
		var body: Color = info["color"]
		var dark: Color = info["dark"]
		outlined_circle(ci, pos, s * 0.7, body, dark, 6)
		outlined_circle(ci, pos + Vector2(-s * 0.25, -s * 0.15), s * 0.2, Color.WHITE, dark, 3)
		outlined_circle(ci, pos + Vector2(s * 0.25, -s * 0.15), s * 0.2, Color.WHITE, dark, 3)
		ci.draw_circle(pos + Vector2(-s * 0.22, -s * 0.1), s * 0.09, dark)
		ci.draw_circle(pos + Vector2(s * 0.22, -s * 0.1), s * 0.09, dark)
	# ponto fraco acima da cabeça
	var bob := sin(t * 4.0) * 3.0
	outlined_circle(ci, Vector2(pos.x, top - 16 + bob), s * 0.36, Color.WHITE, ELEM_DARK[weak], 3)
	draw_symbol(ci, weak, Vector2(pos.x, top - 16 + bob), s * 0.26, ELEM[weak], ELEM_DARK[weak], 2.5)
