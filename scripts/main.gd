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

var state := "menu"
var world: Node2D
var island: Node2D
var incoming_root: Node2D
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
var repair_fx_t := 0.0
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
	incoming_root = Node2D.new()
	world.add_child(incoming_root)
	island = Island.new()
	world.add_child(island)
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
	if state != "play":
		return
	get_tree().paused = not get_tree().paused
	hud.set_paused(get_tree().paused)


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
		var tips := ["", "Correntes empurram as ilhas que chegam. Escolha bem nas ondas!",
			"Monstros mais fortes. Use a cor do ponto fraco!", "Tempestade! Tudo junto e mais rápido."]
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
		if island.age(c) >= G.PIECE_LIFE:
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
	if cargo == "":
		if game_time > 15.0 and randf() < 0.04:
			inc.wild = true
			cargo = "item"
		elif game_time > 25.0 and roll < W["monster"]:
			cargo = "monster"
		elif roll < W["monster"] + W["item"]:
			cargo = "item"
	if cargo == "monster":
		inc.cargo = "monster"
		inc.kind = W["monsters"].pick_random()
		inc.weak = randi() % 4
	elif cargo == "item":
		inc.cargo = "item"
		if inc.wild:
			inc.kind = "tesouro"
		elif randf() < 0.4:
			inc.kind = G.POWERS.pick_random()  # orbe de poder
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
	island.add_cell(slot, elem, edges)
	combo += 1
	best_combo = max(best_combo, combo)
	for id in G.POWERS:
		if power_left[id] <= 0.0:
			power_charge[id] = min(1.0, power_charge[id] + G.POWER_PER_ATTACH)
	var mult := combo_mult()
	var pts := 100 * mult + (300 if inc.wild else 0)
	score += pts
	var wp: Vector2 = island.cell_to_world(Vector2(slot))
	popup(wp, ("+%d" % pts) + (("  ×%d" % mult) if mult > 1 else ""), G.GOLD if inc.wild else G.ELEM[elem].lightened(0.35))
	sfx.play("gold" if inc.wild else "elem%d" % elem, pow(2.0, min(combo - 1, 12) / 12.0))
	burst(wp, G.GOLD if inc.wild else G.ELEM[elem], 22, 300.0, 0.7)
	hitstop(0.04)
	if inc.cargo == "item" and not inc.wild:
		island.items[slot] = inc.kind
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


func _update_powers(delta: float) -> void:
	for id in G.POWERS:
		power_left[id] = max(0.0, power_left[id] - delta)
	island.powers_on = {"ima": power_left["ima"] > 0.0, "soco": power_left["soco"] > 0.0,
		"conserto": power_left["conserto"] > 0.0}


func _punch(m) -> void:
	var wp: Vector2 = island.cell_to_world(m.cpos)
	burst(wp, Color("ffb347"), 20, 360.0, 0.5)
	popup(wp + Vector2(0, -30), "Soco!", Color("ffb347"))
	sfx.play("bump", 1.5)
	shake = 9.0
	hitstop(0.05)
	_monster_overboard(m, 2)


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


func _fish_landed(cell: Vector2i) -> void:
	if state != "play" or not island.cells.has(cell):
		return
	var wp: Vector2 = island.cell_to_world(Vector2(cell))
	burst(wp, Color(1, 1, 1, 0.9), 10, 160.0, 0.5)
	if not island.items.has(cell):
		island.items[cell] = "peixe"
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


func _save() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		return  # modos de teste não gravam recorde
	var cf := ConfigFile.new()
	cf.set_value("recorde", "pontos", best_score)
	cf.set_value("recorde", "ilha", best_size)
	cf.save("user://save.cfg")
