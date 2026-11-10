class_name AcoesHumano
extends RefCounted
## Ações do jogador humano: comprar do baralho e jogar cartas.

var ctrl: ControladorJogo
var ocupado: bool = false   # true enquanto a carta jogada está voando para a mesa

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
		humano.adicionar_carta(nova_carta)
		ctrl.visual.atualizar_mao_humano(humano, 2, 1)
		ctrl.proximo_turno()

## Carta comum clicada (conectada ao sinal carta_clicada da mão).
func on_carta_jogada(indice: int) -> void:
	if not _eh_minha_vez():
		return
	var humano: Jogador = ctrl.jogadores[0]
	var carta: Carta = humano.mao[indice]

	if not _respeita_compra_acumulada(humano, carta):
		return

	# Cartas pretas / +4 / mudar cor passam pelo menu de cores (outro sinal)
	if carta.cor == Carta.Cor.PRETA or carta.valor == Carta.Valor.MAIS_QUATRO or carta.valor == Carta.Valor.MUDAR_COR:
		return

	if humano.pode_jogar_carta(carta, ctrl.baralho.obter_topo()):
		var origem: Transform3D = _origem_carta(indice)
		humano.remover_carta(indice)
		_finalizar_jogada(humano, carta, origem)

## Carta preta jogada com a cor já escolhida no menu.
func on_carta_jogada_com_cor(indice: int, cor_escolhida: Carta.Cor) -> void:
	if not _eh_minha_vez():
		return
	var humano: Jogador = ctrl.jogadores[0]
	var carta: Carta = humano.mao[indice]

	if not _respeita_compra_acumulada(humano, carta):
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
