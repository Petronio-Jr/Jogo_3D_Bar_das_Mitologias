class_name PoderOdin
extends RefCounted
## Poder do Odin: a cada `rodadas_para_poder_odin` rodadas, na vez dele, ele compara
## o tamanho da sua mão com a do jogador. Se a dele for MAIOR, as mãos são trocadas
## (com animação das cartas voando de uma mão para a outra); senão, ele mantém.

var ctrl: ControladorJogo

var rodadas_desde_checagem: int = 0
var em_andamento: bool = false

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

func resetar_ronda() -> void:
	rodadas_desde_checagem = 0
	em_andamento = false

## Chamado uma vez por rodada completa (junto com a habilidade do Anubis).
func registrar_rodada() -> void:
	rodadas_desde_checagem += 1

## Chamado no início da vez do Odin. Zera o contador quando chega a hora de checar.
func deve_ativar() -> bool:
	if ctrl.testar_poder_odin:
		return true
	if rodadas_desde_checagem < ctrl.rodadas_para_poder_odin:
		return false
	rodadas_desde_checagem = 0
	return true

func _achar_odin() -> Jogador:
	for j in ctrl.jogadores:
		if j.nome == "Odin":
			return j
	return null

func ativar() -> void:
	var odin: Jogador = _achar_odin()
	var humano: Jogador = ctrl.jogadores[0]
	if odin == null or humano == null:
		return

	em_andamento = true
	ctrl.mira.carta_em_foco = -1
	Som.sfx("deus_selecionado")   # som de "Odin está avaliando"
	ctrl.visual.mensagem("Odin compara os baralhos...")
	await ctrl.get_tree().create_timer(1.2, false).timeout

	var tam_odin: int = odin.mao.size()
	var tam_humano: int = humano.mao.size()

	if tam_odin > tam_humano:
		ctrl.visual.mensagem("Odin tem %d cartas contra %d suas.\nOdin troca de baralho com você!" % [tam_odin, tam_humano])
		await ctrl.get_tree().create_timer(0.8, false).timeout
		await _trocar_maos(odin, humano)
	else:
		ctrl.visual.mensagem("Odin tem %d cartas contra %d suas.\nOdin mantém o seu baralho." % [tam_odin, tam_humano])
		await ctrl.get_tree().create_timer(1.5, false).timeout

	em_andamento = false
	ctrl.visual.atualizar_indicador_turno()

# ----------------------------------------------------------------------
# Troca + animação
# ----------------------------------------------------------------------

func _trocar_maos(odin: Jogador, humano: Jogador) -> void:
	var cont_humano: Node3D = ctrl.container_mao_3d as Node3D
	var cont_odin: Node3D = ctrl.visual.maos_ia.get("Odin") as Node3D
	var pode_animar: bool = cont_humano != null and cont_odin != null \
		and is_instance_valid(cont_humano) and is_instance_valid(cont_odin)

	# Dados que as cartas "fantasma" precisam, capturados ANTES da troca
	var fantasmas: Array[Node3D] = []
	var tween: Tween = null
	Som.sfx("poder_ativar")       # as cartas começam a voar
	if pode_animar:
		tween = ctrl.create_tween().set_parallel(true)
		fantasmas.append_array(_lancar_fantasmas(tween, humano, cont_humano, cont_odin, false))  # humano -> Odin
		fantasmas.append_array(_lancar_fantasmas(tween, odin, cont_odin, cont_humano, true))   # Odin -> humano

	# Troca lógica das mãos
	var mao_humano: Array[Carta] = humano.mao
	humano.mao = odin.mao
	odin.mao = mao_humano

	if tween != null:
		await tween.finished
	Som.sfx("poder_fim")          # as mãos pousaram trocadas

	# Reconstrói as mãos já com as cartas novas (aparecem exatamente onde os fantasmas pousaram)
	ctrl.visual.atualizar_mao_player()
	ctrl.visual.atualizar_mao_ia(odin)
	for f in fantasmas:
		if is_instance_valid(f):
			f.queue_free()

	ctrl.visual.mensagem("Baralhos trocados! Você agora tem %d cartas." % humano.mao.size())
	await ctrl.get_tree().create_timer(1.2, false).timeout

## Cria uma carta "fantasma" para cada carta da mão `origem` e a faz voar até o
## slot equivalente na mão `destino`. As cartas reais da mão de origem ficam escondidas.
func _lancar_fantasmas(tween: Tween, dono: Jogador, cont_origem: Node3D, cont_destino: Node3D, vem_do_odin: bool) -> Array[Node3D]:
	var criadas: Array[Node3D] = []
	var total: int = dono.mao.size()
	if total == 0:
		return criadas

	var cena: PackedScene = preload("res://Interagiveis/carta_ui_3d.tscn")
	var odin_mostra_frente: bool = ctrl.mostrar_cartas_ia or bool(cont_odin_revelada())
	var cor_verso: Color = _cor_verso_odin()

	var visuais: Array = cont_origem.get("cartas_visuais")
	var esp: float = float(cont_destino.get("espacamento_x"))
	var sobre: float = float(cont_destino.get("sobreposicao_z"))
	var centro: float = (total - 1) / 2.0

	for i in range(total):
		var carta: Carta = dono.mao[i]

		# Origem: onde a carta está na mão agora
		var origem_t: Transform3D = cont_origem.global_transform
		if visuais != null and i < visuais.size() and is_instance_valid(visuais[i]):
			origem_t = (visuais[i] as Node3D).global_transform
			(visuais[i] as Node3D).visible = false

		# Destino: slot i da outra mão (mesma fórmula do renderizar_mao_3d)
		var destino_t: Transform3D = cont_destino.global_transform * Transform3D(Basis.IDENTITY, Vector3((i - centro) * esp, 0.0, i * sobre))

		var no: Node3D = cena.instantiate()
		ctrl.add_child(no)
		no.call("setup", carta, i)
		no.global_transform = origem_t
		criadas.append(no)

		# Estado inicial de face
		if vem_do_odin:
			_aplicar_cor_verso(no, cor_verso)
			if not odin_mostra_frente and no.has_method("mostrar_verso"):
				no.call("mostrar_verso")

		# Vai virar no meio do caminho?
		var vira_para_frente: bool = vem_do_odin and not odin_mostra_frente
		var vira_para_verso: bool = (not vem_do_odin) and not odin_mostra_frente

		var p0: Vector3 = origem_t.origin
		var q0: Quaternion = origem_t.basis.orthonormalized().get_rotation_quaternion()
		var e0: Vector3 = origem_t.basis.get_scale()
		var p1: Vector3 = destino_t.origin
		var q1: Quaternion = destino_t.basis.orthonormalized().get_rotation_quaternion()
		var e1: Vector3 = destino_t.basis.get_scale()
		var altura: float = ctrl.altura_arco_troca_odin + (0.05 if vem_do_odin else 0.0)
		var atraso: float = i * ctrl.atraso_entre_cartas_troca
		var dur: float = maxf(ctrl.duracao_troca_odin, 0.05)

		tween.tween_method(func(t: float): _mover(no, t, p0, q0, e0, p1, q1, e1, altura), 0.0, 1.0, dur)\
			.set_delay(atraso)
		if vira_para_frente or vira_para_verso:
			tween.tween_callback(func(): _virar(no, vira_para_frente, cor_verso))\
				.set_delay(atraso + dur * 0.4)
	return criadas

func cont_odin_revelada() -> bool:
	var c = ctrl.visual.maos_ia.get("Odin")
	if c != null and is_instance_valid(c):
		return bool(c.get("revelada"))
	return false

func _cor_verso_odin() -> Color:
	var c = ctrl.visual.maos_ia.get("Odin")
	if c != null and is_instance_valid(c):
		var d = c.get("cores_verso_deuses")
		if d is Dictionary and d.has("Odin"):
			return d["Odin"]
	return Color(0.08, 0.243, 0.648, 1.0)

func _aplicar_cor_verso(no: Node3D, cor: Color) -> void:
	var verso = no.get_node_or_null("Mesh/Verso")
	if verso is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor
		(verso as MeshInstance3D).set_surface_override_material(0, mat)

func _virar(no: Node3D, para_frente: bool, cor_verso: Color) -> void:
	if not is_instance_valid(no):
		return
	if not para_frente:
		_aplicar_cor_verso(no, cor_verso)   # vira Odin: verso azul dele
	if no.has_method("virar_frente"):
		no.call("virar_frente", para_frente, true)
	elif not para_frente and no.has_method("mostrar_verso"):
		no.call("mostrar_verso")

## t de 0 a 1: arco suave (sobe no meio do caminho) interpolando posição, rotação e escala.
func _mover(no: Node3D, t: float, p0: Vector3, q0: Quaternion, e0: Vector3, p1: Vector3, q1: Quaternion, e1: Vector3, altura: float) -> void:
	if not is_instance_valid(no):
		return
	var k: float = t * t * (3.0 - 2.0 * t)
	var pos: Vector3 = p0.lerp(p1, k) + Vector3.UP * sin(t * PI) * altura
	var q: Quaternion = q0.slerp(q1, k)
	no.global_transform = Transform3D(Basis(q).scaled(e0.lerp(e1, k)), pos)
