class_name CerebroIA
extends RefCounted
## Decisão e execução do turno dos deuses (IAs).

var ctrl: ControladorJogo

## Animador de cada deus (null = ainda sem animações)
var animadores: Dictionary = {}

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	animadores = {
		"Anubis": ctrl.anim_anubis,
		"Hefesto": null,
		"Odin": null,
	}

func processar_turno(ia: Jogador) -> void:
	if ia.nome == "Anubis" and ctrl.habilidade.deve_ativar():
		await ctrl.habilidade.ativar()
	if ia.nome == "Odin" and ctrl.poder_odin.deve_ativar():
		await ctrl.poder_odin.ativar()

	await ctrl.get_tree().create_timer(ctrl.tempo_resposta_ia * Configuracoes.mult_velocidade_deuses(), false).timeout

	var topo = ctrl.baralho.obter_topo()
	var index_pra_jogar: int = -1

	# Combo: jogar 2+ cartas de mesmo valor juntas (nunca zera a mão nem deixa só 1 carta)
	var combo: Array[int] = ComboCartas.escolher_para_ia(ia.mao, topo, ctrl.regras.compras_acumuladas, ctrl.cartas_minimas_apos_combo, ctrl.chance_combo_ia if bool(Configuracoes.obter("combos_deuses")) else 0.0)
	if not combo.is_empty():
		await _jogar_combo(ia, combo)
		return

	if ctrl.regras.compras_acumuladas > 0:
		for i in range(ia.mao.size()):
			var c = ia.mao[i]
			if (c.valor == Carta.Valor.MAIS_DOIS or c.valor == Carta.Valor.MAIS_QUATRO) and ia.pode_jogar_carta(c, topo):
				index_pra_jogar = i
				break

		if index_pra_jogar == -1:
			if ia.nome == "Anubis":
				AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, "RECLAMAR")
			ctrl.regras.processar_compra_cartas(ia)
			return
	else:
		for i in range(ia.mao.size()):
			if ia.pode_jogar_carta(ia.mao[i], topo):
				index_pra_jogar = i
				break

	var animador: AnimationPlayer = animadores.get(ia.nome)

	if index_pra_jogar != -1:
		var carta_jogada = ia.remover_carta(index_pra_jogar)
		if carta_jogada.cor == Carta.Cor.PRETA:
			carta_jogada.cor = escolher_melhor_cor(ia)

		# A lógica é aplicada na hora, mas o visual (carta da mesa e mão da IA)
		# só é atualizado depois da animação do deus e do voo da carta.
		ctrl.baralho.descartar(carta_jogada)
		ctrl.regras.processar_efeito_carta(carta_jogada)

		# A carta sai da mão do deus e voa para a pilha enquanto ele anima
		var voo: Dictionary = _iniciar_voo_carta(ia, index_pra_jogar, carta_jogada)

		await AnimUtil.tocar_e_voltar_idle(animador, "JOGAR_CARTA")
		await _aguardar_voo(voo)

		if not voo["mao_atualizada"]:
			ctrl.visual.atualizar_mao_ia(ia)

		if ia.mao.size() == 0:
			ctrl.jogo_ativo = false
			ctrl.verificar_fim_partida(ia)
	else:
		var comprada = ctrl.baralho.puxar()
		if comprada != null:
			Som.sfx("carta_comprar", -3.0, 0.06)
			ia.adicionar_carta(comprada)
			ctrl.visual.atualizar_mao_ia(ia)
			if ia.nome == "Anubis":
				AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, "COMPRAR_CARTA")

# --- Combo da IA ---

func _jogar_combo(ia: Jogador, indices: Array[int]) -> void:
	var cartas: Array[Carta] = []
	for i in indices:
		cartas.append(ia.mao[i])
	var remover: Array[int] = indices.duplicate()
	remover.sort()
	remover.reverse()
	for i in remover:
		ia.remover_carta(i)   # (os visuais só mudam depois do voo)

	# Lógica na hora: a última carta fica no topo da mesa e define a cor
	for k in range(cartas.size()):
		ctrl.baralho.descartar(cartas[k])
		ctrl.regras.processar_efeito_carta(cartas[k], k == cartas.size() - 1)

	var voo: Dictionary = {"espera": null, "voo": null, "mao_atualizada": false, "lancado_tudo": false}
	var tw: Tween = ctrl.create_tween()
	voo["espera"] = tw
	tw.tween_interval(maxf(ctrl.atraso_voo_carta, 0.0))
	tw.tween_callback(func(): _soltar_combo(voo, ia, indices, cartas))

	await AnimUtil.tocar_e_voltar_idle(animadores.get(ia.nome), "JOGAR_CARTA")
	await _aguardar_voo(voo)
	if not voo["mao_atualizada"]:
		ctrl.visual.atualizar_mao_ia(ia)

# Chamada pelo tween: as cartas saem da mão do deus e voam uma depois da outra
func _soltar_combo(voo: Dictionary, ia: Jogador, indices: Array[int], cartas: Array[Carta]) -> void:
	var container = ctrl.visual.maos_ia.get(ia.nome)
	if container == null or not is_instance_valid(container):
		voo["lancado_tudo"] = true
		return
	var origens: Array[Transform3D] = []
	for i in indices:
		var o: Transform3D = (container as Node3D).global_transform
		if container.has_method("obter_carta_visual"):
			var visual = container.obter_carta_visual(i)
			if visual != null:
				o = visual.global_transform
		origens.append(o)
	ctrl.visual.atualizar_mao_ia(ia)   # as cartas saem da mão
	voo["mao_atualizada"] = true
	Som.sfx("carta_combo")
	for k in range(cartas.size()):
		voo["voo"] = ctrl.pilha.jogar(cartas[k], origens[k])
		if k < cartas.size() - 1:
			await ctrl.get_tree().create_timer(ctrl.intervalo_combo, false).timeout
	voo["lancado_tudo"] = true

# --- Voo da carta jogada (mão do deus -> pilha da mesa) ---

## Agenda o voo: após `atraso_voo_carta` a carta sai da mão do deus e vai para a pilha.
func _iniciar_voo_carta(ia: Jogador, indice: int, carta: Carta) -> Dictionary:
	var voo: Dictionary = {"espera": null, "voo": null, "mao_atualizada": false}
	var tw: Tween = ctrl.create_tween()
	voo["espera"] = tw
	tw.tween_interval(maxf(ctrl.atraso_voo_carta, 0.0))
	tw.tween_callback(func(): _soltar_carta(voo, ia, indice, carta))
	return voo

func _soltar_carta(voo: Dictionary, ia: Jogador, indice: int, carta: Carta) -> void:
	var container = ctrl.visual.maos_ia.get(ia.nome)
	if container == null or not is_instance_valid(container):
		return
	# Posição/rotação da carta na mão (antes de a mão ser atualizada)
	var origem: Transform3D = (container as Node3D).global_transform
	if container.has_method("obter_carta_visual"):
		var visual = container.obter_carta_visual(indice)
		if visual != null:
			origem = visual.global_transform
	ctrl.visual.atualizar_mao_ia(ia)   # a carta sai da mão
	voo["mao_atualizada"] = true
	voo["voo"] = ctrl.pilha.jogar(carta, origem)

func _aguardar_voo(voo: Dictionary) -> void:
	var espera: Tween = voo["espera"]
	if espera.is_valid() and espera.is_running():
		await espera.finished
	while not voo.get("lancado_tudo", true):   # combo: espera a última carta sair
		await ctrl.get_tree().process_frame
	var t: Tween = voo["voo"]
	if t != null and t.is_valid() and t.is_running():
		await t.finished

## Escolhe a cor que a IA mais tem na mão.
func escolher_melhor_cor(ia: Jogador) -> Carta.Cor:
	var contagem = {
		Carta.Cor.VERMELHA: 0,
		Carta.Cor.AZUL: 0,
		Carta.Cor.AMARELA: 0,
		Carta.Cor.VERDE: 0
	}
	for c in ia.mao:
		if c.cor != Carta.Cor.PRETA:
			contagem[c.cor] += 1
	var melhor_cor = Carta.Cor.VERMELHA
	var maior_qtd: int = -1
	for cor in contagem.keys():
		if contagem[cor] > maior_qtd:
			maior_qtd = contagem[cor]
			melhor_cor = cor
	return melhor_cor
