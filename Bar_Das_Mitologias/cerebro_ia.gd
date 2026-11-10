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

	await ctrl.get_tree().create_timer(ctrl.tempo_resposta_ia).timeout

	var topo = ctrl.baralho.obter_topo()
	var index_pra_jogar: int = -1

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
			ia.adicionar_carta(comprada)
			ctrl.visual.atualizar_mao_ia(ia)
			if ia.nome == "Anubis":
				AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, "COMPRAR_CARTA")

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
