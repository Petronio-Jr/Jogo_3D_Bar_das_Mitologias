class_name AcoesHumano
extends RefCounted
## Ações do jogador humano: comprar do baralho e jogar cartas.

var ctrl: ControladorJogo
var ocupado: bool = false   # true enquanto a carta jogada está voando para a mesa
var selecionadas: Array[int] = []   # cartas marcadas (botão direito) para jogar em combo

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

func _eh_minha_vez() -> bool:
	return ctrl.jogo_ativo and not ocupado and ctrl.jogadores[ctrl.indice_jogador_atual].eh_o_player

func comprar_carta() -> void:
	if not _eh_minha_vez():
		return

	var humano: Jogador = ctrl.jogadores[ctrl.indice_jogador_atual]

	if ctrl.regras.compras_acumuladas > 0:
		if ctrl.regras.tem_rebate(humano):
			return
		var qtd_a_comprar: int = ctrl.regras.compras_acumuladas
		if ctrl.regras.processar_compra_cartas(humano):
			ctrl.visual.atualizar_mao_humano(humano, 2, qtd_a_comprar)
			ctrl.proximo_turno()
		return

	var nova_carta = ctrl.baralho.puxar()
	if nova_carta != null:
		Som.sfx("carta_comprar", 0.0, 0.06)
		humano.adicionar_carta(nova_carta)
		ctrl.visual.atualizar_mao_humano(humano, 2, 1)
		ctrl.proximo_turno()

# --- Combo (botão direito marca cartas; clique esquerdo joga tudo) ---

func limpar_selecao() -> void:
	selecionadas.clear()

## Botão direito numa carta: marca/desmarca para o combo (só mesmo valor, nada de pretas).
func alternar_selecao(indice: int) -> void:
	if not _eh_minha_vez():
		return
	var humano: Jogador = ctrl.jogadores[0]
	if indice < 0 or indice >= humano.mao.size():
		return
	var carta: Carta = humano.mao[indice]
	var visual = ctrl.container_mao_3d.obter_carta_visual(indice) if ctrl.container_mao_3d.has_method("obter_carta_visual") else null

	if selecionadas.has(indice):
		selecionadas.erase(indice)
		if visual != null:
			visual.definir_selecionada(false)
		Som.sfx("carta_hover", 0.0, 0.1)
		return

	if ComboCartas.eh_preta(carta):
		ctrl.visual.mensagem("Cartas pretas não entram em combo.")
		Som.sfx("carta_invalida")
		return
	if not selecionadas.is_empty() and humano.mao[selecionadas[0]].valor != carta.valor:
		ctrl.visual.mensagem("Combo: só cartas com o mesmo valor.")
		Som.sfx("carta_invalida")
		return
	selecionadas.append(indice)
	if visual != null:
		visual.definir_selecionada(true)
	Som.sfx("carta_hover", 0.0, 0.1)

## Clique esquerdo com cartas marcadas: joga as marcadas + a clicada (a clicada fica no topo).
func _tentar_combo(humano: Jogador, indices: Array[int], clicada: int) -> void:
	var motivo: String = ComboCartas.validar(humano.mao, indices, ctrl.baralho.obter_topo(), ctrl.regras.compras_acumuladas, ctrl.cartas_minimas_apos_combo)
	if motivo != "":
		ctrl.visual.mensagem(motivo)
		Som.sfx("carta_invalida")
		return
	_jogar_combo(humano, ComboCartas.ordenar_com_final(indices, clicada))

func _jogar_combo(humano: Jogador, indices: Array[int]) -> void:
	ocupado = true
	var cartas: Array[Carta] = []
	var origens: Array[Transform3D] = []
	for i in indices:
		cartas.append(humano.mao[i])
		origens.append(_origem_carta(i))   # posições na mão, antes de ela ser refeita

	var remover: Array[int] = indices.duplicate()
	remover.sort()
	remover.reverse()
	for i in remover:
		humano.remover_carta(i)
	selecionadas.clear()
	ctrl.visual.atualizar_mao_player()
	Som.sfx("carta_combo")

	var voo: Tween = null
	for k in range(cartas.size()):
		var ultima: bool = k == cartas.size() - 1
		ctrl.baralho.descartar(cartas[k])
		ctrl.regras.processar_efeito_carta(cartas[k], ultima)
		voo = ctrl.pilha.jogar(cartas[k], origens[k])
		if not ultima:
			await ctrl.get_tree().create_timer(ctrl.intervalo_combo).timeout
	if voo != null and voo.is_valid() and voo.is_running():
		await voo.finished
	ocupado = false
	ctrl.proximo_turno()   # o combo nunca zera a mão, então não há vitória aqui

## Carta comum clicada (conectada ao sinal carta_clicada da mão).
func on_carta_jogada(indice: int) -> void:
	if not _eh_minha_vez():
		return
	var humano: Jogador = ctrl.jogadores[0]
	var carta: Carta = humano.mao[indice]

	# Há cartas marcadas: joga todas juntas (as marcadas + esta)
	if not selecionadas.is_empty():
		var conjunto: Array[int] = selecionadas.duplicate()
		if not conjunto.has(indice):
			conjunto.append(indice)
		if conjunto.size() >= 2:
			_tentar_combo(humano, conjunto, indice)
			return
		selecionadas.clear()   # só ela mesma estava marcada: joga normal

	if not _respeita_compra_acumulada(humano, carta):
		Som.sfx("carta_invalida")
		return

	# Cartas pretas / +4 / mudar cor passam pelo menu de cores (outro sinal)
	if carta.cor == Carta.Cor.PRETA or carta.valor == Carta.Valor.MAIS_QUATRO or carta.valor == Carta.Valor.MUDAR_COR:
		return

	if humano.pode_jogar_carta(carta, ctrl.baralho.obter_topo()):
		var origem: Transform3D = _origem_carta(indice)
		humano.remover_carta(indice)
		_finalizar_jogada(humano, carta, origem)
	else:
		Som.sfx("carta_invalida")   # jogada inválida

## Carta preta jogada com a cor já escolhida no menu.
func on_carta_jogada_com_cor(indice: int, cor_escolhida: Carta.Cor) -> void:
	if not _eh_minha_vez():
		return
	var humano: Jogador = ctrl.jogadores[0]
	var carta: Carta = humano.mao[indice]

	if not _respeita_compra_acumulada(humano, carta):
		Som.sfx("carta_invalida")
		return

	var origem: Transform3D = _origem_carta(indice)
	humano.remover_carta(indice)
	carta.cor = cor_escolhida
	_finalizar_jogada(humano, carta, origem)

# --- Auxiliares ---

## Com compra acumulada ativa, só dá para jogar +2/+4 válido.
func _respeita_compra_acumulada(humano: Jogador, carta: Carta) -> bool:
	if ctrl.regras.compras_acumuladas == 0:
		return true
	if carta.valor != Carta.Valor.MAIS_DOIS and carta.valor != Carta.Valor.MAIS_QUATRO:
		return false
	return humano.pode_jogar_carta(carta, ctrl.baralho.obter_topo())

## Posição/rotação (global) da carta na mão, de onde ela vai sair voando.
func _origem_carta(indice: int) -> Transform3D:
	var mao = ctrl.container_mao_3d
	if mao != null and mao.has_method("obter_carta_visual"):
		var visual = mao.obter_carta_visual(indice)
		if visual != null:
			return visual.global_transform
	return (mao as Node3D).global_transform

func _finalizar_jogada(humano: Jogador, carta: Carta, origem: Transform3D) -> void:
	ocupado = true
	ctrl.baralho.descartar(carta)
	ctrl.regras.processar_efeito_carta(carta)

	# A carta sai da mão e voa para a pilha; o turno só passa quando ela pousa
	ctrl.visual.atualizar_mao_player()
	var voo: Tween = ctrl.pilha.jogar(carta, origem)
	if voo != null and voo.is_valid() and voo.is_running():
		await voo.finished
	ocupado = false

	if humano.mao.size() == 0:
		ctrl.jogo_ativo = false
		ctrl.verificar_fim_partida(humano)
		return
	ctrl.proximo_turno()
