class_name HabilidadeAnubis
extends RefCounted
## Habilidade especial do Anubis: apaga as luzes, desce a balança e
## decide entre castigo (humano compra) ou sorte (jogador escolhe um deus).

var ctrl: ControladorJogo

var rodadas_desde_checagem: int = 0
var evento_em_andamento: bool = false
var escolhendo_deus: bool = false

var _nomes_deuses: Array[String] = []

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

func resetar_ronda() -> void:
	rodadas_desde_checagem = 0

func registrar_rodada() -> void:
	rodadas_desde_checagem += 1

func deve_ativar() -> bool:
	if ctrl.testar_habilidade:
		return true
	if rodadas_desde_checagem < ctrl.rodadas_para_habilidade:
		return false
	rodadas_desde_checagem = 0
	return randf() < ctrl.chance_habilidade_anubis

func ativar() -> void:
	evento_em_andamento = true
	ctrl.visual.mensagem("Habilidade Ativa")
	Som.pagode_pausar(0.6)      # o pagode some quando as luzes se apagam
	Som.abafar(-10.0, 0.8)
	Som.sfx("luzes_apagar")

	var luz1 = ctrl.get_node_or_null("Cenário/LuzAmbiente3")
	var luz2 = ctrl.get_node_or_null("Cenário/LuzAmbiente5")
	var luz3 = ctrl.get_node_or_null("Cenário/LuzSala1")
	if luz1: luz1.visible = false
	if luz2: luz2.visible = false
	if luz3: luz3.visible = false

	Som.sfx("balanca_descer", 0.0, 0.0, 0.3)
	var descida: Tween = ctrl.balanca.descer()
	await AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, ctrl.animacao_habilidade)
	if descida != null and descida.is_running():
		await descida.finished

	ctrl.visual.mensagem("A balança decide...")
	var castigo: bool = await ctrl.balanca.inclinar()

	Som.sfx("balanca_castigo" if castigo else "balanca_sorte")
	if castigo:
		ctrl.regras.comprar_cartas(ctrl.jogadores[0], ctrl.cartas_jogador_compra)
		ctrl.visual.mensagem("Culpado! Compre %d cartas!" % ctrl.cartas_jogador_compra)
		await ctrl.get_tree().create_timer(1.5, false).timeout
	else:
		await escolher_deus_pela_mira()
		await ctrl.get_tree().create_timer(1.5, false).timeout

	await ctrl.balanca.guardar()
	if luz1: luz1.visible = true
	if luz2: luz2.visible = true
	if luz3: luz3.visible = true   # (antes checava luz2 por engano)
	Som.sfx("luzes_acender")
	Som.soltar(1.5)
	Som.pagode_retomar(2.5)
	evento_em_andamento = false
	ctrl.visual.atualizar_indicador_turno()

func escolher_deus_pela_mira() -> void:
	var deuses_ia: Array[Jogador] = []
	_nomes_deuses.clear()
	for j in ctrl.jogadores:
		if not j.eh_o_player:
			deuses_ia.append(j)
			_nomes_deuses.append(j.nome)

	var nos: Array[Node] = ctrl.get_tree().get_nodes_in_group("deuses")
	for no in nos:
		if no.has_method("set_selecionavel"):
			if not no.is_connected("selecionado", _on_deus_selecionado):
				no.connect("selecionado", _on_deus_selecionado)
			no.set_selecionavel(true, _nomes_deuses.find(String(no.get("nome_jogador"))) + 1)   # nº = tecla do deus

	ctrl.visual.mensagem("Seu coração é puro!\nEscolha um deus para comprar %d cartas!" % ctrl.cartas_deus_compra)

	escolhendo_deus = true
	var nome_escolhido: String = await ctrl.deus_escolhido
	escolhendo_deus = false

	for no in nos:
		if is_instance_valid(no) and no.has_method("set_selecionavel"):
			no.set_selecionavel(false)

	for j in deuses_ia:
		if j.nome == nome_escolhido:
			ctrl.regras.comprar_cartas(j, ctrl.cartas_deus_compra)
			if j.nome == "Anubis":
				AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, "COMPRAR_CARTA")
			ctrl.visual.mensagem("%s compra %d cartas!" % [j.nome, ctrl.cartas_deus_compra])
			break

## Escolha por teclado (teclas 1-9 / teclado numérico) enquanto escolhendo_deus.
func tratar_tecla(event: InputEventKey) -> void:
	var idx: int = -1
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		idx = event.keycode - KEY_1
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		idx = event.keycode - KEY_KP_1
	if idx >= 0 and idx < _nomes_deuses.size():
		ctrl.deus_escolhido.emit(_nomes_deuses[idx])

func _on_deus_selecionado(nome: String) -> void:
	if escolhendo_deus:
		Som.sfx("deus_selecionado")
		ctrl.deus_escolhido.emit(nome)
