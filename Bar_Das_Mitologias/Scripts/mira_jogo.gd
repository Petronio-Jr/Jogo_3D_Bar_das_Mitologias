class_name MiraJogo
extends RefCounted
## Mira central: localiza o dot, detecta o que está sob a mira,
## controla o destaque (hover) e a interação por clique.

enum Alvo { NADA, CARTA, BARALHO, OBJETO, PODER }

const TAMANHO_MAX_DOT: float = 16.0

var ctrl: ControladorJogo

var carta_em_foco: int = -1
var baralho_em_foco: bool = false
var objeto_em_foco: Node = null
var poder_em_foco: bool = false

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

# --- Dot da mira ---

func localizar_dot() -> void:
	if ctrl.dot_mira == null:
		await ctrl.get_tree().process_frame
		var ui := ctrl.get_node_or_null("UI")
		if ui != null:
			ctrl.dot_mira = _procurar_dot(ui)
	if ctrl.dot_mira != null:
		print("[Mira] Dot usado: ", ctrl.dot_mira.get_path())
	elif ctrl.criar_dot_se_nao_achar:
		ctrl.dot_mira = _criar_dot_proprio()

func _procurar_dot(raiz: Node) -> CanvasItem:
	var centro: Vector2 = ctrl.get_viewport().get_visible_rect().size / 2.0
	var melhor: CanvasItem = null
	var menor_dist: float = INF
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for filho in no.get_children():
			pilha.append(filho)
		if no == raiz or not (no is Control):
			continue
		var c: Control = no as Control
		if not c.is_visible_in_tree() or c.size.x <= 0.0 or c.size.y <= 0.0 or c.size.x > TAMANHO_MAX_DOT or c.size.y > TAMANHO_MAX_DOT:
			continue
		var dist: float = (c.get_global_transform_with_canvas() * (c.size / 2.0)).distance_to(centro)
		if dist < menor_dist:
			menor_dist = dist
			melhor = c
	return melhor

func _criar_dot_proprio() -> Control:
	var camada := CanvasLayer.new()
	camada.layer = 100
	ctrl.add_child(camada)
	var ponto := ColorRect.new()
	ponto.color = Color.WHITE
	ponto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(ponto)
	ponto.set_anchors_preset(Control.PRESET_CENTER)
	ponto.offset_left = -1.5; ponto.offset_top = -1.5; ponto.offset_right = 1.5; ponto.offset_bottom = 1.5
	return ponto

func obter_ponto_mira() -> Vector2:
	var dot := ctrl.dot_mira
	if dot != null and is_instance_valid(dot):
		var deslocamento := Vector2.ZERO
		if dot is Control:
			deslocamento = (dot as Control).size / 2.0
		return dot.get_global_transform_with_canvas() * deslocamento
	return ctrl.get_viewport().get_visible_rect().size / 2.0

# --- Detecção do alvo ---

func detectar_alvo(incluir_jogo: bool = true) -> Dictionary:
	var resultado: Dictionary = {"tipo": Alvo.NADA, "indice": -1, "no": null}
	var camera := ctrl.get_viewport().get_camera_3d()
	if camera == null:
		return resultado

	var ponto: Vector2 = obter_ponto_mira()
	var origem: Vector3 = camera.project_ray_origin(ponto)
	var direcao: Vector3 = camera.project_ray_normal(ponto)
	var melhor: float = ctrl.alcance_mira
	var escolhendo_deus: bool = ctrl.habilidade.escolhendo_deus

	if incluir_jogo and not escolhendo_deus:
		var mao = ctrl.container_mao_3d
		if mao != null and mao.has_method("testar_raio"):
			var r: Dictionary = mao.testar_raio(origem, direcao)
			if r["indice"] != -1 and r["dist"] < melhor:
				melhor = r["dist"]
				resultado = {"tipo": Alvo.CARTA, "indice": r["indice"], "no": null}

		var baralho_3d: Node3D = ctrl.baralho_visual
		if baralho_3d != null and baralho_3d.has_method("distancia_do_raio"):
			var d: float = baralho_3d.distancia_do_raio(origem, direcao)
			if d < melhor:
				melhor = d
				resultado = {"tipo": Alvo.BARALHO, "indice": -1, "no": null}

		var dp: float = ctrl.poder.distancia_do_raio(origem, direcao)
		if dp < melhor:
			melhor = dp
			resultado = {"tipo": Alvo.PODER, "indice": -1, "no": null}

	var grupo: String = "deuses_selecionaveis" if escolhendo_deus else "interativos_mira"
	for no in ctrl.get_tree().get_nodes_in_group(grupo):
		if is_instance_valid(no) and no.has_method("distancia_do_raio"):
			var dist: float = no.distancia_do_raio(origem, direcao)
			if dist < melhor:
				melhor = dist
				resultado = {"tipo": Alvo.OBJETO, "indice": -1, "no": no}
	return resultado

# --- Foco (hover) — chamado todo frame pelo _process do controlador ---

func atualizar_foco() -> void:
	var alvo: Dictionary = detectar_alvo(ctrl.vez_do_jogador())
	var novo_foco_carta: int = alvo["indice"] if alvo["tipo"] == Alvo.CARTA else -1
	var novo_foco_baralho: bool = alvo["tipo"] == Alvo.BARALHO
	var novo_objeto: Node = alvo["no"] if alvo["tipo"] == Alvo.OBJETO else null
	var novo_foco_poder: bool = alvo["tipo"] == Alvo.PODER

	if novo_foco_carta != carta_em_foco:
		carta_em_foco = novo_foco_carta
		if carta_em_foco != -1:
			Som.sfx("carta_hover", -4.0, 0.1)
		var mao = ctrl.container_mao_3d
		if mao and mao.has_method("definir_foco"):
			mao.definir_foco(carta_em_foco)
	if novo_foco_baralho != baralho_em_foco:
		baralho_em_foco = novo_foco_baralho
		if baralho_em_foco:
			Som.sfx("carta_hover", -4.0, 0.1)
		var baralho_3d: Node3D = ctrl.baralho_visual
		if baralho_3d and baralho_3d.has_method("definir_hover"):
			baralho_3d.definir_hover(baralho_em_foco)
		if not baralho_3d.has_method("pulsar"):
			EfeitoInchar.hover(baralho_3d, baralho_em_foco)
	if novo_foco_poder != poder_em_foco:
		poder_em_foco = novo_foco_poder
		ctrl.poder.definir_hover(poder_em_foco)
	if novo_objeto != objeto_em_foco:
		if is_instance_valid(objeto_em_foco) and objeto_em_foco.has_method("definir_hover"):
			objeto_em_foco.definir_hover(false)
		if is_instance_valid(objeto_em_foco) and objeto_em_foco.is_in_group("interativos_mira"):
			EfeitoInchar.hover(objeto_em_foco, false)
		objeto_em_foco = novo_objeto
		if objeto_em_foco != null and objeto_em_foco.has_method("definir_hover"):
			objeto_em_foco.definir_hover(true)
		if objeto_em_foco != null and objeto_em_foco.is_in_group("interativos_mira"):
			EfeitoInchar.hover(objeto_em_foco, true)

# --- Clique ---

func interagir(minha_vez: bool = true) -> void:
	if ctrl.embriaguez.apagado:
		return   # de olhos fechados não dá para interagir
	var alvo: Dictionary = detectar_alvo(minha_vez)
	match alvo["tipo"]:
		Alvo.BARALHO:
			if ctrl.baralho_visual != null and ctrl.baralho_visual.has_method("pulsar"):
				ctrl.baralho_visual.pulsar()
			else:
				EfeitoInchar.pulsar(ctrl.baralho_visual)
			ctrl.acoes_humano.comprar_carta()
		Alvo.CARTA:
			var mao = ctrl.container_mao_3d
			var carta_node = mao.obter_carta_visual(alvo["indice"]) if mao.has_method("obter_carta_visual") else mao.get_child(alvo["indice"])
			if carta_node and carta_node.has_method("interagir_por_mira"):
				carta_node.interagir_por_mira()
		Alvo.PODER:
			ctrl.poder.ativar()
		Alvo.OBJETO:
			var objeto = alvo["no"]
			if objeto and objeto.has_method("interagir_por_mira"):
				objeto.interagir_por_mira()
			if is_instance_valid(objeto) and objeto.is_in_group("interativos_mira"):
				EfeitoInchar.pulsar(objeto)
				if ctrl.embriaguez.eh_cerveja(objeto):
					ctrl.embriaguez.beber()
