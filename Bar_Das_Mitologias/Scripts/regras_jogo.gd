class_name RegrasJogo
extends RefCounted
## Regras do jogo: efeitos das cartas, sentido, bloqueio e compras acumuladas.

var ctrl: ControladorJogo

var sentido: int = 1
var compras_acumuladas: int = 0
var passos_para_avancar: int = 1

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

func resetar_ronda() -> void:
	compras_acumuladas = 0
	passos_para_avancar = 1

func processar_efeito_carta(carta: Carta, tocar_som: bool = true) -> void:
	# O som do efeito entra um instante depois, quando a carta já está pousando na mesa
	match carta.valor:
		Carta.Valor.INVERTER:
			sentido *= -1
			if tocar_som: Som.sfx("efeito_inverter", 0.0, 0.0, 0.45)
		Carta.Valor.BLOQUEIO:
			passos_para_avancar += 1   # num combo, cada bloqueio pula mais um jogador
			if tocar_som: Som.sfx("efeito_bloqueio", 0.0, 0.0, 0.45)
		Carta.Valor.MAIS_DOIS:
			compras_acumuladas += 2
			if tocar_som: Som.sfx("efeito_mais2", 0.0, 0.0, 0.45)
		Carta.Valor.MAIS_QUATRO:
			compras_acumuladas += 4
			if tocar_som: Som.sfx("efeito_mais4", 0.0, 0.0, 0.45)

## O jogador tem um +2/+4 jogável para rebater a compra acumulada?
func tem_rebate(jogador: Jogador) -> bool:
	var topo = ctrl.baralho.obter_topo()
	for c in jogador.mao:
		if (c.valor == Carta.Valor.MAIS_DOIS or c.valor == Carta.Valor.MAIS_QUATRO) and jogador.pode_jogar_carta(c, topo):
			return true
	return false

## Retorna true se o jogador teve de comprar as cartas acumuladas.
func processar_compra_cartas(jogador: Jogador) -> bool:
	if compras_acumuladas == 0:
		return false
	if tem_rebate(jogador):
		return false

	for i in range(compras_acumuladas):
		var c = ctrl.baralho.puxar()
		if c != null:
			jogador.adicionar_carta(c)

	if not jogador.eh_o_player and jogador.nome == "Anubis":
		AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, "RECLAMAR")

	compras_acumuladas = 0
	Som.sfx("carta_comprar", 0.0, 0.06)

	if jogador.eh_o_player:
		ctrl.visual.atualizar_mao_humano(jogador, 2)
	else:
		ctrl.visual.atualizar_mao_ia(jogador)
	return true

## Compra direta (efeitos de habilidade) e atualiza a mão certa.
func comprar_cartas(jogador: Jogador, quantidade: int) -> void:
	for i in range(quantidade):
		var c = ctrl.baralho.puxar()
		if c != null:
			jogador.adicionar_carta(c)
	Som.sfx("carta_comprar", 0.0, 0.06)
	if jogador.eh_o_player:
		ctrl.visual.atualizar_mao_player()
	else:
		ctrl.visual.atualizar_mao_ia(jogador)
