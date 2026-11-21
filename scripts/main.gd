extends Node2D
## Jogo principal: estados, spawner de ilhas, encaixes, Tobé automático,
## monstros, correntes, câmera, efeitos e fim de jogo.

const Island = preload("res://scripts/island.gd")
const Incoming = preload("res://scripts/incoming.gd")
const Actor = preload("res://scripts/actor.gd")
const Hud = preload("res://scripts/hud.gd")
const Sfx = preload("res://scripts/sfx.gd")
const SeaLife = preload("res://scripts/sealife.gd")
const FishJump = preload("res://scripts/fishjump.gd")
const Crab = preload("res://scripts/crab.gd")
const Whale = preload("res://scripts/whale.gd")
const Coco = preload("res://scripts/coco.gd")

var state := "menu"
var world: Node2D
var island: Node2D
var incoming_root: Node2D
var crab_root: Node2D      # caranguejos e siri (bichos de fora da ilha)
var fx_root: Node2D
var cam: Camera2D
var sea_mat: ShaderMaterial
var overlay_mat: ShaderMaterial
var hud: Control
var sfx: Node

var score := 0
var combo := 0
var best_combo := 0
var hearts := 3
var max_size := 1
var game_time := 0.0
var world_idx := 0
var world_t := 0.0
var spawn_acc := 0.0
var choice_t := 20.0
var current_t := 14.0
var current_dir := Vector2.ZERO
var current_left := 0.0
var current_warn := 0.0
var anchor_t := 0.0
var shake := 0.0
var flash := 0.0
var hurt_fx := 0.0
var lightning_t := 7.0
var night := 0.0
var rain := 0.0
var best_score := 0
var best_size := 0
var death_reason := ""
var menu_t := 0.0
var sea_life: Node2D
var power_charge := {}   # id -> 0..1 (barrinha)
var power_left := {}     # id -> segundos restantes do poder ligado
var special := ""        # poder especial guardado no 5º espaço ("" = vazio)
var special_left := 0.0  # segundos restantes do especial ligado
var special_gift := false  # o presente do combo já saiu nesta sequência
var repair_fx_t := 0.0
var crab_t := G.CRAB_FIRST  # contagem até a próxima onda de caranguejos (a partir do mundo 2)
var crab_warn := 0.0        # aviso antes da onda (bolhinhas na borda da tela)
var crab_side := 0          # de que lado da tela a onda vem (0 cima, 1 direita, 2 baixo, 3 esquerda)
var siri_t := G.SIRI_FIRST  # contagem até o próximo siri presenteador
var whale_root: Node2D
var whale = null            # baleia da missão (null = nenhuma)
var whale_t := G.WHALE_FIRST
var star_t := 180.0         # contagem até a próxima estrela-do-mar chegar numa ilha
var star_pending := false   # a próxima ilha comum traz a estrela
var challenge := {}         # desafio do Tobé: {"id", "text", "goal", "n", "elem", "prize", "t"}
var challenge_t := G.CHALLENGE_FIRST
var last_challenge := ""
var palm_t := G.PALM_FIRST   # contagem até o próximo coqueiro atirador (a partir do mundo 3)
var shark_t := G.SHARK_FIRST # contagem até a próxima onda de tubarões (mundo 4)
var shark_wave_on := false
var shark_bit := false       # algum tubarão desta onda arrancou peça
var coco_cd := 0.0           # Chuva de cocos: tempo até o próximo coco
var coco_targets: Array = [] # alvos que já têm um coco voando
var album := {}              # coleção: id -> quantas vezes pegou (fica salvo)
var outfit := ""             # visual do Tobé em uso (liberado no álbum)
var stats := {"poderes": 0, "peixes": 0, "pulos": 0}   # só para o robô de teste


func _ready() -> void:
	randomize()
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var sea := ColorRect.new()
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/sea.gdshader")
	sea.material = sea_mat
	bg.add_child(sea)

	world = Node2D.new()
	add_child(world)
	sea_life = SeaLife.new()
	world.add_child(sea_life)
	whale_root = Node2D.new()
	world.add_child(whale_root)
	incoming_root = Node2D.new()
	world.add_child(incoming_root)
	island = Island.new()
	world.add_child(island)
	crab_root = Node2D.new()
	world.add_child(crab_root)
	fx_root = Node2D.new()
	world.add_child(fx_root)
	cam = Camera2D.new()
	world.add_child(cam)
	cam.make_current()

	var over := CanvasLayer.new()
	over.layer = 5
	add_child(over)
	var ov := ColorRect.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = load("res://shaders/overlay.gdshader")
	ov.material = overlay_mat
	over.add_child(ov)

	sfx = Sfx.new()
	add_child(sfx)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

	for id in G.POWERS:
		power_charge[id] = 0.0
		power_left[id] = 0.0
	_load_save()
	island.reset()
	_apply_world(0, false)
	hud.show_menu()
	if OS.get_cmdline_user_args().has("autoplay"):
		autoplay = true
		start_game()
	if OS.get_cmdline_user_args().has("demo_monsters"):
		start_game()
		var e := 0
		for x in range(-2, 3):
			for y in range(-1, 2):
				if Vector2i(x, y) != Vector2i.ZERO:
					island.cells[Vector2i(x, y)] = {"elem": e % 4, "edges": G.random_edges(), "born": -50.0 if x == 2 else 0.0}
					e += 1
		island.recompute_pivot()
		var kinds := ["gorila", "hiena", "mapinguari", "boitata"]
		for i in 4:
			var m := Actor.new()
			m.kind = kinds[i]
			m.cpos = Vector2([-2, -1, 1, 2][i], 1 if i % 2 == 0 else -1)
			m.weak = i
			m.speed = 0.0
			island.monsters.append(m)
		island.items[Vector2i(-2, 0)] = "tesouro"
		island.items[Vector2i(-1, 0)] = "vida"
		island.items[Vector2i(1, 0)] = "ancora"
	if OS.get_cmdline_user_args().has("demo_powers"):
		start_game()
		for x in range(-1, 2):
			for y in range(-1, 2):
				if Vector2i(x, y) != Vector2i.ZERO:
					island.cells[Vector2i(x, y)] = {"elem": 0, "edges": G.random_edges(), "born": -40.0 if x == 1 else 0.0}
		island.recompute_pivot()
		island.items[Vector2i(-1, -1)] = "ima"
		island.items[Vector2i(-1, 1)] = "peixe"
		island.items[Vector2i(0, 1)] = "conserto"
		power_charge = {"ima": 1.0, "coracao": 1.0, "soco": 0.6, "conserto": 0.3}
		var g2 := Actor.new()
		g2.kind = "gorila"
		g2.cpos = Vector2(1, -1)
		g2.speed = 1.5
		g2.weak = 2
		island.monsters.append(g2)
		if OS.get_cmdline_user_args().has("soco"):
			power_charge = {"ima": 0.4, "coracao": 1.0, "soco": 1.0, "conserto": 1.0}
			activate_power("soco")
			activate_power("conserto")
		else:
			activate_power("ima")
			power_charge["ima"] = 0.0
	if OS.get_cmdline_user_args().has("test_sink"):
		# Tobé preso numa peça que vai afundar, com outra peça do lado: ele deve pular e o jogo continuar
		start_game()
		island.cells[Vector2i(1, 0)] = {"elem": 0, "edges": G.random_edges(), "born": 0.0}
		island.recompute_pivot()
		island.cells[Vector2i.ZERO]["born"] = -59.0
		island.tobe.stun = 5.0
		get_tree().create_timer(2.5).timeout.connect(func():
			print("[teste] estado=", state, " peças=", island.cells.size(), " tobe=", island.tobe.cell(), " pulos=", stats["pulos"])
			get_tree().quit())
	if OS.get_cmdline_user_args().has("demo_over"):
		start_game()
		score = 4200
		max_size = 12
		get_tree().create_timer(3.0).timeout.connect(func(): game_over("O Tobé foi pego!"))
	if OS.get_cmdline_user_args().has("test_pacote1"):
		# confere as regras do pacote 1 e imprime o resultado
		start_game()
		await get_tree().process_frame
		var ok := true
		# 1) Redemoinho: tocar na ilha que chega gira as cores 90° no sentido horário
		give_special("giro", island.position, "")
		activate_special()
		var inc := Incoming.new()
		inc.edges = [0, 1, 2, 3]
		inc.position = island.position + Vector2(300, 0)
		incoming_root.add_child(inc)
		var sp: Vector2 = get_viewport().get_canvas_transform() * inc.position
		var tapped := tap_incoming(sp)
		print("[teste] giro: tocou=", tapped, " cores=", inc.edges)
		ok = ok and tapped and inc.edges == [3, 0, 1, 2]
		inc.queue_free()
		# 2) cor encaixada enche só a barra do poder dela
		for id in G.POWERS:
			power_charge[id] = 0.0
		var a := Incoming.new()
		a.edges = [0, 0, 0, 0]
		a.mono = true
		incoming_root.add_child(a)
		_attach(a, Vector2i(0, -1), 0)
		print("[teste] cargas=", power_charge, " vida da peça rara=", island.life(Vector2i(0, -1)))
		ok = ok and power_charge["conserto"] > 0.2 and power_charge["soco"] == 0.0 and island.life(Vector2i(0, -1)) == G.MONO_LIFE
		# 3) peixe arco-íris enche um poder por completo
		island.items[Vector2i(0, -1)] = "peixe_raro"
		_collect(Vector2i(0, -1))
		var full := G.POWERS.filter(func(id): return power_charge[id] >= 1.0)
		print("[teste] cheios depois do peixe arco-íris=", full)
		ok = ok and full.size() == 1
		print("[teste] pacote 1: ", "OK" if ok else "FALHOU")
		get_tree().quit()
	if OS.get_cmdline_user_args().has("demo_novos"):
		# pacote 1: ilha rara chegando, peixe arco-íris na ilha, Redemoinho ligado e barras por cor
		start_game()
		island.add_cell(Vector2i(1, 0), 2, [2, 2, 2, 2], G.MONO_LIFE)
		island.items[Vector2i(1, 0)] = "peixe_raro"
		power_charge = {"ima": 0.36, "coracao": 1.0, "soco": 0.6, "conserto": 0.12}
		give_special("giro", island.position, "")
		activate_special()
		var W: Dictionary = G.WORLDS[0]
		for k in 3:
			_spawn_one(W, k, "", 0.6)
		var mono := Incoming.new()
		mono.mono = true
		mono.edges = [1, 1, 1, 1]
		mono.position = island.position + Vector2(-330, -150)
		mono.vel = Vector2(20, 8)
		incoming_root.add_child(mono)
		if OS.get_cmdline_user_args().has("shot"):
			get_tree().create_timer(2.2).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("user://novos.png")
				print("[demo] print salvo")
				get_tree().quit())
	if OS.get_cmdline_user_args().has("test_pacote2"):
		# confere as regras do pacote 2 e imprime o resultado
		start_game()
		await get_tree().process_frame
		var ok := true
		var pc := Vector2i(1, 0)
		island.add_cell(pc, 0, [0, 1, 2, 3])  # lado direito da peça nova = cor 1 (Brasa)
		var hit := _edge_hit(island.cell_to_world(Vector2(1.75, 0.1)), 0.8)
		print("[teste] batida na borda: ", hit)
		ok = ok and hit.get("cell") == pc and hit.get("dir") == Vector2i(1, 0)
		# 1) caranguejo da cor da borda é jogado longe e a peça não perde vida
		var before: float = island.remaining(pc)
		var a := Crab.new()
		a.elem = 1
		a.position = island.cell_to_world(Vector2(2, 0))
		crab_root.add_child(a)
		_crab_hit(a, pc, Vector2i(1, 0))
		print("[teste] cor certa: estado=", a.state, " vida=", island.remaining(pc), " (antes ", before, ")")
		ok = ok and a.state == "flung" and is_equal_approx(island.remaining(pc), before)
		# 2) cor errada gruda e tira 15 s
		var b := Crab.new()
		b.elem = 2
		b.position = island.cell_to_world(Vector2(2, 0))
		crab_root.add_child(b)
		_crab_hit(b, pc, Vector2i(1, 0))
		print("[teste] cor errada: estado=", b.state, " perdeu=", before - island.remaining(pc), " s")
		ok = ok and b.state == "stuck" and absf(before - island.remaining(pc) - G.CRAB_DRAIN) < 0.01
		# 3) siri com a cor da borda dá a Bolha; com outra cor só mergulha
		var s1 := Crab.new()
		s1.kind = "siri"
		s1.elem = island.edge_color(pc, Vector2i(0, -1))
		crab_root.add_child(s1)
		_siri_hit(s1, pc, Vector2i(0, -1))
		var s2 := Crab.new()
		s2.kind = "siri"
		s2.elem = (island.edge_color(pc, Vector2i(0, 1)) + 1) % 4
		crab_root.add_child(s2)
		var had: String = special
		_siri_hit(s2, pc, Vector2i(0, 1))
		print("[teste] siri: especial=", special, " estados=", s1.state, "/", s2.state)
		ok = ok and had == "bolha" and special == "bolha" and s1.state == "bye" and s2.state == "dive"
		# 4) Bolha ligada segura 1 caranguejo de cor errada e estoura
		activate_special()
		_update_powers(0.0)
		var on: bool = island.bubble
		var before2: float = island.remaining(pc)
		var c := Crab.new()
		c.elem = 3
		c.position = island.cell_to_world(Vector2(2, 0))
		crab_root.add_child(c)
		_crab_hit(c, pc, Vector2i(1, 0))
		print("[teste] bolha: ligada=", on, " caranguejo=", c.state, " bolha depois=", island.bubble, " vida igual=", is_equal_approx(island.remaining(pc), before2))
		ok = ok and on and c.state == "flung" and not island.bubble and special == "" and is_equal_approx(island.remaining(pc), before2)
		# 5) um caranguejo nadando de verdade chega na ilha e é resolvido
		var d := Crab.new()
		d.elem = 0
		d.speed = 160.0
		d.position = island.position + Vector2(0, -420)
		d.vel = Vector2(0, 160)
		crab_root.add_child(d)
		await get_tree().create_timer(4.0).timeout
		print("[teste] caranguejo nadando: estado=", d.state if is_instance_valid(d) else "sumiu")
		ok = ok and (not is_instance_valid(d) or d.state != "swim")
		print("[teste] pacote 2: ", "OK" if ok else "FALHOU")
		get_tree().quit()
	if OS.get_cmdline_user_args().has("demo_caranguejos"):
		# pacote 2: mundo 2, onda de caranguejos chegando, um grudado e o siri passando
		start_game()
		_apply_world(1, false)
		island.add_cell(Vector2i(1, 0), 1, [1, 1, 2, 0])
		island.add_cell(Vector2i(-1, 0), 2, [3, 2, 2, 0])
		island.add_cell(Vector2i(0, 1), 3, [2, 3, 3, 1])
		crab_t = 0.01
		var sr := Crab.new()
		sr.kind = "siri"
		sr.elem = 2
		sr.position = island.position + Vector2(-330, 170)
		sr.vel = Vector2(18, -6)
		crab_root.add_child(sr)
		var g := Crab.new()
		g.elem = 0
		crab_root.add_child(g)
		g.stick(Vector2i(1, 0), Vector2i(0, 1), 60.0)
		if OS.get_cmdline_user_args().has("shot"):
			get_tree().create_timer(5.6).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("user://caranguejos.png")
				give_special("bolha", island.position, "")
				activate_special()
				await get_tree().create_timer(0.8).timeout
				get_viewport().get_texture().get_image().save_png("user://bolha.png")
				print("[demo] prints salvos")
				get_tree().quit())
	if OS.get_cmdline_user_args().has("test_pacote3"):
		# confere as regras do pacote 3 e imprime o resultado
		start_game()
		await get_tree().process_frame
		var ok := true
		# 1) desafio "coma 5 peixes" dá o poder Vida cheio
		for id in G.POWERS:
			power_charge[id] = 0.0
		challenge = {"id": "peixes", "text": "Coma %d peixes", "goal": 5, "n": 0, "elem": 0, "prize": "coracao", "t": 0.0}
		for i in 5:
			island.items[Vector2i.ZERO] = "peixe"
			_collect(Vector2i.ZERO)
		print("[teste] desafio peixes: vida=", power_charge["coracao"], " desafio=", challenge)
		ok = ok and power_charge["coracao"] >= 1.0 and challenge.is_empty()
		# 2) desafio de cor: só conta a cor sorteada
		challenge = {"id": "cor", "text": "Encaixe %d peças %s", "goal": 2, "n": 0, "elem": 0, "prize": "cor", "t": 0.0}
		challenge_event("cor", 1, 3)
		challenge_event("cor", 1, 0)
		var half: int = challenge.get("n", -1)
		challenge_event("cor", 1, 0)
		print("[teste] desafio cor: depois de 1 certa=", half, " conserto=", power_charge["conserto"])
		ok = ok and half == 1 and power_charge["conserto"] >= 1.0 and challenge.is_empty()
		# 3) baleia: cor errada não limpa; as 4 certas dão a estrela-do-mar
		var w := Whale.new()
		w.setup([1, 1, 1, 1])
		whale_root.add_child(w)
		whale = w
		w.set_state("up")
		var target: Vector2 = island.cell_to_world(Vector2(0.78, 0))  # encostando na borda direita da peça inicial (cor 1)
		w.spots[0]["elem"] = 2
		w.position += target - w.spot_world(0)
		_update_whale(0.0)
		var wrong_ok: bool = not w.spots[0]["clean"]
		w.spots[0]["elem"] = 1
		for i in 4:
			w.position += target - w.spot_world(i)
			_update_whale(0.0)
		print("[teste] baleia: cor errada ignorada=", wrong_ok, " limpos=", w.cleaned(), " estado=", w.state, " especial=", special)
		ok = ok and wrong_ok and w.cleaned() == 4 and w.state == "jet" and special == "estrela"
		# 4) estrela-do-mar: peças com o dobro do tempo, +1/4 nas barras, monstro que encosta voa
		power_charge["ima"] = 0.0
		var before: float = island.remaining(Vector2i.ZERO)
		var m := Actor.new()
		m.kind = "gorila"
		m.cpos = island.tobe.cpos
		m.speed = 0.0
		island.monsters.append(m)
		var hearts_before := hearts
		activate_special()
		var after: float = island.remaining(Vector2i.ZERO)
		_update_monsters(0.016)
		print("[teste] estrela: vida ", before, " -> ", after, " ímã=", power_charge["ima"], " monstros=", island.monsters.size(), " corações=", hearts)
		ok = ok and absf(after - before * 2.0) < 0.1 and is_equal_approx(power_charge["ima"], G.STAR_BONUS) and island.monsters.is_empty() and hearts == hearts_before
		# 5) estrela pendente vem na próxima ilha
		star_pending = true
		_spawn_one(G.WORLDS[0], 0, "", 1.0)
		var last = incoming_root.get_child(incoming_root.get_child_count() - 1)
		print("[teste] ilha com estrela: ", last.kind)
		ok = ok and last.kind == "esp_estrela" and not star_pending
		print("[teste] pacote 3: ", "OK" if ok else "FALHOU")
		get_tree().quit()
	if OS.get_cmdline_user_args().has("demo_missoes"):
		# pacote 3: baleia com 2 bichinhos limpos, desafio na tela e estrela-do-mar ligada
		start_game()
		_apply_world(1, false)
		island.add_cell(Vector2i(1, 0), 1, [1, 1, 2, 0])
		island.add_cell(Vector2i(0, 1), 3, [2, 3, 3, 1])
		crab_t = 999.0
		whale_t = 0.01
		challenge = {"id": "cor", "text": "Encaixe %d peças %s", "goal": 5, "n": 3, "elem": 2, "prize": "cor", "t": 0.0}
		if OS.get_cmdline_user_args().has("shot"):
			get_tree().create_timer(2.5).timeout.connect(func():
				if whale != null:
					whale.spots[0]["clean"] = true
					whale.spots[3]["clean"] = true
				give_special("estrela", island.position, "")
				activate_special()
				await get_tree().create_timer(3.4).timeout
				get_viewport().get_texture().get_image().save_png("user://missoes.png")
				if whale != null:
					for sp in whale.spots:
						sp["clean"] = true
				await get_tree().create_timer(0.9).timeout
				get_viewport().get_texture().get_image().save_png("user://baleia_jato.png")
				print("[demo] prints salvos")
				get_tree().quit())
	if OS.get_cmdline_user_args().has("test_pacote4"):
		# confere as regras do pacote 4 e imprime o resultado (não grava o álbum)
		album = {}
		start_game()
		await get_tree().process_frame
		var ok := true
		for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			island.add_cell(c, 0, [0, 1, 2, 3])
		# 1) coqueiro atira: sombra na peça do Tobé e ele foge para uma vizinha
		var palm := Incoming.new()
		palm.cargo = "coqueiro"
		palm.kind = "coqueiro"
		palm.edges = [0, 1, 2, 3]
		palm.position = island.position + Vector2(220, -160)
		incoming_root.add_child(palm)
		palm.shoot_t = 0.0
		_update_palms(0.0)
		var t = island.tobe
		print("[teste] coqueiro: sombras=", island.coco_marks.size(), " Tobé foge para ", t.manual if t.has_manual else "nada")
		ok = ok and island.coco_marks.size() == 1 and t.has_manual and t.manual != t.cell()
		# 2) coco acerta o Tobé: -1 coração; com a Bolha ligada, só estoura a bolha
		island.coco_marks.clear()
		hearts = 3
		t.invuln = 0.0
		_coco_land({"cell": t.cell(), "t": 0.0, "from": Vector2.ZERO})
		var h1 := hearts
		special = "bolha"
		special_left = 15.0
		island.bubble = true
		t.invuln = 0.0
		_coco_land({"cell": t.cell(), "t": 0.0, "from": Vector2.ZERO})
		print("[teste] coco: corações ", h1, " depois com bolha ", hearts, " bolha=", island.bubble)
		ok = ok and h1 == 2 and hearts == 2 and not island.bubble
		# 3) encaixar o coqueiro: vira amigo, dá a Chuva de cocos e entra no álbum
		_attach(palm, Vector2i(0, -1), 0)
		print("[teste] coqueiro amigo: especial=", special, " álbum=", album.keys())
		ok = ok and special == "cocos" and album.has("amigo_coqueiro")
		# 4) Chuva de cocos derruba o monstro
		var m := Actor.new()
		m.kind = "gorila"
		m.cpos = Vector2(2, 0)
		m.speed = 0.0
		m.pause_t = 99.0
		island.monsters.append(m)
		activate_special()
		await get_tree().create_timer(1.2).timeout
		print("[teste] chuva de cocos: monstros=", island.monsters.size())
		ok = ok and island.monsters.is_empty()
		# 5) tubarão arranca 1 peça, mas nunca a do Tobé
		special = ""
		special_left = 0.0
		island.bubble = false
		var victim := Vector2i(2, 0) if island.tobe.cell() != Vector2i(2, 0) else Vector2i(-1, 0)
		var n0: int = island.cells.size()
		var sh := Crab.new()
		sh.kind = "tubarao"
		sh.vel = Vector2.DOWN * 300.0
		crab_root.add_child(sh)
		_shark_hit(sh, victim)
		var n1: int = island.cells.size()
		var sh2 := Crab.new()
		sh2.kind = "tubarao"
		crab_root.add_child(sh2)
		_shark_hit(sh2, island.tobe.cell())
		print("[teste] tubarão: peças ", n0, " -> ", n1, " (mordeu ", victim, "), na peça do Tobé -> ", island.cells.size())
		ok = ok and not island.cells.has(victim) and n1 < n0 and island.cells.size() == n1 and island.cells.has(island.tobe.cell())
		# 6) cavalo-marinho enche um poder e entra no álbum
		for id in G.POWERS:
			power_charge[id] = 0.0
		var tc: Vector2i = island.tobe.cell()
		island.items[tc] = "cavalo_marinho"
		_collect(tc)
		var full := G.POWERS.filter(func(id): return power_charge[id] >= 1.0)
		print("[teste] cavalo-marinho: cheios=", full, " no álbum=", album.has("cavalo_marinho"))
		ok = ok and full.size() == 1 and album.has("cavalo_marinho")
		# 7) as 5 conchas completam a página e liberam a coroa
		for k in G.SHELLS:
			island.items[tc] = k
			_collect(tc)
		print("[teste] conchas: página=", page_done(G.ALBUM[0]), " visual=", outfit, " liberado=", outfit_unlocked("coroa"))
		ok = ok and page_done(G.ALBUM[0]) and outfit == "coroa" and outfit_unlocked("coroa") and not outfit_unlocked("pirata")
		print("[teste] pacote 4: ", "OK" if ok else "FALHOU")
		get_tree().quit()
	if OS.get_cmdline_user_args().has("demo_pacote4"):
		# pacote 4: Tempestade com coqueiro atirando, tubarões avisando, conchas e cavalo-marinho, Tobé de pirata
		album = {}
		start_game()
		_apply_world(3, false)
		island.outfit = "pirata"
		island.tobe.stun = 99.0 if OS.get_cmdline_user_args().has("parado") else 0.0
		island.add_cell(Vector2i(1, 0), 1, [1, 1, 2, 0])
		island.add_cell(Vector2i(-1, 0), 2, [3, 2, 2, 0])
		island.add_cell(Vector2i(0, 1), 3, [2, 3, 3, 1])
		island.items[Vector2i(-1, 0)] = "concha_vieira"
		island.items[Vector2i(0, 1)] = "cavalo_marinho"
		crab_t = 999.0
		whale_t = 999.0
		shark_t = 999.0
		palm_t = 999.0
		var palm := Incoming.new()
		palm.cargo = "coqueiro"
		palm.kind = "coqueiro"
		palm.edges = [2, 0, 1, 3]
		palm.position = island.position + Vector2(-330, -170)
		palm.vel = Vector2(12, 0)
		palm.shoot_t = 2.0
		incoming_root.add_child(palm)
		var sh := Incoming.new()
		sh.edges = [0, 1, 2, 3]
		sh.cargo = "item"
		sh.kind = "concha_buzio"
		sh.position = island.position + Vector2(330, 160)
		sh.vel = Vector2(-10, -4)
		incoming_root.add_child(sh)
		give_special("cocos", island.position, "")
		if OS.get_cmdline_user_args().has("shot"):
			get_tree().create_timer(1.0).timeout.connect(func():
				_launch_sharks())
			get_tree().create_timer(0.6).timeout.connect(func():
				print("[demo] tobé na tela: ", get_viewport().get_canvas_transform() * island.cell_to_world(island.tobe.cpos), " facing=", island.tobe.facing)
				get_viewport().get_texture().get_image().save_png("user://pacote4_a.png"))
			get_tree().create_timer(2.45).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("user://pacote4.png")
				print("[demo] print salvo")
				get_tree().quit())
	if OS.get_cmdline_user_args().has("demo_album"):
		# álbum aberto no menu, com uma página completa e o Tobé de coroa
		album = {"concha_vieira": 3, "concha_caramujo": 1, "concha_buzio": 2, "concha_mexilhao": 1, "concha_bolacha": 1,
			"peixe_raro": 2, "esp_estrela": 1, "amigo_siri": 1}
		outfit = "coroa"
		island.outfit = outfit
		hud.album_open = OS.get_cmdline_user_args().has("aberto")
		if OS.get_cmdline_user_args().has("shot"):
			get_tree().create_timer(1.0).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("user://album.png")
				print("[demo] print salvo")
				get_tree().quit())
	if OS.get_cmdline_user_args().has("demo_options"):
		# painel de opções aberto no meio da partida (com "shot" salva um print e fecha)
		start_game()
		get_tree().create_timer(1.5).timeout.connect(func():
			open_options()
			if OS.get_cmdline_user_args().has("shot"):
				await get_tree().create_timer(0.5).timeout
				get_viewport().get_texture().get_image().save_png("user://opcoes.png")
				print("[demo] print salvo em ", ProjectSettings.globalize_path("user://opcoes.png"))
				get_tree().quit())


# ---------- modo de teste: joga sozinho (godot -- autoplay) ----------

var autoplay := false
var bot_t := 0.0


func _bot(delta: float) -> void:
	bot_t -= delta
	if state == "over":
		print("[bot] fim: ", death_reason, " pontos=", score, " ilha=", max_size, " tempo=", int(game_time), " mundo=", world_idx + 1,
			" poderes=", stats["poderes"], " peixes=", stats["peixes"], " pulos=", stats["pulos"])
		start_game()
		return
	if bot_t > 0.0:
		return
	bot_t = 0.35
	for id in G.POWERS:
		if power_charge[id] >= 1.0 and randf() < 0.3:
			activate_power(id)
	if special != "" and special_left <= 0.0 and randf() < 0.3:
		activate_special()
	# gira para casar a cor da ilha mais próxima, se não casar
	if island.preview.size() > 0 and not island.preview["ok"] and not island.is_spinning():
		island.tap_rotate(1 if randf() < 0.5 else -1)


# ---------- estados ----------

func start_game() -> void:
	state = "play"
	score = 0
	combo = 0
	best_combo = 0
	hearts = 3
	max_size = 1
	game_time = 0.0
	world_t = 0.0
	spawn_acc = -0.5
	choice_t = 18.0
	current_t = 14.0
	current_left = 0.0
	current_warn = 0.0
	anchor_t = 0.0
	for id in G.POWERS:
		power_charge[id] = 0.0
		power_left[id] = 0.0
	special = ""
	special_left = 0.0
	special_gift = false
	crab_t = G.CRAB_FIRST
	crab_warn = 0.0
	siri_t = G.SIRI_FIRST
	island.bubble = false
	_reset_missions()
	for c in crab_root.get_children():
		c.queue_free()
	stats = {"poderes": 0, "peixes": 0, "pulos": 0}
	Engine.time_scale = 1.0
	for c in incoming_root.get_children():
		c.queue_free()
	island.game_time = 0.0
	island.reset()
	island.shield = false
	cam.position = Vector2.ZERO
	_apply_world(0, false)
	sfx.play("start")
	hud.show_play()
	hud.banner("Mundo 1 · Mar Calmo", "Gire até as bordas da mesma cor se encostarem")
	# robô de teste começando direto num mundo mais adiante (ex.: -- autoplay mundo4)
	for i in range(1, G.WORLDS.size()):
		if autoplay and OS.get_cmdline_user_args().has("mundo%d" % (i + 1)):
			_apply_world(i, false)


func game_over(reason: String) -> void:
	if state != "play":
		return
	state = "over"
	death_reason = reason
	island.preview = {}
	Engine.time_scale = 1.0
	sfx.play("over")
	var new_record := score > best_score
	best_score = max(best_score, score)
	best_size = max(best_size, max_size)
	_save()
	hud.show_game_over(reason, new_record)


func toggle_pause() -> void:
	if hud.album_open:
		hud.album_open = false
		return
	if hud.options_open:
		close_options()
		return
	if state != "play":
		return
	get_tree().paused = not get_tree().paused
	hud.set_paused(get_tree().paused)


## Abre o painel de opções (volume, menu, sair). No jogo, pausa a partida.
func open_options() -> void:
	if state == "over":
		return
	if state == "play":
		get_tree().paused = true
		hud.set_paused(true)
	island.spin_release(-1)
	island.spin_release(1)
	hud.options_open = true
	sfx.play("click")


## Fecha o painel e volta direto para o jogo (ou para a tela inicial).
func close_options() -> void:
	hud.options_open = false
	sfx.save_options()
	if state == "play":
		get_tree().paused = false
		hud.set_paused(false)
	sfx.play("click")


## Abandona a partida atual e volta para a tela inicial (sem contar recorde).
func quit_to_menu() -> void:
	hud.options_open = false
	sfx.save_options()
	get_tree().paused = false
	hud.set_paused(false)
	Engine.time_scale = 1.0
	state = "menu"
	island.preview = {}
	for c in incoming_root.get_children():
		c.queue_free()
	for c in crab_root.get_children():
		c.queue_free()
	island.bubble = false
	special = ""
	special_left = 0.0
	_reset_missions()
	island.reset()
	island.shield = false
	cam.position = Vector2.ZERO
	_apply_world(0, false)
	hud.show_menu()


func quit_game() -> void:
	sfx.save_options()
	get_tree().quit()


## No navegador não dá para fechar o jogo.
func can_quit() -> bool:
	return not OS.has_feature("web")


func _apply_world(i: int, announce: bool) -> void:
	world_idx = i
	world_t = 0.0
	var W: Dictionary = G.WORLDS[i]
	var tw := create_tween().set_parallel(true)
	var from_sea: Color = sea_mat.get_shader_parameter("sea") if sea_mat.get_shader_parameter("sea") != null else W["sea"]
	var from_deep: Color = sea_mat.get_shader_parameter("deep") if sea_mat.get_shader_parameter("deep") != null else W["sea2"]
	tw.tween_method(func(v): sea_mat.set_shader_parameter("sea", v), from_sea, W["sea"], 2.5)
	tw.tween_method(func(v): sea_mat.set_shader_parameter("deep", v), from_deep, W["sea2"], 2.5)
	island.sea_color = W["sea"]
	if announce:
		sfx.play("start", 0.9)
		if i == G.CRAB_FROM_WORLD:
			crab_t = G.CRAB_FIRST
		if i == G.WHALE_FROM_WORLD:
			whale_t = G.WHALE_FIRST
		if i == G.PALM_FROM_WORLD:
			palm_t = G.PALM_FIRST
		if i == G.SHARK_FROM_WORLD:
			shark_t = G.SHARK_FIRST
		var tips := ["", "Correntes e caranguejos! Vire para eles a borda da cor deles.",
			"Coqueiros atiram cocos! Encaixe um na cor certa para virar amigo.", "Tempestade e tubarões! Saia da linha vermelha."]
		hud.banner("Mundo %d · %s" % [i + 1, W["name"]], tips[i])


# ---------- laço principal ----------

func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	if autoplay:
		_bot(delta)
	if state == "play":
		_play(delta)
	else:
		menu_t += delta
	_update_camera(delta, vp)
	sea_life.view = _view_world()
	sea_life.focus = island.position
	sea_life.night = night
	var W: Dictionary = G.WORLDS[world_idx]
	night = move_toward(night, W["night"], delta * 0.4)
	rain = move_toward(rain, 1.0 if W["storm"] else 0.0, delta * 0.4)
	flash = max(0.0, flash - delta * 3.0)
	hurt_fx = max(0.0, hurt_fx - delta * 2.0)
	var low := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008) if (state == "play" and hearts == 1) else 0.0
	overlay_mat.set_shader_parameter("night", night)
	overlay_mat.set_shader_parameter("rain", rain)
	overlay_mat.set_shader_parameter("flash", flash)
	overlay_mat.set_shader_parameter("hurt", max(hurt_fx, low * 0.35))
	sea_mat.set_shader_parameter("cam_pos", cam.get_screen_center_position())
	sea_mat.set_shader_parameter("zoom", cam.zoom.x)
	sea_mat.set_shader_parameter("screen", vp)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif hud.options_open or hud.album_open:
		pass
	elif state != "play" and event.is_action_pressed("confirm"):
		start_game()
	elif state == "play" and not get_tree().paused:
		if event.is_action_pressed("rot_left"):
			spin_press(-1)
		elif event.is_action_pressed("rot_right"):
			spin_press(1)
		elif event.is_action_released("rot_left"):
			spin_release(-1)
		elif event.is_action_released("rot_right"):
			spin_release(1)
		else:
			for i in G.POWERS.size():
				if event.is_action_pressed("power_%d" % (i + 1)):
					activate_power(G.POWERS[i])
			if event.is_action_pressed("power_5"):
				activate_special()


## Começa a girar (-1 anti-horário, 1 horário). Segurar acelera o giro.
func spin_press(dir: int) -> void:
	if state != "play" or get_tree().paused:
		return
	island.spin_press(dir)
	sfx.play("click", 0.85 + randf() * 0.1, -10.0)


func spin_release(dir: int) -> void:
	island.spin_release(dir)


## Toque na tela: se cair numa peça da ilha, o Tobé vai até lá. Devolve true se acertou a ilha.
func tap_island(screen_pos: Vector2) -> bool:
	if state != "play":
		return false
	var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var q: Vector2 = island.world_to_cell(wp)
	var c := Vector2i(roundi(q.x), roundi(q.y))
	if not island.cells.has(c) or (q - Vector2(c)).length() > 0.75:
		return false
	if island.is_unsafe(c):
		popup(wp, "Peça quebrando!", Color("ffd0d0"))
		sfx.play("bump", 1.3, -8.0)
		return true
	var t = island.tobe
	t.has_manual = true
	t.manual = c
	t.manual_t = 2.5
	t.replan = 0.0
	sfx.play("click", 1.4, -8.0)
	return true


func _play(delta: float) -> void:
	game_time += delta
	island.game_time = game_time
	world_t += delta
	if world_t >= G.WORLD_TIME and world_idx < G.WORLDS.size() - 1:
		_apply_world(world_idx + 1, true)
	var W: Dictionary = G.WORLDS[world_idx]

	_update_current(delta, W)
	if W["storm"]:
		lightning_t -= delta
		if lightning_t <= 0.0:
			flash = 1.0
			lightning_t = randf_range(5.0, 10.0)
			sfx.play("bump", 0.5, -4.0)

	if anchor_t > 0.0:
		anchor_t -= delta
		for c in island.cells:
			island.cells[c]["born"] += delta

	_update_powers(delta)
	_check_fish()
	_check_sinking()
	if state != "play":
		return
	_update_tobe(delta)
	_update_monsters(delta)
	if state != "play":
		return
	_update_crabs(delta)
	_update_siri(delta)
	_update_whale(delta)
	_update_star(delta)
	_update_challenge(delta)
	_update_palms(delta)
	if state != "play":
		return
	_update_sharks(delta)
	_update_coco_rain(delta)
	_spawner(delta, W)
	_update_incoming()
	max_size = max(max_size, island.cells.size())


func _update_current(delta: float, W: Dictionary) -> void:
	if not W["current"]:
		return
	if current_left <= 0.0 and current_warn <= 0.0:
		current_t -= delta
		if current_t <= 0.0:
			current_warn = 1.5
			current_dir = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN].pick_random()
			sfx.play("whoosh", 1.0, -6.0)
	if current_warn > 0.0:
		current_warn -= delta
		if current_warn <= 0.0:
			current_left = 3.0
	if current_left > 0.0:
		current_left -= delta
		# a corrente empurra as ilhas que estão chegando
		for inc in incoming_root.get_children():
			if not inc.drifting:
				inc.position += current_dir * (70.0 + 15.0 * world_idx) * delta
		if randf() < delta * 14.0:
			var p: Vector2 = island.position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (island.radius_cells() + 1.5) * G.TILE
			burst(p, Color(1, 1, 1, 0.8), 6, 60.0, 0.6)
		if current_left <= 0.0:
			current_t = randf_range(12.0, 18.0)


# ---------- afundamento ----------

func _check_sinking() -> void:
	var gone: Array[Vector2i] = []
	for c in island.cells:
		if island.remaining(c) <= 0.0:
			gone.append(c)
	if gone.is_empty():
		return
	var tcell: Vector2i = island.tobe.cell()
	for c in gone:
		_remove_cell(c)
	sfx.play("sink")
	if island.cells.is_empty():
		splash(island.cell_to_world(island.tobe.cpos))
		game_over("A ilha do Tobé afundou!")
		return
	if gone.has(tcell):
		tcell = _tobe_jump_to_safety(tcell)
	var info: Dictionary = island.bfs(tcell)
	for c in island.cells.keys():
		if not info["dist"].has(c):
			_detach(c)
	island.recompute_pivot()


func _remove_cell(c: Vector2i) -> void:
	var wp: Vector2 = island.cell_to_world(Vector2(c))
	splash(wp)
	island.items.erase(c)
	for m in island.monsters.duplicate():
		if m.cell() == c:
			_monster_overboard(m, 1)
	island.cells.erase(c)


func _detach(c: Vector2i) -> void:
	var wp: Vector2 = island.cell_to_world(Vector2(c))
	var d := Incoming.new()
	d.edges = island.cells[c]["edges"].duplicate()
	d.drifting = true
	d.position = wp
	d.vel = (wp - island.position).normalized() * 60.0
	incoming_root.add_child(d)
	island.items.erase(c)
	for m in island.monsters.duplicate():
		if m.cell() == c:
			_monster_overboard(m, 1)
	island.cells.erase(c)


# ---------- Tobé ----------

## A peça do Tobé afundou: ele pula para a peça mais perto (de preferência sem rachadura).
func _tobe_jump_to_safety(from: Vector2i) -> Vector2i:
	var t = island.tobe
	var best := from
	var bd := 1e9
	for c in island.cells:
		var d := (Vector2(c) - Vector2(from)).length() + (20.0 if island.is_unsafe(c) else 0.0)
		if d < bd:
			bd = d
			best = c
	splash(island.cell_to_world(t.cpos))
	t.cpos = Vector2(best)
	t.path.clear()
	t.has_manual = false
	t.stun = 0.4
	t.invuln = max(t.invuln, 1.0)
	t.replan = 0.0
	var wp: Vector2 = island.cell_to_world(t.cpos)
	burst(wp, Color(1, 1, 1, 0.9), 14, 200.0, 0.5)
	popup(wp, "Ufa! Pulou!", Color("bdf2ff"))
	stats["pulos"] += 1
	return best

func _update_tobe(delta: float) -> void:
	var t = island.tobe
	t.invuln = max(0.0, t.invuln - delta)
	t.stun = max(0.0, t.stun - delta)
	t.food_t = max(0.0, t.food_t - delta)
	t.replan -= delta
	var cur: Vector2i = t.cell()
	if not island.cells.has(cur):
		return
	# destino escolhido pelo jogador: vai até lá, espera um pouco e volta a andar sozinho
	if t.has_manual and not island.cells.has(t.manual):
		t.has_manual = false
	if t.has_manual and cur == t.manual and t.path.is_empty():
		t.manual_t -= delta
		if t.manual_t <= 0.0:
			t.has_manual = false
	var near := 99.0
	for m in island.monsters:
		near = min(near, (m.cpos - t.cpos).length())
	var punching: bool = power_left["soco"] > 0.0 and not island.monsters.is_empty()
	var repairing: bool = power_left["conserto"] > 0.0
	t.fleeing = near < 2.3 and not punching
	# super soco: o Tobé derruba quem estiver perto
	if power_left["soco"] > 0.0:
		for m in island.monsters.duplicate():
			if (m.cpos - t.cpos).length() < 0.8:
				_punch(m)
	# conserto: a peça onde o Tobé está recupera vida rápido
	if repairing and island.cells.has(cur):
		var cd: Dictionary = island.cells[cur]
		if cd["born"] < game_time:
			cd["born"] = min(cd["born"] + 22.0 * delta, game_time)
			repair_fx_t -= delta
			if repair_fx_t <= 0.0:
				repair_fx_t = 0.18
				burst(island.cell_to_world(Vector2(cur)) + Vector2(randf_range(-25, 25), randf_range(-25, 25)), Color("b9ff9e"), 5, 120.0, 0.5)
	if t.replan <= 0.0:
		t.replan = 0.25
		var start: Vector2i = t.path[0] if t.path.size() > 0 and island.cells.has(t.path[0]) else cur
		if start != cur and island.is_unsafe(start):
			start = cur  # o próximo passo rachou: recalcula a partir de onde está
		var info: Dictionary = island.bfs(start, true)
		var dist: Dictionary = info["dist"]
		var dest := start
		var best := -1e9
		if t.has_manual:
			dist = {}
			dest = t.manual
		elif punching:
			# vai atrás do monstro mais perto
			var bd := 1e9
			for m in island.monsters:
				var mc: Vector2i = m.cell()
				if dist.has(mc) and dist[mc] < bd:
					bd = dist[mc]
					dest = mc
			dist = {}
		elif repairing and not t.fleeing:
			# vai para a peça mais perto de afundar
			var low := 1e9
			for c in dist:
				var r: float = island.remaining(c) + dist[c] * 1.5
				if r < low:
					low = r
					dest = c
			dist = {}
		for c in dist:
			var s := 0.0
			var rem: float = island.remaining(c)
			if t.fleeing:
				var md := 99.0
				for m in island.monsters:
					md = min(md, (m.cpos - Vector2(c)).length())
				s = md * 2.0 - dist[c] * 0.25 - (6.0 if rem < 20.0 else 0.0)
			elif island.is_unsafe(start):
				s = rem - dist[c] * 3.0
			elif not island.items.is_empty():
				s = -dist[c] - (100.0 if not island.items.has(c) else 0.0) - (8.0 if rem < 12.0 else 0.0)
			else:
				s = -(Vector2(c) - island.pivot).length() - (5.0 if rem < 20.0 else 0.0)
			if s > best:
				best = s
				dest = c
		# refaz o caminho se mudou o destino ou se alguma peça do caminho rachou
		var cracked := false
		for i in range(1, t.path.size()):
			if island.cells.has(t.path[i]) and island.is_unsafe(t.path[i]):
				cracked = true
		if dest != t.target or t.path.is_empty() or cracked:
			island.set_destination(t, dest, info, true)
	if t.stun <= 0.0:
		var spd: float = t.speed * (1.5 if t.food_t > 0.0 else 1.0) * (2.0 if punching else 1.0)
		island.step_actor(t, delta, spd)
	else:
		t.moving = false
	var now: Vector2i = t.cell()
	if island.items.has(now) and (t.cpos - Vector2(now)).length() < 0.35:
		_collect(now)


func _collect(c: Vector2i) -> void:
	var kind: String = island.items[c]
	island.items.erase(c)
	var wp: Vector2 = island.cell_to_world(Vector2(c))
	sfx.play("item")
	burst(wp, Color("fff3a8"), 16, 220.0, 0.6)
	if kind.begins_with("esp_"):
		give_special(kind.substr(4), wp, "")
		if kind == "esp_estrela":
			album_add("esp_estrela")
		return
	if kind.begins_with("concha_"):
		score += G.SHELL_POINTS
		popup(wp, G.ALBUM_NAMES[kind] + "! +%d" % G.SHELL_POINTS, Color("ffe0f0"))
		album_add(kind)
		return
	if kind == "peixe" or kind == "peixe_raro" or kind == "cavalo_marinho":
		challenge_event("peixes")
	if kind == "peixe_raro" or kind == "cavalo_marinho":
		# peixe arco-íris e cavalo-marinho: enchem por completo um poder sorteado (de preferência um que não está cheio)
		album_add(kind)
		var options := G.POWERS.filter(func(id): return power_charge[id] < 1.0 and power_left[id] <= 0.0)
		if options.is_empty():
			options = G.POWERS.duplicate()
		var pid: String = options.pick_random()
		power_charge[pid] = 1.0
		score += 200
		popup(wp, ("Peixe arco-íris! " if kind == "peixe_raro" else "Cavalo-marinho! ") + G.POWER_INFO[pid]["name"] + " pronto!", G.POWER_INFO[pid]["color"].lightened(0.35))
		burst(wp, G.ELEM[randi() % 4], 24, 300.0, 0.7)
		sfx.play("gold")
		return
	if G.POWER_INFO.has(kind):
		var was: float = power_charge[kind]
		power_charge[kind] = min(1.0, was + G.POWER_PICKUP)
		var info: Dictionary = G.POWER_INFO[kind]
		popup(wp, info["name"] + (" pronto!" if power_charge[kind] >= 1.0 and was < 1.0 else " +"), info["color"].lightened(0.3))
		return
	match kind:
		"peixe":
			if hearts < G.MAX_HEARTS:
				hearts += 1
				popup(wp, "Peixe! +1 vida", Color("ffb347"))
			else:
				score += 150
				popup(wp, "Peixe! +150", Color("ffb347"))
		"tesouro":
			score += 300
			popup(wp, "+300", Color("ffe066"))
		"comida":
			island.tobe.food_t = 10.0
			popup(wp, "Comida! Mais rápido", Color("ff8f6b"))
		"vida":
			hearts = min(G.MAX_HEARTS, hearts + 1)
			popup(wp, "+1 vida", Color("ff6b8a"))
		"ancora":
			anchor_t = 10.0
			popup(wp, "Âncora! Nada afunda", Color("9fd3ff"))
		"escudo":
			island.shield = true
			popup(wp, "Escudo!", Color("7fd3ff"))


func _hurt() -> void:
	var t = island.tobe
	var wp: Vector2 = island.cell_to_world(t.cpos)
	if island.shield:
		island.shield = false
		t.invuln = 1.0
		popup(wp, "Escudo quebrou!", Color("7fd3ff"))
		sfx.play("bump", 1.4)
		return
	hearts -= 1
	t.invuln = 1.5
	t.stun = 0.3
	shake = 12.0
	hurt_fx = 1.0
	sfx.play("hurt")
	hitstop(0.08)
	popup(wp, "Ai!", Color("ff6b6b"))
	if hearts <= 0:
		game_over("O Tobé foi pego!")


# ---------- monstros ----------

func _update_monsters(delta: float) -> void:
	var t = island.tobe
	for m in island.monsters.duplicate():
		m.replan -= delta
		if m.replan <= 0.0:
			m.replan = 0.35
			if island.cells.has(t.cell()):
				island.set_destination(m, t.cell())
		var spd: float = m.speed
		if m.pause_t > 0.0:
			m.pause_t -= delta
			m.anim += delta
			m.moving = false
			continue
		match m.kind:
			"gorila":
				m.dash_cd -= delta
				if m.dash_cd <= 0.0:
					m.dash_t = 0.7
					m.dash_cd = 5.0
				if m.dash_t > 0.0:
					m.dash_t -= delta
					spd *= 2.1
			"hiena":
				m.dash_cd -= delta
				if m.dash_cd <= 0.0:
					m.dash_cd = 1.3
					m.pause_t = 0.6
		island.step_actor(m, delta, spd)
		if star_on() and (m.cpos - t.cpos).length() < 0.6:
			_punch(m)  # estrela-do-mar: o monstro que encosta no Tobé voa para o mar
			continue
		if t.invuln <= 0.0 and power_left["soco"] <= 0.0 and (m.cpos - t.cpos).length() < 0.5:
			_hurt()
			if state != "play":
				return


func _monster_overboard(m, mult: int) -> void:
	var wp: Vector2 = island.cell_to_world(m.cpos)
	island.monsters.erase(m)
	splash(wp)
	var pts: int = G.MONSTERS[m.kind]["score"] * mult
	score += pts
	challenge_event("monstros")
	popup(wp, "Ao mar! +%d" % pts, Color("bdf2ff"))


# ---------- ilhas que chegam ----------

func _spawner(delta: float, W: Dictionary) -> void:
	var tw: float = clamp(world_t / G.WORLD_TIME, 0.0, 1.0)
	if world_idx == G.WORLDS.size() - 1:
		tw = clamp(world_t / (G.WORLD_TIME * 3.0), 0.0, 1.0)
	var ipm: float = lerp(W["ipm"][0], W["ipm"][1], tw)
	spawn_acc += delta * ipm / 60.0
	if spawn_acc >= 1.0:
		spawn_acc -= 1.0
		_spawn_one(W, -1, "", 1.0)
	if W["choice"]:
		choice_t -= delta
		if choice_t <= 0.0:
			choice_t = randf_range(20.0, 28.0)
			_spawn_choice(W)


func _view_world() -> Rect2:
	var vp := get_viewport().get_visible_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - vp * 0.5, vp)


func _spawn_one(W: Dictionary, edge: int, force: String, spread: float) -> void:
	var view := _view_world()
	var e := edge if edge >= 0 else randi() % 4
	var margin := G.TILE * 1.2 + randf_range(60.0, 260.0)
	var c := view.get_center()
	var pos: Vector2
	match e:
		0: pos = Vector2(c.x + randf_range(-0.42, 0.42) * view.size.x, view.position.y - margin)
		1: pos = Vector2(view.end.x + margin, c.y + randf_range(-0.42, 0.42) * view.size.y)
		2: pos = Vector2(c.x + randf_range(-0.42, 0.42) * view.size.x, view.end.y + margin)
		_: pos = Vector2(view.position.x - margin, c.y + randf_range(-0.42, 0.42) * view.size.y)
	var r: float = island.radius_cells()
	var aim: Vector2 = island.position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (r + 2.2) * G.TILE * spread
	var inc := Incoming.new()
	inc.position = pos
	inc.vel = (aim - pos).normalized() * W["speed"] * randf_range(0.85, 1.15)
	inc.edges = G.random_edges()
	var roll := randf()
	var cargo := force
	var orb := false
	if cargo == "" and star_pending:
		star_pending = false
		cargo = "item"
		inc.kind = "esp_estrela"
	elif cargo == "":
		if game_time > 15.0 and randf() < 0.04:
			inc.wild = true
			cargo = "item"
		elif game_time > 20.0 and randf() < G.MONO_CHANCE:
			# ilha rara de uma cor só: sem carga, dura 180 s
			inc.mono = true
			var col := randi() % 4
			inc.edges = [col, col, col, col]
		elif randf() < G.SHELL_CHANCE:
			cargo = "item"
			inc.kind = _pick_shell()
		elif game_time > 25.0 and roll < W["monster"]:
			cargo = "monster"
		elif roll < W["monster"] + W["item"]:
			cargo = "item"
		elif randf() < G.ORB_CHANCE:
			cargo = "item"
			orb = true
	if cargo == "monster":
		inc.cargo = "monster"
		inc.kind = W["monsters"].pick_random()
		inc.weak = randi() % 4
	elif cargo == "item":
		inc.cargo = "item"
		if inc.kind == "esp_estrela" or inc.kind.begins_with("concha_"):
			pass
		elif inc.wild:
			inc.kind = "tesouro"
		elif orb or randf() < 0.4:
			inc.kind = G.POWERS.pick_random()  # orbe de poder
		elif game_time > 30.0 and randf() < G.SPECIAL_ITEM_CHANCE:
			inc.kind = "esp_giro"  # orbe do poder especial (a Bolha só vem do siri)
		else:
			inc.kind = G.pick_weighted(G.ITEMS, G.ITEM_WEIGHTS)
	incoming_root.add_child(inc)


## Onda de escolha: várias ilhas juntas; o jogador decide quais valem a pena.
func _spawn_choice(W: Dictionary) -> void:
	var count := 3 if world_idx < 3 else randi_range(4, 5)
	var edges := [0, 1, 2, 3]
	edges.shuffle()
	for i in count:
		var force := "monster" if i == 0 else ("item" if i == 1 else "")
		_spawn_one(W, edges[i % 4], force, 0.6)
	hud.banner("Onda de ilhas!", "Escolha quais valem a pena")
	sfx.play("whoosh", 1.3)


func _update_incoming() -> void:
	var view := _view_world()
	var cen := view.get_center()
	var best_prev := {}
	var best_d := 99.0
	for inc in incoming_root.get_children():
		if inc.drifting or inc.is_queued_for_deletion():
			continue
		inc.sea_color = island.sea_color
		var rel: Vector2 = inc.position - cen
		if inc.age > 4.0 and rel.length() > view.size.length() * 0.85 and inc.vel.dot(rel) > 0.0:
			inc.queue_free()
			continue
		if inc.bounce_t > 0.0:
			continue
		if power_left["ima"] > 0.0:
			# magnetismo: puxa as ilhas que passam perto
			var to_isl: Vector2 = island.position - inc.position
			if to_isl.length() < (island.radius_cells() + 6.0) * G.TILE:
				var spd: float = max(inc.vel.length(), 130.0)
				inc.vel = inc.vel.lerp(to_isl.normalized() * spd, 1.0 - exp(-get_process_delta_time() * 2.5))
		var q: Vector2 = island.world_to_cell(inc.position)
		var contact: Dictionary = island.find_contact(q)
		if contact.is_empty():
			var pc: Dictionary = island.find_contact(q, 1.9)
			if not pc.is_empty():
				var d := (q - Vector2(pc["cell"])).length()
				if d < best_d:
					best_d = d
					best_prev = {"slot": pc["slot"], "ok": island.slot_color(pc["slot"], inc) >= 0}
			continue
		var col: int = island.slot_color(contact["slot"], inc)
		if col >= 0:
			_attach(inc, contact["slot"], col)
		else:
			_bounce(inc, contact["cell"])
	island.preview = best_prev


func combo_mult() -> int:
	if combo >= 15: return 5
	if combo >= 10: return 4
	if combo >= 6: return 3
	if combo >= 3: return 2
	return 1


func _attach(inc, slot: Vector2i, elem: int) -> void:
	# a dourada vira uma peça comum de 4 cores depois de encaixar
	var edges: Array = G.random_edges() if inc.wild else island.local_edges(inc)
	island.add_cell(slot, elem, edges, G.MONO_LIFE if inc.mono else G.PIECE_LIFE)
	combo += 1
	best_combo = max(best_combo, combo)
	var wp: Vector2 = island.cell_to_world(Vector2(slot))
	if inc.wild:
		for id in G.POWERS:
			if power_left[id] <= 0.0:
				power_charge[id] = min(1.0, power_charge[id] + G.POWER_PER_ATTACH)
	else:
		# a cor encaixada enche a barra do poder dela
		var pid: String = G.ELEM_POWER[elem]
		if power_left[pid] <= 0.0:
			var was: float = power_charge[pid]
			power_charge[pid] = min(1.0, was + G.POWER_PER_COLOR * (2.0 if inc.mono else 1.0))
			if was < 1.0 and power_charge[pid] >= 1.0:
				popup(wp + Vector2(0, -44), G.POWER_INFO[pid]["name"] + " pronto!", G.POWER_INFO[pid]["color"].lightened(0.3))
	if inc.mono:
		popup(wp + Vector2(0, 40), "Ilha rara! Dura 3 min", Color("fff3c4"))
	challenge_event("combo", combo)
	if not inc.wild:
		challenge_event("cor", 1, elem)
	if combo >= G.SPECIAL_COMBO and not special_gift:
		special_gift = true
		give_special("giro", wp, "Combo %d! " % combo)
	var mult := combo_mult()
	var pts := 100 * mult + (300 if inc.wild else 0)
	score += pts
	popup(wp, ("+%d" % pts) + (("  ×%d" % mult) if mult > 1 else ""), G.GOLD if inc.wild else G.ELEM[elem].lightened(0.35))
	sfx.play("gold" if inc.wild else "elem%d" % elem, pow(2.0, min(combo - 1, 12) / 12.0))
	burst(wp, G.GOLD if inc.wild else G.ELEM[elem], 22, 300.0, 0.7)
	hitstop(0.04)
	if inc.cargo == "item" and not inc.wild:
		island.items[slot] = inc.kind
	if inc.cargo == "coqueiro":
		# coqueiro encaixado na cor certa vira amigo e dá a Chuva de cocos
		popup(wp + Vector2(0, -40), "O coqueiro virou amigo!", Color("c8f5a0"))
		if not give_special("cocos", wp, ""):
			score += 300
		album_add("amigo_coqueiro")
	if inc.cargo == "monster":
		var m := Actor.new()
		m.kind = inc.kind
		m.cpos = Vector2(slot)
		m.weak = inc.weak
		m.speed = G.MONSTERS[inc.kind]["speed"]
		m.pause_t = 1.0
		m.replan = 0.0
		island.monsters.append(m)
		sfx.play("roar")
		shake = 8.0
		popup(wp + Vector2(0, -40), "Monstro a bordo!", Color("ff9e9e"))
	# onda elemental: derruba os monstros cujo ponto fraco é a cor anexada
	var hit := []
	for m in island.monsters:
		if m.weak == elem and m.pause_t < 0.99:
			hit.append(m)
	if not hit.is_empty():
		island.rings.append({"pos": Vector2(slot), "elem": elem, "t": 0.0})
		sfx.play("wave")
		shake = 6.0
		for m in hit:
			_monster_overboard(m, mult)
	inc.queue_free()


func _bounce(inc, cell: Vector2i) -> void:
	var away: Vector2 = (inc.position - island.cell_to_world(Vector2(cell))).normalized()
	inc.vel = away * max(170.0, inc.vel.length() * 1.3)
	inc.position += away * 10.0
	inc.bounce_t = 0.9
	if combo >= 3:
		popup(inc.position, "Combo perdido", Color("ffd0d0"))
	combo = 0
	special_gift = false
	island.tobe.stun = 1.0
	shake = 7.0
	sfx.play("bump")
	burst(inc.position, Color.WHITE, 10, 200.0, 0.4)


# ---------- poderes do Tobé ----------

## Liga um poder se a barrinha estiver cheia.
func activate_power(id: String) -> void:
	if state != "play" or get_tree().paused:
		return
	if power_charge[id] < 1.0 or power_left[id] > 0.0:
		return
	var info: Dictionary = G.POWER_INFO[id]
	power_charge[id] = 0.0
	stats["poderes"] += 1
	var wp: Vector2 = island.cell_to_world(island.tobe.cpos)
	sfx.play("wave", 1.2)
	burst(wp, info["color"], 26, 320.0, 0.7)
	island.rings.append({"pos": island.tobe.cpos, "color": info["color"], "t": 0.0})
	match id:
		"coracao":
			hearts = min(G.MAX_HEARTS, hearts + 2)
			island.tobe.invuln = max(island.tobe.invuln, 2.0)
			popup(wp, "+2 vidas!", info["color"].lightened(0.3))
			power_left[id] = 0.6  # só para a barrinha piscar
		_:
			power_left[id] = info["dur"]
			popup(wp, info["name"] + "!", info["color"].lightened(0.3))


## Guarda um poder especial no 5º espaço (troca o que estava lá, se não estiver ligado).
func give_special(id: String, wp: Vector2, prefix: String) -> bool:
	if special_left > 0.0:
		return false
	special = id
	var info: Dictionary = G.SPECIAL_INFO[id]
	popup(wp + Vector2(0, -60), prefix + info["name"] + "!", info["color"].lightened(0.35))
	sfx.play("gold", 1.2)
	return true


func activate_special() -> void:
	if state != "play" or get_tree().paused or special == "" or special_left > 0.0:
		return
	var info: Dictionary = G.SPECIAL_INFO[special]
	special_left = info["dur"]
	stats["poderes"] += 1
	var wp: Vector2 = island.cell_to_world(island.tobe.cpos)
	sfx.play("wave", 1.4)
	burst(wp, info["color"], 26, 320.0, 0.7)
	island.rings.append({"pos": island.tobe.cpos, "color": info["color"], "t": 0.0})
	hud.banner(info["name"] + "!", info["tip"])
	if special == "estrela":
		# peças atuais com o dobro do tempo que ainda tinham e +1/4 em todas as barras
		for c in island.cells:
			island.cells[c]["born"] += max(0.0, island.remaining(c))
		for id in G.POWERS:
			if power_left[id] <= 0.0:
				power_charge[id] = min(1.0, power_charge[id] + G.STAR_BONUS)


## Redemoinho ligado: tocar numa ilha que está chegando gira ela 90°.
func tap_incoming(screen_pos: Vector2) -> bool:
	if state != "play" or special != "giro" or special_left <= 0.0:
		return false
	var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var best = null
	var bd := G.TILE * 0.95
	for inc in incoming_root.get_children():
		if inc.drifting or inc.is_queued_for_deletion() or inc.wild or inc.mono:
			continue
		var d: float = inc.position.distance_to(wp)
		if d < bd:
			bd = d
			best = inc
	if best == null:
		return false
	best.rotate_cw()
	sfx.play("click", 1.6, -4.0)
	burst(best.position, G.SPECIAL_INFO["giro"]["color"], 8, 160.0, 0.35)
	return true


func _update_powers(delta: float) -> void:
	if special_left > 0.0:
		special_left = max(0.0, special_left - delta)
		if special_left <= 0.0:
			special = ""
	island.bubble = special == "bolha" and special_left > 0.0
	var hot := special == "giro" and special_left > 0.0
	for inc in incoming_root.get_children():
		inc.hot = hot and not inc.drifting and not inc.wild and not inc.mono
	for id in G.POWERS:
		power_left[id] = max(0.0, power_left[id] - delta)
	island.powers_on = {"ima": power_left["ima"] > 0.0, "soco": power_left["soco"] > 0.0,
		"conserto": power_left["conserto"] > 0.0, "estrela": star_on()}


func _punch(m) -> void:
	var wp: Vector2 = island.cell_to_world(m.cpos)
	burst(wp, Color("ffb347"), 20, 360.0, 0.5)
	popup(wp + Vector2(0, -30), "Soco!", Color("ffb347"))
	sfx.play("bump", 1.5)
	shake = 9.0
	hitstop(0.05)
	_monster_overboard(m, 2)


# ---------- caranguejos e siri (Pacote 2) ----------

## Ponto na borda da tela (lado 0..3), u de -0.5 a 0.5 ao longo dela; out > 0 empurra para fora.
func _screen_edge_point(side: int, u: float, out: float) -> Vector2:
	var v := _view_world()
	var c := v.get_center()
	match side:
		0: return Vector2(c.x + u * v.size.x, v.position.y - out)
		1: return Vector2(v.end.x + out, c.y + u * v.size.y)
		2: return Vector2(c.x + u * v.size.x, v.end.y + out)
		_: return Vector2(v.position.x - out, c.y + u * v.size.y)


func _crab_wave_active() -> bool:
	if crab_warn > 0.0:
		return true
	for cr in crab_root.get_children():
		if cr.kind == "caranguejo" and cr.state == "swim":
			return true
	return false


func _update_crabs(delta: float) -> void:
	if world_idx >= G.CRAB_FROM_WORLD:
		if crab_warn > 0.0:
			crab_warn -= delta
			# aviso: bolhinhas subindo na borda da tela de onde eles vêm
			if randf() < delta * 16.0:
				burst(_screen_edge_point(crab_side, randf_range(-0.3, 0.3), -40.0), Color(1, 1, 1, 0.85), 3, 60.0, 0.7)
			if crab_warn <= 0.0:
				_launch_crabs()
		elif not _event_busy():
			crab_t -= delta
			if crab_t <= 0.0:
				crab_t = randf_range(G.CRAB_EVERY[0], G.CRAB_EVERY[1]) - world_idx * 2.0
				crab_warn = G.CRAB_WARN
				crab_side = randi() % 4
				hud.banner("Caranguejos!", "Vire para eles a borda da cor deles")
				sfx.play("whoosh", 0.8)
	for cr in crab_root.get_children():
		if cr.kind != "caranguejo" or cr.is_queued_for_deletion():
			continue
		if cr.state == "swim":
			var to: Vector2 = island.position - cr.position
			cr.vel = cr.vel.lerp(to.normalized() * cr.speed, 1.0 - exp(-delta * 1.2))
			var hit := _edge_hit(cr.position, 0.8)
			if not hit.is_empty():
				_crab_hit(cr, hit["cell"], hit["dir"])
		elif cr.state == "stuck":
			cr.stuck_left -= delta
			if not island.cells.has(cr.cell) or cr.stuck_left <= 0.0:
				cr.fall()
				continue
			cr.position = island.cell_to_world(Vector2(cr.cell) + Vector2(cr.dir) * 0.55)
			cr.rotation = (Vector2(-cr.dir)).angle() + island.rotation + PI / 2.0
		elif cr.position.distance_to(island.position) > 4000.0:
			cr.queue_free()


## 4 a 6 caranguejos vindos do mesmo lado, em fila, com 1 ou 2 cores que a ilha tem na borda.
func _launch_crabs() -> void:
	var n := 3 + world_idx
	var exposed: Array = island.exposed_colors()
	exposed.shuffle()
	var cols: Array = exposed.slice(0, 1 if world_idx < 2 else 2)
	for i in n:
		var cr := Crab.new()
		cr.kind = "caranguejo"
		cr.elem = cols[i % cols.size()]
		cr.speed = 95.0 + 10.0 * world_idx
		cr.position = _screen_edge_point(crab_side, randf_range(-0.12, 0.12), 60.0 + i * 85.0)
		cr.vel = (island.position - cr.position).normalized() * cr.speed
		cr.rotation = cr.vel.angle() + PI / 2.0
		crab_root.add_child(cr)


## Encostou em alguma peça? Devolve a peça e o lado (de preferência um lado aberto).
func _edge_hit(wp: Vector2, reach: float) -> Dictionary:
	var q: Vector2 = island.world_to_cell(wp)
	var best := Vector2i.ZERO
	var bd := 99.0
	for c in island.cells:
		var d: Vector2 = q - Vector2(c)
		if max(abs(d.x), abs(d.y)) < reach and d.length() < bd:
			bd = d.length()
			best = c
	if bd > 90.0:
		return {}
	var dv: Vector2 = q - Vector2(best)
	var main_dir := Vector2i(int(signf(dv.x)), 0) if abs(dv.x) >= abs(dv.y) else Vector2i(0, int(signf(dv.y)))
	var other := Vector2i(0, int(signf(dv.y))) if abs(dv.x) >= abs(dv.y) else Vector2i(int(signf(dv.x)), 0)
	if main_dir == Vector2i.ZERO:
		main_dir = Vector2i(0, -1)
	var dir := main_dir
	if island.cells.has(best + main_dir) and other != Vector2i.ZERO and not island.cells.has(best + other):
		dir = other
	return {"cell": best, "dir": dir}


func _crab_hit(cr, cell: Vector2i, dir: Vector2i) -> void:
	var wp: Vector2 = island.cell_to_world(Vector2(cell) + Vector2(dir) * 0.5)
	var away: Vector2 = (cr.position - island.position)
	if away.length() < 1.0:
		away = Vector2.UP
	var col: int = island.edge_color(cell, dir)
	if col == cr.elem:
		var pts: int = G.CRAB_POINTS * combo_mult()
		score += pts
		cr.fling(away)
		popup(wp, "Defendeu! +%d" % pts, G.ELEM[col].lightened(0.35))
		challenge_event("caranguejos")
		sfx.play("elem%d" % col, 1.3)
		burst(wp, G.ELEM[col], 14, 260.0, 0.5)
	elif island.bubble:
		cr.fling(away)
		pop_bubble(wp)
	elif power_left["soco"] > 0.0 or star_on():
		cr.fling(away)
		popup(wp, "Soco!", Color("ffb347"))
		sfx.play("bump", 1.5)
		burst(wp, Color("ffb347"), 12, 260.0, 0.4)
	else:
		cr.stick(cell, dir, G.CRAB_STUCK)
		island.cells[cell]["born"] -= G.CRAB_DRAIN
		popup(wp, "Grudou! -%d s" % int(G.CRAB_DRAIN), Color("ff9e9e"))
		sfx.play("bump", 0.8)
		shake = 5.0
		burst(wp, G.ELEM[cr.elem], 10, 180.0, 0.4)


## A Bolha do siri segura uma batida e estoura.
func pop_bubble(wp: Vector2) -> void:
	special_left = 0.0
	special = ""
	island.bubble = false
	popup(wp, "A bolha protegeu!", Color("bdf2ff"))
	sfx.play("item", 0.7)
	var cen: Vector2 = island.cell_to_world(island.pivot_center())
	var r: float = island.bubble_radius() * G.TILE
	for i in 16:
		burst(cen + Vector2.from_angle(TAU * i / 16.0) * r, Color(0.8, 0.97, 1.0, 0.9), 2, 120.0, 0.5)


func _siri_present() -> bool:
	for cr in crab_root.get_children():
		if cr.kind == "siri" and not cr.is_queued_for_deletion():
			return true
	return false


func _update_siri(delta: float) -> void:
	if not _siri_present():
		siri_t -= delta
		if siri_t <= 0.0:
			siri_t = randf_range(G.SIRI_EVERY[0], G.SIRI_EVERY[1])
			_spawn_siri()
	for cr in crab_root.get_children():
		if cr.kind != "siri" or cr.is_queued_for_deletion():
			continue
		if cr.state == "swim":
			var hit := _edge_hit(cr.position, 0.5 + 0.5)
			if not hit.is_empty():
				_siri_hit(cr, hit["cell"], hit["dir"])
				continue
			var rel: Vector2 = cr.position - _view_world().get_center()
			if cr.t > 6.0 and rel.length() > _view_world().size.length() * 0.85 and cr.vel.dot(rel) > 0.0:
				cr.queue_free()


## O siri passa devagar perto da ilha segurando uma plaquinha com uma cor que a ilha tem na borda.
func _spawn_siri() -> void:
	var cr := Crab.new()
	cr.kind = "siri"
	cr.elem = island.exposed_colors().pick_random()
	var side := randi() % 4
	cr.position = _screen_edge_point(side, randf_range(-0.3, 0.3), G.TILE * 1.5)
	var aim: Vector2 = island.position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (island.radius_cells() + 1.5) * G.TILE
	cr.vel = (aim - cr.position).normalized() * G.SIRI_SPEED
	crab_root.add_child(cr)
	popup(island.position + Vector2(0, -120), "Um siri com presente!", Color("ffd0c8"))


func _siri_hit(cr, cell: Vector2i, dir: Vector2i) -> void:
	var away: Vector2 = (cr.position - island.position).normalized()
	if island.edge_color(cell, dir) == cr.elem:
		cr.set_state("bye")
		cr.vel = away * 120.0
		album_add("amigo_siri")
		if not give_special("bolha", cr.position, "Presente do siri! "):
			score += 300
			popup(cr.position + Vector2(0, -60), "Presente do siri! +300", Color("ffd0c8"))
		burst(cr.position, G.ELEM[cr.elem], 16, 220.0, 0.6)
	else:
		cr.set_state("dive")
		cr.vel = away * 30.0
		popup(cr.position + Vector2(0, -60), "O siri se assustou!", Color("ffd0c8"))
		sfx.play("whoosh", 1.5, -6.0)
		splash(cr.position)


# ---------- missões (Pacote 3) ----------

func _reset_missions() -> void:
	if whale != null and is_instance_valid(whale):
		whale.queue_free()
	whale = null
	whale_t = G.WHALE_FIRST
	star_t = randf_range(G.STAR_EVERY[0], G.STAR_EVERY[1])
	star_pending = false
	challenge = {}
	challenge_t = G.CHALLENGE_FIRST
	last_challenge = ""
	palm_t = G.PALM_FIRST
	shark_t = G.SHARK_FIRST
	shark_wave_on = false
	shark_bit = false
	coco_cd = 0.0
	coco_targets.clear()


func star_on() -> bool:
	return special == "estrela" and special_left > 0.0


func _update_star(delta: float) -> void:
	if star_pending:
		return
	star_t -= delta
	if star_t <= 0.0:
		star_t = randf_range(G.STAR_EVERY[0], G.STAR_EVERY[1])
		star_pending = true


func _update_whale(delta: float) -> void:
	if whale != null and not is_instance_valid(whale):
		whale = null
	if whale == null:
		if world_idx >= G.WHALE_FROM_WORLD and not _event_busy():
			whale_t -= delta
			if whale_t <= 0.0:
				whale_t = randf_range(G.WHALE_EVERY[0], G.WHALE_EVERY[1])
				_spawn_whale()
		return
	if whale.state != "up":
		return
	whale.left -= delta
	for i in whale.spots.size():
		var sp: Dictionary = whale.spots[i]
		if sp["clean"]:
			continue
		var wp: Vector2 = whale.spot_world(i)
		var hit := _edge_hit(wp, 0.85)
		if hit.is_empty():
			continue
		if island.edge_color(hit["cell"], hit["dir"]) == sp["elem"]:
			sp["clean"] = true
			sp["pop"] = 0.5
			var pts: int = G.WHALE_SPOT_POINTS * combo_mult()
			score += pts
			popup(wp, "Limpou! %d/%d" % [whale.cleaned(), whale.spots.size()], G.ELEM[sp["elem"]].lightened(0.35))
			sfx.play("elem%d" % sp["elem"], 1.2)
			burst(wp, G.ELEM[sp["elem"]], 16, 240.0, 0.5)
		elif whale.nudge_cd <= 0.0:
			whale.nudge_cd = 1.5
			popup(wp, "Precisa da borda " + ["verde", "laranja", "azul", "amarela"][sp["elem"]], Color("ffe0d0"))
			sfx.play("bump", 1.4, -8.0)
	if whale.cleaned() == whale.spots.size():
		_whale_reward()
	elif whale.left <= 0.0:
		whale.set_state("dive")
		popup(whale.global_position + Vector2(0, -90), "A baleia mergulhou", Color("cfe8ff"))
		sfx.play("whoosh", 0.6)


## A baleia sobe ao lado da ilha (na mesma altura, porque a ilha anda para os lados).
func _spawn_whale() -> void:
	var w := Whale.new()
	var side := -1.0 if randf() < 0.5 else 1.0
	w.facing = -side  # cabeça virada para a ilha
	w.position = island.position + Vector2(side * (island.radius_cells() + 3.9) * G.TILE, 0)
	w.left = G.WHALE_TIME
	var cols: Array = []
	var exposed: Array = island.exposed_colors()
	for i in 4:
		cols.append(exposed.pick_random())
	w.setup(cols)
	whale_root.add_child(w)
	whale = w
	hud.banner("Missão da baleia!", "Encoste a borda da mesma cor em cada bichinho das costas dela")
	sfx.play("wave", 0.6)
	splash(w.position)


func _whale_reward() -> void:
	whale.set_state("jet")
	var wp: Vector2 = island.cell_to_world(island.tobe.cpos)
	score += 500
	sfx.play("gold", 0.9)
	burst(whale.global_position, Color(0.85, 0.97, 1.0), 30, 320.0, 0.9)
	# prêmio: estrela-do-mar no 5º espaço; se ele estiver ocupado, todas as barras cheias
	if special == "" and give_special("estrela", wp, "A baleia agradece! "):
		pass
	else:
		for id in G.POWERS:
			power_charge[id] = 1.0
		popup(wp + Vector2(0, -60), "Todos os poderes cheios!", Color("cfe8ff"))
	hud.banner("Baleia limpinha!", "+500 e um presente")
	album_add("amigo_baleia")


func _update_challenge(delta: float) -> void:
	if challenge.is_empty():
		challenge_t -= delta
		if challenge_t <= 0.0:
			_new_challenge()
		return
	challenge["t"] += delta
	if challenge["id"] == "tamanho":
		challenge["n"] = island.cells.size()
		_check_challenge()
	elif challenge["t"] > G.CHALLENGE_TIME:
		last_challenge = challenge["id"]
		challenge = {}
		challenge_t = G.CHALLENGE_GAP


func _new_challenge() -> void:
	var opts: Array = G.CHALLENGES.filter(func(c): return c["world"] <= world_idx and c["id"] != last_challenge)
	var c: Dictionary = opts.pick_random()
	challenge = {"id": c["id"], "text": c["text"], "goal": c["goal"], "n": 0, "elem": randi() % 4, "prize": c["prize"], "t": 0.0}
	popup(island.cell_to_world(island.tobe.cpos) + Vector2(0, -90), "Desafio: " + challenge_text(), Color("fff3c4"))
	sfx.play("item", 1.3)


## Avisa o desafio de algo que aconteceu (peixe comido, encaixe, monstro ao mar...).
func challenge_event(id: String, value := 1, elem := -1) -> void:
	if challenge.is_empty() or challenge["id"] != id:
		return
	if id == "cor" and elem != challenge["elem"]:
		return
	if id == "combo":
		challenge["n"] = max(challenge["n"], value)
	else:
		challenge["n"] += value
	_check_challenge()


func _check_challenge() -> void:
	if challenge["n"] < challenge["goal"]:
		return
	var pid := challenge_prize()
	var wp: Vector2 = island.cell_to_world(island.tobe.cpos)
	var pname: String = G.power_info(pid)["name"]
	if G.POWER_INFO.has(pid):
		power_charge[pid] = 1.0
		popup(wp + Vector2(0, -60), pname + " pronto!", G.POWER_INFO[pid]["color"].lightened(0.3))
	elif not give_special(pid, wp, ""):
		score += 300
		popup(wp + Vector2(0, -60), "+300", G.GOLD)
	hud.banner("Desafio cumprido!", "Prêmio: " + pname)
	sfx.play("gold", 1.1)
	burst(wp, G.GOLD, 24, 300.0, 0.7)
	last_challenge = challenge["id"]
	challenge = {}
	challenge_t = G.CHALLENGE_GAP


func challenge_text() -> String:
	if challenge.is_empty():
		return ""
	if challenge["id"] == "cor":
		return challenge["text"] % [challenge["goal"], G.ELEM_PLURAL[challenge["elem"]]]
	return challenge["text"] % challenge["goal"]


## Poder que o desafio dá ("cor" = o poder da cor sorteada).
func challenge_prize() -> String:
	if challenge["prize"] == "cor":
		return G.ELEM_POWER[challenge["elem"]]
	return challenge["prize"]


# ---------- ataques de fora e coleção (Pacote 4) ----------

## Só um evento grande por vez (onda de caranguejos, tubarões, coqueiro ou baleia); o siri não conta.
func _event_busy() -> bool:
	return _crab_wave_active() or _shark_wave_active() or _palm_present() or (whale != null and is_instance_valid(whale))


func _palm_present() -> bool:
	for inc in incoming_root.get_children():
		if inc.cargo == "coqueiro" and not inc.drifting and not inc.is_queued_for_deletion():
			return true
	return false


func _update_palms(delta: float) -> void:
	if world_idx >= G.PALM_FROM_WORLD and not _event_busy():
		palm_t -= delta
		if palm_t <= 0.0:
			palm_t = randf_range(G.PALM_EVERY[0], G.PALM_EVERY[1])
			_spawn_palm()
	var view := _view_world()
	for inc in incoming_root.get_children():
		if inc.cargo != "coqueiro" or inc.drifting or inc.is_queued_for_deletion():
			continue
		var reach: float = (island.radius_cells() + G.PALM_RANGE) * G.TILE
		if inc.position.distance_to(island.position) > reach or not view.has_point(inc.position):
			continue
		inc.shoot_t -= delta
		if inc.shoot_t <= 0.0:
			inc.shoot_t = G.PALM_SHOT
			_palm_shoot(inc)
	for m in island.coco_marks.duplicate():
		m["t"] -= delta
		if m["t"] <= 0.0:
			island.coco_marks.erase(m)
			_coco_land(m)
			if state != "play":
				return


## O coqueiro passa ao lado da ilha (não em cima), devagar.
func _spawn_palm() -> void:
	var W: Dictionary = G.WORLDS[world_idx]
	var pos := _screen_edge_point(randi() % 4, randf_range(-0.25, 0.25), G.TILE * 1.5)
	var dir_in: Vector2 = (island.position - pos).normalized()
	var perp := dir_in.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var aim: Vector2 = island.position + perp * (island.radius_cells() + 2.2) * G.TILE
	var inc := Incoming.new()
	inc.position = pos
	inc.vel = (aim - pos).normalized() * W["speed"] * 0.55
	inc.edges = G.random_edges()
	inc.cargo = "coqueiro"
	inc.kind = "coqueiro"
	incoming_root.add_child(inc)
	hud.banner("Coqueiro atirador!", "Fuja da sombra do coco, ou encaixe o coqueiro na cor certa")
	sfx.play("roar", 1.4)


func _palm_shoot(inc) -> void:
	var target: Vector2i = island.tobe.cell()
	if not island.cells.has(target):
		return
	island.coco_marks.append({"cell": target, "t": G.PALM_WARN, "from": island.to_local(inc.position + Vector2(0, -50))})
	sfx.play("whoosh", 1.8, -6.0)
	_tobe_dodge(target)


## O Tobé sai sozinho da sombra do coco (se tiver para onde ir).
func _tobe_dodge(danger: Vector2i) -> void:
	var marked: Array = island.coco_marks.map(func(m): return m["cell"])
	var opts: Array = []
	for d in G.DIRS:
		var c: Vector2i = danger + d
		if island.cells.has(c) and not island.is_unsafe(c) and not marked.has(c):
			opts.append(c)
	if opts.is_empty():
		return
	var t = island.tobe
	t.has_manual = true
	t.manual = opts.pick_random()
	t.manual_t = 0.8
	t.replan = 0.0


func _coco_land(m: Dictionary) -> void:
	var c: Vector2i = m["cell"]
	if not island.cells.has(c):
		return
	var wp: Vector2 = island.cell_to_world(Vector2(c))
	burst(wp, Color("8a5a2b"), 12, 220.0, 0.5)
	sfx.play("bump", 1.1, -4.0)
	var t = island.tobe
	if (t.cpos - Vector2(c)).length() > 0.6:
		return
	if star_on():
		popup(wp + Vector2(0, -40), "A estrela protegeu!", Color("ffd0a0"))
	elif island.bubble:
		pop_bubble(wp)
	elif t.invuln <= 0.0:
		popup(wp + Vector2(0, -60), "Coco!", Color("e0b080"))
		_hurt()


# Chuva de cocos: o Tobé atira um coco por vez no inimigo mais perto.
func _update_coco_rain(delta: float) -> void:
	if special != "cocos" or special_left <= 0.0:
		return
	coco_cd -= delta
	if coco_cd > 0.0:
		return
	var tg := _coco_target()
	if tg.is_empty():
		coco_cd = 0.15
		return
	coco_cd = G.COCO_EVERY
	coco_targets.append(tg["ref"])
	var c := Coco.new()
	c.from = island.cell_to_world(island.tobe.cpos) + Vector2(0, -30)
	c.aim = func(): return _coco_target_pos(tg)
	c.hit.connect(func(): _coco_hit(tg))
	fx_root.add_child(c)
	sfx.play("whoosh", 2.0, -6.0)


func _coco_target() -> Dictionary:
	var from: Vector2 = island.cell_to_world(island.tobe.cpos)
	var view := _view_world()
	var best := {}
	var bd := 1e9
	for m in island.monsters:
		if coco_targets.has(m):
			continue
		var d := from.distance_to(island.cell_to_world(m.cpos))
		if d < bd:
			bd = d
			best = {"kind": "monster", "ref": m, "last": island.cell_to_world(m.cpos)}
	for cr in crab_root.get_children():
		if cr.is_queued_for_deletion() or coco_targets.has(cr) or not view.has_point(cr.position):
			continue
		var ok: bool = (cr.kind == "caranguejo" and cr.state in ["swim", "stuck"]) or (cr.kind == "tubarao" and cr.state == "swim")
		if not ok:
			continue
		var d: float = from.distance_to(cr.position)
		if d < bd:
			bd = d
			best = {"kind": "bicho", "ref": cr, "last": cr.position}
	return best


func _coco_target_pos(tg: Dictionary) -> Vector2:
	if tg["kind"] == "monster":
		if island.monsters.has(tg["ref"]):
			tg["last"] = island.cell_to_world(tg["ref"].cpos)
	elif is_instance_valid(tg["ref"]):
		tg["last"] = tg["ref"].position
	return tg["last"]


func _coco_hit(tg: Dictionary) -> void:
	coco_targets.erase(tg["ref"])
	var wp := _coco_target_pos(tg)
	burst(wp, Color("8a5a2b"), 10, 200.0, 0.4)
	if tg["kind"] == "monster":
		if island.monsters.has(tg["ref"]):
			_punch(tg["ref"])
		return
	var cr = tg["ref"]
	if not is_instance_valid(cr) or cr.done():
		return
	var away: Vector2 = cr.position - island.position
	if cr.kind == "tubarao":
		cr.flee(away)
	else:
		cr.fling(away)
	popup(wp, "Coco!", Color("e0b080"))
	sfx.play("bump", 1.5)


# Onda de tubarões: barbatanas em fila cruzando de cima para baixo (ou ao contrário);
# a ilha anda para os lados para sair da linha.
func _shark_wave_active() -> bool:
	for cr in crab_root.get_children():
		if cr.kind == "tubarao" and cr.state in ["warn", "swim"] and not cr.is_queued_for_deletion():
			return true
	return false


func _update_sharks(delta: float) -> void:
	if world_idx >= G.SHARK_FROM_WORLD and not _event_busy():
		shark_t -= delta
		if shark_t <= 0.0:
			shark_t = randf_range(G.SHARK_EVERY[0], G.SHARK_EVERY[1])
			_launch_sharks()
	var far := _view_world().size.length()
	for cr in crab_root.get_children():
		if cr.kind != "tubarao" or cr.is_queued_for_deletion():
			continue
		match cr.state:
			"warn":
				if cr.st >= G.SHARK_WARN:
					cr.set_state("swim")
			"swim":
				var hit := _edge_hit(cr.position, 0.75)
				if not hit.is_empty():
					_shark_hit(cr, hit["cell"])
		if cr.state in ["swim", "passed"] and cr.position.distance_to(island.position) > far and cr.vel.dot(cr.position - island.position) > 0.0:
			cr.queue_free()
	if shark_wave_on and not _shark_wave_active():
		shark_wave_on = false
		if not shark_bit:
			score += G.SHARK_DODGE_POINTS
			popup(island.position + Vector2(0, -120), "Desviou dos tubarões! +%d" % G.SHARK_DODGE_POINTS, Color("cfe8ff"))
			challenge_event("tubaroes")


func _launch_sharks() -> void:
	var view := _view_world()
	var down := randf() < 0.5
	var dir := Vector2.DOWN if down else Vector2.UP
	var x: float = island.position.x + randf_range(-1.0, 1.0) * (island.radius_cells() + 0.5) * G.TILE
	var y0: float = view.position.y + 50.0 if down else view.end.y - 50.0
	var n := randi_range(2, 3)
	for k in n:
		var cr := Crab.new()
		cr.kind = "tubarao"
		cr.state = "warn"
		cr.position = Vector2(x, y0) - dir * 130.0 * k
		cr.vel = dir * G.SHARK_SPEED
		if k == 0:
			cr.route = view.size.y + 200.0
		crab_root.add_child(cr)
	shark_wave_on = true
	shark_bit = false
	hud.banner("Tubarões!", "Ande para o lado e saia da linha vermelha")
	sfx.play("roar", 0.7)


func _shark_hit(cr, cell: Vector2i) -> void:
	var wp: Vector2 = island.cell_to_world(Vector2(cell))
	var away := Vector2(signf(cr.position.x - island.position.x), 0.0)
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	if star_on():
		cr.flee(away + cr.vel.normalized() * 0.3)
		popup(wp, "A estrela assustou o tubarão!", Color("ffd0a0"))
		return
	if island.bubble:
		cr.flee(away + cr.vel.normalized() * 0.3)
		pop_bubble(wp)
		return
	cr.set_state("passed")
	if cell == island.tobe.cell() or island.cells.size() <= 1:
		return  # nunca morde a peça do Tobé: passa por baixo
	shark_bit = true
	_bite(cell)


## Tubarão arranca uma peça; o que ficar solto (sem ligação com o Tobé) sai à deriva.
func _bite(cell: Vector2i) -> void:
	var wp: Vector2 = island.cell_to_world(Vector2(cell))
	_remove_cell(cell)
	popup(wp + Vector2(0, -40), "Nhac! -1 peça", Color("ff9e9e"))
	shake = 10.0
	hitstop(0.06)
	sfx.play("bump", 0.6)
	burst(wp, Color(1, 1, 1, 0.9), 18, 260.0, 0.5)
	var info: Dictionary = island.bfs(island.tobe.cell())
	for c in island.cells.keys():
		if not info["dist"].has(c):
			_detach(c)
	island.recompute_pivot()
	island.tobe.path.clear()
	island.tobe.replan = 0.0
	for m in island.monsters:
		m.path.clear()
		m.replan = 0.0


# Álbum: conchas, raros e amigos do mar; cada página completa libera um visual do Tobé.
func _pick_shell() -> String:
	var missing: Array = G.SHELLS.filter(func(k): return album.get(k, 0) == 0)
	if not missing.is_empty() and randf() < 0.6:
		return missing.pick_random()
	return G.SHELLS.pick_random()


func album_add(id: String) -> void:
	var had: int = album.get(id, 0)
	album[id] = had + 1
	if had == 0:
		popup(island.cell_to_world(island.tobe.cpos) + Vector2(0, -130), "Novo no álbum: " + G.ALBUM_NAMES[id], Color("fff3c4"))
		for page in G.ALBUM:
			if page["items"].has(id) and page_done(page):
				hud.banner("Página do álbum completa!", "Novo visual do Tobé: " + G.OUTFITS[page["outfit"]])
				set_outfit(page["outfit"])
	_save()


func page_done(page: Dictionary) -> bool:
	for id in page["items"]:
		if album.get(id, 0) == 0:
			return false
	return true


func album_total() -> Vector2i:
	var have := 0
	var total := 0
	for page in G.ALBUM:
		for id in page["items"]:
			total += 1
			if album.get(id, 0) > 0:
				have += 1
	return Vector2i(have, total)


func outfit_unlocked(id: String) -> bool:
	for page in G.ALBUM:
		if page["outfit"] == id:
			return page_done(page)
	return false


func set_outfit(id: String) -> void:
	outfit = id
	island.outfit = id
	_save()


# ---------- vida no mar ----------

## Se a ilha passar por cima de um cardume, um peixe pula numa peça livre.
func _check_fish() -> void:
	for c in island.cells:
		var wp: Vector2 = island.cell_to_world(Vector2(c))
		var school: Dictionary = sea_life.school_near(wp, G.TILE * 1.3)
		if school.is_empty():
			continue
		school["cd"] = 12.0
		stats["peixes"] += 1
		var target := _free_cell_near(c)
		var j := FishJump.new()
		var roll := randf()
		j.item = "cavalo_marinho" if roll < G.SEAHORSE_CHANCE else ("peixe_raro" if roll < G.SEAHORSE_CHANCE + G.RARE_FISH_CHANCE else "peixe")
		j.from = school["pos"]
		j.cell = target
		j.island = island
		j.landed.connect(_fish_landed)
		fx_root.add_child(j)
		splash(school["pos"])
		sfx.play("whoosh", 1.6, -6.0)
		return


func _free_cell_near(c: Vector2i) -> Vector2i:
	var best := c
	var bd := 1e9
	var tc: Vector2i = island.tobe.cell()
	for k in island.cells:
		if island.items.has(k) or k == tc:
			continue
		var d := (Vector2(k) - Vector2(c)).length()
		if d < bd:
			bd = d
			best = k
	return best


func _fish_landed(cell: Vector2i, item: String) -> void:
	if state != "play" or not island.cells.has(cell):
		return
	var wp: Vector2 = island.cell_to_world(Vector2(cell))
	burst(wp, Color(1, 1, 1, 0.9), 10, 160.0, 0.5)
	if not island.items.has(cell) or item != "peixe":
		island.items[cell] = item
	if island.tobe.cell() == cell:
		_collect(cell)


# ---------- câmera e efeitos ----------

func _update_camera(delta: float, vp: Vector2) -> void:
	cam.position = cam.position.lerp(island.position, 1.0 - exp(-delta * 5.0))
	var r: float = island.radius_cells()
	var need := (2.0 * r + 5.0) * G.TILE
	var z: float = clamp(min(vp.x, vp.y) / need, 0.45, 1.3)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 1.0 - exp(-delta * 2.0))
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	shake = move_toward(shake, 0.0, delta * 30.0)


func hitstop(t: float) -> void:
	Engine.time_scale = 0.08
	get_tree().create_timer(t, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func burst(pos: Vector2, color: Color, amount: int, speed: float, life: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = G.dot_tex
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	fx_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func splash(pos: Vector2) -> void:
	burst(pos, Color(1, 1, 1, 0.9), 18, 260.0, 0.7)
	burst(pos, island.sea_color.lightened(0.4), 12, 160.0, 0.8)


func popup(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.label_settings = G.label_settings(30, color, Color("1d2b4a"), 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 20
	fx_root.add_child(l)
	l.reset_size()
	l.position = pos - l.size * 0.5
	l.scale = Vector2(0.6, 0.6)
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 70.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


# ---------- salvar ----------

func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		best_score = cf.get_value("recorde", "pontos", 0)
		best_size = cf.get_value("recorde", "ilha", 0)
		album = cf.get_value("album", "itens", {})
		outfit = cf.get_value("album", "visual", "")
	island.outfit = outfit


func _save() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		return  # modos de teste não gravam recorde
	var cf := ConfigFile.new()
	cf.set_value("recorde", "pontos", best_score)
	cf.set_value("recorde", "ilha", best_size)
	cf.set_value("album", "itens", album)
	cf.set_value("album", "visual", outfit)
	cf.save("user://save.cfg")
