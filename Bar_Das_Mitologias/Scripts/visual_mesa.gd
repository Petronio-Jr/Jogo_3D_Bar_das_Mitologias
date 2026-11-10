class_name VisualMesa
extends RefCounted
## Tudo que é apresentação: textos da UI, contadores dos deuses,
## mãos 3D e carta do topo da mesa.

var ctrl: ControladorJogo

var label_turno: Label
var label_contador_turnos: Label
var carta_mesa: Node
var contadores_ia: Dictionary = {}
var maos_ia: Dictionary = {}

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	label_turno = ctrl.get_node_or_null("UI/PanelContainer/LabelTurno") as Label
	label_contador_turnos = ctrl.get_node_or_null("UI/LabelContagemTurno") as Label
	carta_mesa = ctrl.get_node_or_null("Cenário/CartaMesa")
	
	label_turno.visible = true
	label_contador_turnos.visible = true

	for nome in ["Anubis", "Hefesto", "Odin"]:
		var base: String = "Cenário/deuses/" + nome.to_lower()
		contadores_ia[nome] = ctrl.get_node_or_null(base + "/ContadorCartas")
		maos_ia[nome] = ctrl.get_node_or_null(base + "/PosicaoMao")

# --- Textos / HUD ---

func mensagem(texto: String) -> void:
	if label_turno:
		label_turno.text = texto

func atualizar_indicador_turno() -> void:
	if label_turno == null:
		return
	var jogador_atual: Jogador = ctrl.jogadores[ctrl.indice_jogador_atual]
	if jogador_atual.eh_o_player:
		label_turno.text = "Sua vez!\n" + ctrl.poder.texto_status()
	else:
		label_turno.text = "Vez de " + jogador_atual.nome
	atualizar_todos_contadores_ia()
	if label_contador_turnos:
		label_contador_turnos.text = "Turno " + str(ctrl.numero_turno_atual)

func atualizar_todos_contadores_ia() -> void:
	for j in ctrl.jogadores:
		if not j.eh_o_player:
			var label = contadores_ia.get(j.nome)
			if label and is_instance_valid(label):
				label.text = str(j.mao.size()) + " Cartas"

# --- Mãos ---

## modo/quantidade são repassados ao container da mão (ex.: 0 = normal, 1 = início, 2 = compra)
func atualizar_mao_humano(jogador: Jogador, modo: int, quantidade: int = -1) -> void:
	var container = ctrl.container_mao_3d
	if container == null or not container.has_method("atualizar_mao"):
		return
	if quantidade < 0:
		container.atualizar_mao(jogador, modo)
	else:
		container.atualizar_mao(jogador, modo, quantidade)

func atualizar_mao_player() -> void:
	ctrl.mira.carta_em_foco = -1
	atualizar_mao_humano(ctrl.jogadores[0], 0)

func atualizar_mao_ia(jogador: Jogador) -> void:
	if jogador == null or jogador.eh_o_player:
		return
	var container = maos_ia.get(jogador.nome)
	if container == null or not is_instance_valid(container):
		return
	if container.has_method("atualizar_mao"):
		container.set("mostrar_frente", ctrl.mostrar_cartas_ia)
		container.atualizar_mao(jogador)
	atualizar_todos_contadores_ia()

func atualizar_maos_ia() -> void:
	for j in ctrl.jogadores:
		atualizar_mao_ia(j)

# --- Carta da mesa ---

func atualizar_carta_mesa() -> void:
	# Só usado para a 1ª carta da ronda; as seguintes entram na pilha ao serem jogadas
	var topo = ctrl.baralho.obter_topo()
	if topo != null:
		ctrl.pilha.colocar_inicial(topo)

func girar_carta_mesa(passos: int = 1) -> void:
	if carta_mesa != null and carta_mesa.has_method("girar_graus"):
		var graus: float = -90.0 * ctrl.regras.sentido * passos
		carta_mesa.girar_graus(graus)
