class_name VisualMesa
extends RefCounted
## Tudo que é apresentação: textos da UI, contadores dos deuses,
## mãos 3D e carta do topo da mesa.

var ctrl: ControladorJogo

var label_turno: Label
var label_contador_turnos: Label
var label_habilidade: Label      # status da habilidade (separado do label do turno)
var label_dica: Label            # "Aperte [Q] para levantar"
var carta_mesa: Node
var contadores_ia: Dictionary = {}
var maos_ia: Dictionary = {}

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	label_turno = ctrl.get_node_or_null("UI/PanelContainer/LabelTurno") as Label
	label_contador_turnos = ctrl.get_node_or_null("UI/LabelContagemTurno") as Label
	carta_mesa = ctrl.get_node_or_null("Cenário/CartaMesa")
	label_habilidade = ctrl.label_habilidade if ctrl.label_habilidade != null else ctrl.find_child("LabelHabilidade", true, false) as Label
	label_dica = ctrl.label_dica_levantar if ctrl.label_dica_levantar != null else ctrl.find_child("LabelDicaLevantar", true, false) as Label
	if label_dica == null and label_turno != null:
		label_dica = _criar_dica_levantar()
	
	# Indicador de turno e contagem só aparecem quando o jogo começa (mostrar_hud)
	_definir_hud_visivel(false)

	for nome in ["Anubis", "Hefesto", "Odin"]:
		var base: String = "Cenário/deuses/" + nome.to_lower()
		contadores_ia[nome] = ctrl.get_node_or_null(base + "/ContadorCartas")
		maos_ia[nome] = ctrl.get_node_or_null(base + "/PosicaoMao")

# --- Textos / HUD ---

func mostrar_hud() -> void:
	_definir_hud_visivel(true)

func esconder_hud() -> void:
	_definir_hud_visivel(false)

## Cria o texto pequeno "Aperte [Q] para levantar" logo abaixo do painel do turno.
func _criar_dica_levantar() -> Label:
	var ref: Control = label_turno.get_parent() as Control   # painel que envolve o texto do turno
	var ui: Node = ctrl.get_node_or_null("UI")
	if ref == null or ref == ui:
		ref = label_turno
	var dica := Label.new()
	dica.name = "LabelDicaLevantar"
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.add_theme_font_size_override("font_size", maxi(int(label_turno.get_theme_font_size("font_size") * 0.55), 12))
	dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	dica.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	dica.add_theme_constant_override("outline_size", 4)
	dica.add_theme_font_override("font", label_turno.get_theme_font("font"))
	ref.get_parent().add_child(dica)
	var colocar := func():
		if is_instance_valid(ref) and is_instance_valid(dica):
			dica.position = ref.position + Vector2(0.0, ref.size.y + 4.0)
	colocar.call_deferred()
	ref.resized.connect(colocar)
	return dica

func _definir_hud_visivel(v: bool) -> void:
	if label_turno:
		label_turno.visible = v
		var painel := label_turno.get_parent() as Control   # PanelContainer que envolve o texto
		if painel != null and painel != ctrl.get_node_or_null("UI"):
			painel.visible = v
	if label_habilidade:
		label_habilidade.visible = v
		var painel_h := label_habilidade.get_parent() as Control
		if painel_h != null and painel_h != ctrl.get_node_or_null("UI"):
			painel_h.visible = v
	if label_dica:
		label_dica.visible = v   # só aparece durante o jogo (o HUD some ao levantar e no fim da série)
		if v:
			label_dica.text = "Aperte [%s] para levantar" % OS.get_keycode_string(ctrl.tecla_levantar)
	if label_contador_turnos:
		label_contador_turnos.visible = v

func mensagem(texto: String) -> void:
	if label_turno:
		label_turno.text = texto

## Mensagens do SEU poder (baralho de poder): vão para o label da habilidade, se ele existir.
func mensagem_poder(texto: String) -> void:
	if label_habilidade:
		label_habilidade.text = texto
	else:
		mensagem(texto)

func atualizar_indicador_turno() -> void:
	if label_turno == null:
		return
	var jogador_atual: Jogador = ctrl.jogadores[ctrl.indice_jogador_atual]
	if jogador_atual.eh_o_player:
		# Sem label próprio para a habilidade, o status continua junto com o turno (como era antes)
		label_turno.text = "Sua vez!" if label_habilidade else "Sua vez!\t" + ctrl.poder.texto_status()
	else:
		label_turno.text = "Vez de " + jogador_atual.nome
	if label_habilidade:
		label_habilidade.text = ctrl.poder.texto_status().strip_edges()   # aparece em todos os turnos
	atualizar_todos_contadores_ia()
	if ctrl.uno != null:
		ctrl.uno.atualizar()
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
	if ctrl.acoes_humano != null:
		ctrl.acoes_humano.limpar_selecao()   # a mão foi refeita: some a seleção do combo
	if ctrl.uno != null:
		ctrl.uno.atualizar()
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
	if ctrl.uno != null:
		ctrl.uno.atualizar()
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
