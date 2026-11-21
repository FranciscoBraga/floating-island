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
const POWER_PER_ATTACH := 0.04     # ilha dourada: enche um pouquinho de todas
# Cada cor enche o poder dela: Folha → Conserto, Brasa → Super soco, Gota → Vida, Raio → Magnetismo.
const ELEM_POWER := ["conserto", "soco", "coracao", "ima"]
const POWER_PER_COLOR := 0.12      # encaixe certo enche a barra do poder da cor encaixada
const ORB_CHANCE := 0.3            # chance extra de uma ilha vazia trazer orbe de poder

# Poder especial (5º espaço): um por vez; pegar outro troca o atual.
const SPECIAL_INFO := {
	"giro": {"name": "Redemoinho", "dur": 8.0, "color": Color("b06bff"), "dark": Color("5a2a9e"),
		"tip": "Toque nas ilhas que chegam para girá-las"},
	"bolha": {"name": "Bolha do siri", "dur": 15.0, "color": Color("7fe0ff"), "dark": Color("2a8fb0"),
		"tip": "Bloqueia 1 caranguejo"},
	"cocos": {"name": "Chuva de cocos", "dur": 6.0, "color": Color("a8743c"), "dark": Color("5a3510"),
		"tip": "O Tobé atira cocos nos inimigos"},
	"estrela": {"name": "Estrela-do-mar", "dur": 15.0, "color": Color("ff9f6b"), "dark": Color("b5502a"),
		"tip": "Tobé invencível e as peças duram o dobro"},
}
const SPECIAL_ITEM_CHANCE := 0.06  # entre os itens: orbe do poder especial
const SPECIAL_COMBO := 8           # combo que dá o poder especial de presente

# Raridades
const MONO_CHANCE := 1.0 / 30.0    # ilha de uma cor só (4 lados iguais)
const MONO_LIFE := 180.0           # ...e dura 3 vezes mais
const RARE_FISH_CHANCE := 1.0 / 8.0  # peixe arco-íris: enche um poder sorteado
const MAX_HEARTS := 5

# Pacote 2: bichos de fora que usam a regra da cor
const CRAB_FROM_WORLD := 1         # onda de caranguejos estreia no mundo 2 (Correntes)
const CRAB_FIRST := 12.0           # segundos depois de começar o mundo 2
const CRAB_EVERY := [24.0, 34.0]   # intervalo entre ondas
const CRAB_WARN := 2.0             # aviso (bolhinhas na borda) antes de chegarem
const CRAB_DRAIN := 15.0           # caranguejo grudado: a peça perde 15 s de vida
const CRAB_STUCK := 5.0            # quanto tempo ele fica grudado antes de cair
const CRAB_POINTS := 50
const SIRI_FIRST := 35.0           # o siri presenteador aparece já no mundo 1
const SIRI_EVERY := [40.0, 55.0]
const SIRI_SPEED := 42.0

# Pacote 3: missões
const STAR_EVERY := [150.0, 210.0]  # uma estrela-do-mar chega numa ilha a cada ~3 min
const STAR_BONUS := 0.25            # ao ligar a estrela: +1/4 em todas as barras
const WHALE_FROM_WORLD := 1         # missão da baleia a partir do mundo 2
const WHALE_FIRST := 30.0           # segundos depois de começar o mundo 2
const WHALE_EVERY := [60.0, 80.0]
const WHALE_TIME := 30.0            # quanto tempo ela fica na superfície
const WHALE_SPOT_POINTS := 100
const CHALLENGE_FIRST := 10.0       # primeiro desafio do Tobé
const CHALLENGE_GAP := 8.0          # pausa entre um desafio e outro
const CHALLENGE_TIME := 75.0        # desafio não cumprido é trocado depois disso
## Desafios do Tobé (1 por vez). "world" = a partir de que mundo (0 = Mar Calmo). prize "cor" = poder da cor sorteada.
const CHALLENGES := [
	{"id": "peixes", "text": "Coma %d peixes", "goal": 5, "prize": "coracao", "world": 0},
	{"id": "combo", "text": "Faça combo de %d", "goal": 6, "prize": "giro", "world": 0},
	{"id": "cor", "text": "Encaixe %d peças %s", "goal": 5, "prize": "cor", "world": 0},
	{"id": "monstros", "text": "Jogue %d monstros ao mar", "goal": 3, "prize": "cocos", "world": 1},
	{"id": "caranguejos", "text": "Defenda %d caranguejos", "goal": 5, "prize": "bolha", "world": 1},
	{"id": "tamanho", "text": "Chegue a %d peças", "goal": 12, "prize": "estrela", "world": 2},
	{"id": "tubaroes", "text": "Desvie de %d onda de tubarões", "goal": 1, "prize": "bolha", "world": 3},
]

# Pacote 4: ataques de fora e coleção
const PALM_FROM_WORLD := 2          # coqueiro atirador a partir do mundo 3 (Mar Noturno)
const PALM_FIRST := 15.0
const PALM_EVERY := [40.0, 55.0]
const PALM_SHOT := 3.0              # um coco a cada 3 s
const PALM_WARN := 1.0              # sombra no chão 1 s antes do coco cair
const PALM_RANGE := 7.0             # (em peças, além do raio da ilha) distância em que ele atira
const COCO_EVERY := 0.45            # Chuva de cocos: intervalo entre os cocos do Tobé
const SHARK_FROM_WORLD := 3         # onda de tubarões a partir do mundo 4 (Tempestade)
const SHARK_FIRST := 12.0
const SHARK_EVERY := [22.0, 30.0]
const SHARK_WARN := 2.0
const SHARK_SPEED := 300.0
const SHARK_DODGE_POINTS := 200
const SEAHORSE_CHANCE := 1.0 / 15.0  # cavalo-marinho entre os peixes
const SHELL_CHANCE := 1.0 / 20.0     # concha numa ilha que chega
const SHELL_POINTS := 50
const SHELLS := ["concha_vieira", "concha_caramujo", "concha_buzio", "concha_mexilhao", "concha_bolacha"]
## Álbum: cada página completa libera um visual do Tobé.
const ALBUM := [
	{"name": "Conchas", "items": SHELLS, "outfit": "coroa"},
	{"name": "Raros do mar", "items": ["peixe_raro", "cavalo_marinho", "esp_estrela"], "outfit": "boia"},
	{"name": "Amigos do mar", "items": ["amigo_siri", "amigo_baleia", "amigo_coqueiro"], "outfit": "pirata"},
]
const ALBUM_NAMES := {
	"concha_vieira": "Vieira", "concha_caramujo": "Caramujo", "concha_buzio": "Búzio",
	"concha_mexilhao": "Mexilhão", "concha_bolacha": "Bolacha-do-mar",
	"peixe_raro": "Peixe arco-íris", "cavalo_marinho": "Cavalo-marinho", "esp_estrela": "Estrela-do-mar",
	"amigo_siri": "Presente do siri", "amigo_baleia": "Baleia limpinha", "amigo_coqueiro": "Coqueiro amigo",
}
const OUTFITS := {"coroa": "Coroa de conchas", "boia": "Boia", "pirata": "Chapéu de pirata"}
const ELEM_PLURAL := ["verdes", "laranja", "azuis", "amarelas"]

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
		"power_1": [KEY_1], "power_2": [KEY_2], "power_3": [KEY_3], "power_4": [KEY_4], "power_5": [KEY_5],
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
	if kind.begins_with("esp_"):
		draw_power(ci, kind.substr(4), pos, s * 1.1)
		return
	if kind == "peixe_raro":
		draw_fish(ci, pos, s, true)
		return
	if kind == "cavalo_marinho":
		draw_seahorse(ci, pos, s)
		return
	if kind.begins_with("concha_"):
		draw_shell(ci, kind, pos, s)
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
func draw_fish(ci: CanvasItem, pos: Vector2, s: float, rare := false) -> void:
	if rare:
		_draw_rainbow_fish(ci, pos, s)
		return
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


## Peixe arco-íris (raro): corpo com faixas das 4 cores e brilho.
func _draw_rainbow_fish(ci: CanvasItem, pos: Vector2, s: float) -> void:
	var t := tex("peixe_raro")
	if t:
		var sz := t.get_size()
		var k: float = s * 1.8 / max(sz.x, sz.y)
		ci.draw_texture_rect(t, Rect2(pos - sz * k * 0.5, sz * k), false)
		return
	var ink := Color("4a1f6e")
	ci.draw_circle(pos, s * 1.05, Color(1, 1, 1, 0.25))
	outlined_poly(ci, PackedVector2Array([pos + Vector2(-s * 0.5, 0), pos + Vector2(-s * 1.05, -s * 0.5),
		pos + Vector2(-s * 1.05, s * 0.5)]), Color("ff6bd6"), ink, 3)
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(pos + Vector2(cos(a) * s * 0.7, sin(a) * s * 0.42))
	outlined_poly(ci, body, Color("ffffff"), ink, 3)
	for i in 4:
		var x := pos.x + s * (-0.45 + i * 0.22)
		ci.draw_line(Vector2(x, pos.y - s * 0.3), Vector2(x, pos.y + s * 0.3), ELEM[i], s * 0.18)
	ci.draw_polyline(body, ink, 3, true)
	ci.draw_circle(pos + Vector2(s * 0.42, -s * 0.08), s * 0.11, Color.WHITE)
	ci.draw_circle(pos + Vector2(s * 0.45, -s * 0.08), s * 0.06, Color("1d2b4a"))


## Dados de um poder normal ou especial.
func power_info(id: String) -> Dictionary:
	return POWER_INFO[id] if POWER_INFO.has(id) else SPECIAL_INFO[id]


func _rot_pts(pts: Array, pos: Vector2, ang: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(pos + Vector2(p).rotated(ang))
	return out


## Ícone de poder: medalha redonda com o desenho (ou o PNG poder_<id> se existir).
func draw_power(ci: CanvasItem, id: String, pos: Vector2, s: float, dim := false) -> void:
	var info: Dictionary = power_info(id)
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
		"giro":
			# redemoinho: duas setas curvas girando
			var wc := Color.WHITE if not dim else Color(0.8, 0.82, 0.88)
			for k in 2:
				var a0 := PI * k
				ci.draw_arc(pos, a * 0.62, a0 + 0.3, a0 + 2.5, 14, ink, a * 0.34, true)
				ci.draw_arc(pos, a * 0.62, a0 + 0.3, a0 + 2.5, 14, wc, a * 0.18, true)
				var tip := pos + Vector2.from_angle(a0 + 2.5) * a * 0.62
				var fwd := Vector2.from_angle(a0 + 2.5 + PI / 2)
				var side := Vector2.from_angle(a0 + 2.5)
				outlined_poly(ci, PackedVector2Array([tip + fwd * a * 0.38, tip + side * a * 0.3, tip - side * a * 0.3]), wc, ink, 2)
		"bolha":
			# bolha de sabão com brilho e um siri pequenininho dentro
			ci.draw_circle(pos, a * 0.85, Color(1, 1, 1, 0.25 if not dim else 0.15))
			ci.draw_arc(pos, a * 0.85, 0, TAU, 24, Color.WHITE if not dim else Color(0.8, 0.82, 0.88), a * 0.14, true)
			ci.draw_arc(pos, a * 0.6, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.9), a * 0.12, true)
			draw_crab(ci, pos + Vector2(0, a * 0.12), a * 0.38, -1, 0.0, true)
		"cocos":
			# dois cocos com uma folhinha
			for k in 2:
				var cp := pos + Vector2((k - 0.5) * a * 0.75, a * 0.18 - k * a * 0.1)
				draw_coconut(ci, cp, a * 0.42, dim)
			var leaf := Color("4fae3a") if not dim else Color(0.5, 0.6, 0.5)
			outlined_poly(ci, PackedVector2Array([pos + Vector2(-a * 0.1, -a * 0.25), pos + Vector2(a * 0.35, -a * 0.85),
				pos + Vector2(a * 0.55, -a * 0.55)]), leaf, ink, 2)
		"estrela":
			# estrela-do-mar de 5 braços com bolinhas
			var sp := PackedVector2Array()
			for i in 10:
				var ang := -PI / 2 + TAU * i / 10.0
				sp.append(pos + Vector2.from_angle(ang) * (a * 0.95 if i % 2 == 0 else a * 0.42))
			outlined_poly(ci, sp, Color("ffb36b") if not dim else Color("c8a68a"), ink, 3)
			for i in 5:
				ci.draw_circle(pos + Vector2.from_angle(-PI / 2 + TAU * i / 5.0) * a * 0.5, a * 0.07, Color(1, 1, 1, 0.7))
			ci.draw_circle(pos, a * 0.1, Color(1, 1, 1, 0.7))
		"conserto":
			# martelo inclinado
			var ang := -PI / 4.0
			outlined_poly(ci, _rot_pts([Vector2(-a * 0.11, -a * 0.2), Vector2(a * 0.11, -a * 0.2), Vector2(a * 0.11, a * 0.85),
				Vector2(-a * 0.11, a * 0.85)], pos, ang), Color("c08f4c"), ink, 3)
			outlined_poly(ci, _rot_pts([Vector2(-a * 0.55, -a * 0.62), Vector2(a * 0.45, -a * 0.62), Vector2(a * 0.45, -a * 0.18),
				Vector2(-a * 0.55, -a * 0.18)], pos, ang), Color("b7c3d0"), ink, 3)


## Caranguejo visto de cima (frente para -y). elem = -1 desenha o siri vermelho.
func draw_crab(ci: CanvasItem, pos: Vector2, s: float, elem: int, t: float, grab := false) -> void:
	var col: Color = Color("e8413a") if elem < 0 else ELEM[elem]
	var dark: Color = Color("8a1c16") if elem < 0 else ELEM_DARK[elem]
	var tx := tex("siri" if elem < 0 else "caranguejo")
	if tx:
		var sz := tx.get_size()
		var k: float = s * 2.4 / max(sz.x, sz.y)
		ci.draw_texture_rect(tx, Rect2(pos - sz * k * 0.5, sz * k), false, Color.WHITE if elem < 0 else col.lightened(0.2))
		return
	# perninhas (3 de cada lado) mexendo
	for sx in [-1.0, 1.0]:
		for i in 3:
			var a: float = sin(t * 14.0 + i * 2.0 + sx) * 0.25
			var base: Vector2 = pos + Vector2(sx * s * 0.55, (i - 1) * s * 0.32 + s * 0.1)
			var knee: Vector2 = base + Vector2(sx * s * 0.42, -s * 0.1).rotated(a * sx)
			var foot: Vector2 = knee + Vector2(sx * s * 0.2, s * 0.32).rotated(a * sx)
			ci.draw_polyline(PackedVector2Array([base, knee, foot]), dark, s * 0.14, true)
	# garras (abrem e fecham; mais fechadas quando grudado)
	for sx in [-1.0, 1.0]:
		var open: float = (0.15 if grab else 0.35 + sin(t * 6.0 + sx) * 0.2)
		var arm: Vector2 = pos + Vector2(sx * s * 0.45, -s * 0.35)
		var hand: Vector2 = pos + Vector2(sx * s * 0.75, -s * 0.95)
		ci.draw_line(arm, hand, dark, s * 0.2)
		outlined_circle(ci, hand, s * 0.3, col, dark, max(2.0, s * 0.1))
		var cut: Vector2 = hand + Vector2(0, -s * 0.34)
		ci.draw_colored_polygon(PackedVector2Array([hand + Vector2(0, -s * 0.02), cut + Vector2(-s * open * 0.6, 0),
			cut + Vector2(s * open * 0.6, 0)]), dark)
	# casco
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(pos + Vector2(cos(a) * s * 0.72, sin(a) * s * 0.52))
	outlined_poly(ci, body, col, dark, max(2.5, s * 0.12))
	ci.draw_circle(pos + Vector2(-s * 0.25, -s * 0.15), s * 0.14, Color(1, 1, 1, 0.4))
	# olhinhos na frente
	for sx in [-1.0, 1.0]:
		var e: Vector2 = pos + Vector2(sx * s * 0.24, -s * 0.55)
		ci.draw_line(pos + Vector2(sx * s * 0.2, -s * 0.35), e, dark, s * 0.1)
		outlined_circle(ci, e, s * 0.15, Color.WHITE, dark, 2)
		ci.draw_circle(e + Vector2(0, -s * 0.03), s * 0.07, Color("1d2b4a"))
	if elem >= 0:
		draw_symbol(ci, elem, pos + Vector2(0, s * 0.08), s * 0.24, col.lightened(0.45), dark, 2)


func draw_coconut(ci: CanvasItem, pos: Vector2, r: float, dim := false) -> void:
	outlined_circle(ci, pos, r, Color("8a5a2b") if not dim else Color(0.55, 0.5, 0.45), Color("3d220a"), max(2.0, r * 0.18))
	ci.draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.3))
	for i in 3:
		ci.draw_circle(pos + Vector2.from_angle(-PI / 2 + i * TAU / 3) * r * 0.32 + Vector2(r * 0.15, 0), r * 0.1, Color("3d220a"))


## Coqueiro numa ilha (de cara brava quando é inimigo).
func draw_palm(ci: CanvasItem, pos: Vector2, s: float, t: float, angry := true) -> void:
	var ink := Color("3d220a")
	var sway := sin(t * 2.0) * 0.08
	var top := pos + Vector2(s * 0.25, -s * 1.5).rotated(sway)
	# tronco curvo com anéis
	var trunk := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		trunk.append(pos.lerp(top, u) + Vector2(sin(u * PI) * -s * 0.25, 0))
	ci.draw_polyline(trunk, ink, s * 0.36, true)
	ci.draw_polyline(trunk, Color("b27b42"), s * 0.24, true)
	for i in range(1, 8):
		var p: Vector2 = trunk[i]
		ci.draw_line(p + Vector2(-s * 0.1, 0), p + Vector2(s * 0.1, 0), Color("7a4c20"), 2)
	# folhas
	for i in 6:
		var ang := -PI / 2 + (i - 2.5) * 0.55 + sway * 2.0
		var tip := top + Vector2.from_angle(ang) * s * 1.0 + Vector2(0, s * 0.3 * abs(cos(ang)))
		var side := Vector2.from_angle(ang + PI / 2) * s * 0.16
		outlined_poly(ci, PackedVector2Array([top, top.lerp(tip, 0.5) + side, tip, top.lerp(tip, 0.5) - side]), Color("4fae3a"), Color("23722f"), 2)
	# cocos com cara
	for k in 2:
		draw_coconut(ci, top + Vector2((k - 0.5) * s * 0.42, s * 0.18), s * 0.2)
	if angry:
		var face := top + Vector2(0, s * 0.55)
		outlined_circle(ci, face, s * 0.3, Color("c8955a"), ink, 3)
		for sx in [-1.0, 1.0]:
			ci.draw_line(face + Vector2(sx * s * 0.2, -s * 0.14), face + Vector2(sx * s * 0.05, -s * 0.06), ink, 3)
			ci.draw_circle(face + Vector2(sx * s * 0.11, 0), s * 0.05, ink)
		ci.draw_arc(face + Vector2(0, s * 0.2), s * 0.1, PI + 0.4, TAU - 0.4, 8, ink, 3)


func draw_seahorse(ci: CanvasItem, pos: Vector2, s: float) -> void:
	var tx := tex("cavalo_marinho")
	if tx:
		var sz := tx.get_size()
		var k: float = s * 1.8 / max(sz.x, sz.y)
		ci.draw_texture_rect(tx, Rect2(pos - sz * k * 0.5, sz * k), false)
		return
	var col := Color("ffb347")
	var dark := Color("a65a07")
	# cauda enrolada
	ci.draw_arc(pos + Vector2(s * 0.05, s * 0.6), s * 0.22, -PI * 0.2, PI * 1.4, 14, dark, s * 0.24, true)
	ci.draw_arc(pos + Vector2(s * 0.05, s * 0.6), s * 0.22, -PI * 0.2, PI * 1.4, 14, col, s * 0.13, true)
	# corpo e cabeça
	var body := PackedVector2Array([pos + Vector2(-s * 0.05, -s * 0.55), pos + Vector2(s * 0.3, -s * 0.2), pos + Vector2(s * 0.3, s * 0.25),
		pos + Vector2(s * 0.1, s * 0.5), pos + Vector2(-s * 0.15, s * 0.25), pos + Vector2(-s * 0.2, -s * 0.2)])
	outlined_poly(ci, body, col, dark, 3)
	var head := pos + Vector2(0, -s * 0.62)
	outlined_circle(ci, head, s * 0.24, col, dark, 3)
	outlined_poly(ci, PackedVector2Array([head + Vector2(-s * 0.15, -s * 0.05), head + Vector2(-s * 0.55, s * 0.0),
		head + Vector2(-s * 0.55, s * 0.12), head + Vector2(-s * 0.15, s * 0.12)]), col, dark, 3)
	ci.draw_circle(head + Vector2(-s * 0.02, -s * 0.03), s * 0.06, Color("1d2b4a"))
	# nadadeira e crista
	outlined_poly(ci, PackedVector2Array([pos + Vector2(s * 0.28, -s * 0.15), pos + Vector2(s * 0.55, -s * 0.05), pos + Vector2(s * 0.3, s * 0.15)]), Color("ffe066"), dark, 2)
	for i in 4:
		ci.draw_line(pos + Vector2(s * 0.3, -s * 0.15 + i * s * 0.13), pos + Vector2(s * 0.38, -s * 0.13 + i * s * 0.13), dark, 2)


## Cinco conchas diferentes para o álbum.
func draw_shell(ci: CanvasItem, kind: String, pos: Vector2, s: float) -> void:
	var tx := tex(kind)
	if tx:
		var sz := tx.get_size()
		var k: float = s * 1.6 / max(sz.x, sz.y)
		ci.draw_texture_rect(tx, Rect2(pos - sz * k * 0.5, sz * k), false)
		return
	var ink := Color("6e3a10")
	match kind:
		"concha_vieira":
			# leque com gomos
			var pts := PackedVector2Array([pos + Vector2(0, s * 0.6)])
			for i in 13:
				var ang := PI + PI * i / 12.0
				var r := s * (0.8 + 0.06 * (1 if i % 2 == 0 else -1))
				pts.append(pos + Vector2(0, s * 0.3) + Vector2.from_angle(ang) * r)
			outlined_poly(ci, pts, Color("ff9e9e"), ink, 3)
			for i in 5:
				var ang := PI + PI * (i + 1) / 6.0
				ci.draw_line(pos + Vector2(0, s * 0.55), pos + Vector2(0, s * 0.3) + Vector2.from_angle(ang) * s * 0.72, Color("d45f5f"), 2)
			outlined_poly(ci, PackedVector2Array([pos + Vector2(-s * 0.25, s * 0.5), pos + Vector2(s * 0.25, s * 0.5),
				pos + Vector2(s * 0.12, s * 0.72), pos + Vector2(-s * 0.12, s * 0.72)]), Color("ff9e9e"), ink, 2)
		"concha_caramujo":
			# espiral
			outlined_circle(ci, pos, s * 0.7, Color("f6dca2"), ink, 3)
			var sp := PackedVector2Array()
			for i in 40:
				var u := i / 39.0
				sp.append(pos + Vector2.from_angle(u * TAU * 2.2) * s * 0.62 * (1.0 - u))
			ci.draw_polyline(sp, Color("b27b42"), 3, true)
		"concha_buzio":
			# cone pontudo
			outlined_poly(ci, PackedVector2Array([pos + Vector2(0, -s * 0.85), pos + Vector2(s * 0.5, s * 0.1), pos + Vector2(s * 0.3, s * 0.7),
				pos + Vector2(-s * 0.3, s * 0.7), pos + Vector2(-s * 0.5, s * 0.1)]), Color("e8d3ff"), Color("5a2a9e"), 3)
			for i in 3:
				var y := -s * 0.4 + i * s * 0.35
				ci.draw_line(pos + Vector2(-s * 0.3 - i * 0.05 * s, y), pos + Vector2(s * 0.3 + i * 0.05 * s, y + s * 0.12), Color("9b6bd6"), 2)
		"concha_mexilhao":
			# mexilhão azul escuro, oval inclinado
			var pts := PackedVector2Array()
			for i in 20:
				var ang := TAU * i / 20.0
				pts.append(pos + Vector2(cos(ang) * s * 0.4, sin(ang) * s * 0.78).rotated(0.5))
			outlined_poly(ci, pts, Color("3d5a8a"), Color("15243f"), 3)
			ci.draw_arc(pos, s * 0.45, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.5), 3, true)
		_:
			# bolacha-do-mar: disco com flor de 5 pétalas
			outlined_circle(ci, pos, s * 0.72, Color("f2e6c9"), Color("a08454"), 3)
			for i in 5:
				var ang := -PI / 2 + TAU * i / 5.0
				ci.draw_line(pos + Vector2.from_angle(ang) * s * 0.12, pos + Vector2.from_angle(ang) * s * 0.45, Color("a08454"), 4)
			ci.draw_circle(pos, s * 0.08, Color("a08454"))


## Barbatana de tubarão vista de cima (frente em +x). red = aviso.
func draw_fin(ci: CanvasItem, pos: Vector2, ang: float, s: float, red: bool, t: float) -> void:
	var f := Vector2.from_angle(ang)
	var side := f.orthogonal()
	# espuma atrás
	for i in 4:
		var k := float(i + 1)
		ci.draw_circle(pos - f * s * 0.45 * k + side * sin(t * 9.0 + k) * 3.0, s * (0.28 - k * 0.04), Color(1, 1, 1, 0.45 - k * 0.08))
	var col := Color("e8413a") if red else Color("5e7387")
	var dark := Color("7a1410") if red else Color("2a3846")
	outlined_poly(ci, PackedVector2Array([pos + f * s * 0.7, pos + side * s * 0.22 - f * s * 0.3, pos - f * s * 0.55, pos - side * s * 0.22 - f * s * 0.3]), col, dark, 3)
	ci.draw_line(pos + f * s * 0.6, pos - f * s * 0.45, Color(1, 1, 1, 0.5), 2)


## Visual do Tobé (álbum) desenhado em cima do retângulo da imagem dele.
func draw_outfit(ci: CanvasItem, id: String, r: Rect2) -> void:
	var w: float = abs(r.size.x)
	var h: float = abs(r.size.y)
	var x0: float = min(r.position.x, r.position.x + r.size.x)
	var y0: float = min(r.position.y, r.position.y + r.size.y)
	var ink := Color("1d2b4a")
	var hx := 0.55 if r.size.x >= 0.0 else 0.45  # o chapéu do Tobé fica um pouco para o lado
	match id:
		"pirata":
			var c := Vector2(x0 + w * hx, y0 + h * 0.2)
			var hat := PackedVector2Array([c + Vector2(-w * 0.66, h * 0.08), c + Vector2(-w * 0.36, -h * 0.15), c + Vector2(0, -h * 0.22),
				c + Vector2(w * 0.36, -h * 0.15), c + Vector2(w * 0.66, h * 0.08), c + Vector2(0, h * 0.01)])
			outlined_poly(ci, hat, Color("2b2b33"), Color("0d0d12"), 3)
			ci.draw_line(c + Vector2(-w * 0.5, h * 0.045), c + Vector2(w * 0.5, h * 0.045), Color("d8a630"), max(2.0, w * 0.05))
			# caveirinha
			ci.draw_circle(c + Vector2(0, -h * 0.08), w * 0.09, Color.WHITE)
			ci.draw_line(c + Vector2(-w * 0.1, -h * 0.01), c + Vector2(w * 0.1, -h * 0.01), Color.WHITE, max(2.0, w * 0.04))
		"coroa":
			var c := Vector2(x0 + w * hx, y0 + h * 0.03)
			var base := Rect2(c + Vector2(-w * 0.3, -h * 0.02), Vector2(w * 0.6, h * 0.08))
			rounded_box(ci, base, Color("ffd447"), Color("a57a06"), 3, 4)
			var kinds := ["concha_vieira", "concha_buzio", "concha_vieira"]
			for i in 3:
				draw_shell(ci, kinds[i], c + Vector2((i - 1) * w * 0.2, -h * 0.06 - (0.03 * h if i == 1 else 0.0)), w * 0.13)
		"boia":
			var c := Vector2(x0 + w * 0.5, y0 + h * 0.74)
			var rx := w * 0.56
			var ry := h * 0.12
			for i in 16:
				var a0 := TAU * i / 16.0
				var a1 := TAU * (i + 1) / 16.0
				var col := Color("ff5a4f") if i % 4 < 2 else Color.WHITE
				var p0 := c + Vector2(cos(a0) * rx, sin(a0) * ry)
				var p1 := c + Vector2(cos(a1) * rx, sin(a1) * ry)
				if sin((a0 + a1) * 0.5) > -0.2:  # só a metade da frente
					ci.draw_line(p0, p1, ink, h * 0.11 + 4)
					ci.draw_line(p0, p1, col, h * 0.11)


## Ícone de um espaço do álbum.
func draw_album_item(ci: CanvasItem, id: String, pos: Vector2, s: float) -> void:
	match id:
		"amigo_siri":
			draw_crab(ci, pos, s * 0.8, -1, 0.0, false)
		"amigo_baleia":
			var pts := PackedVector2Array()
			for i in 20:
				var ang := TAU * i / 20.0
				pts.append(pos + Vector2(cos(ang) * s * 0.9, sin(ang) * s * 0.42 * (1.0 - 0.4 * maxf(0.0, -cos(ang)))))
			outlined_poly(ci, pts, Color("4f7fb3"), Color("1f3d63"), 3)
			outlined_poly(ci, PackedVector2Array([pos + Vector2(-s * 0.8, 0), pos + Vector2(-s * 1.1, -s * 0.3), pos + Vector2(-s * 1.1, s * 0.3)]), Color("4f7fb3"), Color("1f3d63"), 3)
			ci.draw_circle(pos + Vector2(s * 0.55, -s * 0.1), s * 0.08, Color.WHITE)
		"amigo_coqueiro":
			draw_palm(ci, pos + Vector2(-s * 0.1, s * 0.8), s * 0.75, 0.0, false)
		_:
			draw_item(ci, id, pos, s)


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
