class_name MenuOpcoes
extends CanvasLayer
## Menu de opções montado por código (não precisa de cena): Áudio, Gráficos, Controles e Jogo.
## Tudo vale na hora e é salvo sozinho. ESC ou "Voltar" fecha.
## Uso: MenuOpcoes.abrir(no_qualquer)

signal fechado

static func abrir(pai: Node) -> MenuOpcoes:
	var m := MenuOpcoes.new()
	pai.add_child(m)
	return m

var _abas: TabContainer
var _fechando: bool = false

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	Configuracoes.garantir()

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.7)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP     # bloqueia cliques no menu de trás
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)

	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(860, 580)
	var tema := Theme.new()
	tema.default_font_size = 20
	painel.theme = tema
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Opções"
	titulo.add_theme_font_size_override("font_size", 36)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)

	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_abas)
	_construir_abas()

	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_END
	rodape.add_theme_constant_override("separation", 12)
	coluna.add_child(rodape)
	var b_padrao := _botao("Restaurar padrão")
	b_padrao.pressed.connect(_restaurar)
	rodape.add_child(b_padrao)
	var b_voltar := _botao("Voltar")
	b_voltar.pressed.connect(_fechar)
	rodape.add_child(b_voltar)

	_abas.get_tab_bar().grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar()

func _fechar() -> void:
	if _fechando:
		return
	_fechando = true
	Configuracoes.salvar()
	Som.sfx("ui_click")
	fechado.emit()
	queue_free()

func _restaurar() -> void:
	Som.sfx("ui_click")
	Configuracoes.restaurar()
	var aba: int = _abas.current_tab
	for c in _abas.get_children():
		_abas.remove_child(c)
		c.queue_free()
	_construir_abas()
	_abas.current_tab = aba

# ---------------------------------------------------------------- ABAS

func _construir_abas() -> void:
	# ÁUDIO
	var a := _nova_aba("Áudio")
	_slider(a, "Volume geral", "vol_geral", 0.0, 1.0, 0.05, "pct")
	_slider(a, "Música", "vol_musica", 0.0, 1.0, 0.05, "pct")
	_slider(a, "Pagode de fundo", "vol_pagode", 0.0, 1.0, 0.05, "pct")
	_slider(a, "Efeitos sonoros", "vol_efeitos", 0.0, 1.0, 0.05, "pct", func(): Som.sfx("carta_jogar"))
	_slider(a, "Vozes (Ah Puch)", "vol_vozes", 0.0, 1.0, 0.05, "pct", func(): Som.blip())
	_checkbox(a, "Mudo (desliga todo o som)", "mudo")

	# GRÁFICOS
	var g := _nova_aba("Gráficos")
	_opcao(g, "Modo de tela", "modo_tela", ["Janela", "Tela cheia", "Tela cheia exclusiva"])
	_checkbox(g, "Sincronia vertical (VSync)", "vsync")
	var fps_nomes: Array[String] = []
	for f in Configuracoes.FPS_OPCOES:
		fps_nomes.append("Sem limite" if f == 0 else "%d FPS" % f)
	_opcao(g, "Limite de FPS", "fps_max", fps_nomes)
	_opcao(g, "Suavização de bordas (MSAA)", "msaa", ["Desligada", "2x", "4x", "8x"])
	_slider(g, "Resolução de renderização", "escala_3d", 0.5, 1.0, 0.05, "pct")
	_checkbox(g, "Mostrar FPS na tela", "mostrar_fps")

	# CONTROLES
	var c := _nova_aba("Controles")
	_slider(c, "Sensibilidade do mouse", "sens", 0.2, 3.0, 0.05, "x")
	_checkbox(c, "Inverter eixo vertical do mouse", "inverter_y")
	var dicas := Label.new()
	dicas.text = "WASD: andar     Mouse: olhar     E: interagir (cadeira, porta, Ah Puch)\n" \
		+ "Botão esquerdo: jogar carta / comprar     Botão direito: marcar cartas do combo\n" \
		+ "Teclas 1-3: escolher deus na habilidade     M: liga/desliga música     ESC: soltar o mouse"
	dicas.add_theme_font_size_override("font_size", 17)
	dicas.modulate = Color(1, 1, 1, 0.75)
	dicas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(HSeparator.new())
	c.add_child(dicas)

	# JOGO
	var j := _nova_aba("Jogo")
	_opcao(j, "Velocidade dos deuses", "vel_deuses", ["Lenta", "Normal", "Rápida"])
	_checkbox(j, "Deuses podem jogar combos", "combos_deuses")
	_checkbox(j, "Mostrar as cartas dos deuses (modo treino)", "mostrar_cartas_deuses")

func _nova_aba(nome: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.name = nome
	for lado in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 18)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	m.add_child(v)
	_abas.add_child(m)
	return v

# ---------------------------------------------------------------- CONTROLES DA UI

func _botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(190, 44)
	b.mouse_entered.connect(func(): Som.sfx("ui_hover"))
	return b

func _linha(pai: Container, rotulo: String, controle: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = rotulo
	l.custom_minimum_size.x = 330
	h.add_child(l)
	controle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(controle)
	pai.add_child(h)

func _aplicar(chave: String) -> void:
	if chave.begins_with("vol_") or chave == "mudo":
		Configuracoes.aplicar_audio()
	elif chave in ["modo_tela", "vsync", "fps_max", "msaa", "escala_3d", "mostrar_fps"]:
		Configuracoes.aplicar_graficos()

func _slider(pai: Container, rotulo: String, chave: String, minimo: float, maximo: float, passo: float, formato: String, ao_soltar: Callable = Callable()) -> void:
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.value = float(Configuracoes.obter(chave))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 28
	var v := Label.new()
	v.custom_minimum_size.x = 70
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = _formatar(s.value, formato)
	caixa.add_child(s)
	caixa.add_child(v)
	s.value_changed.connect(func(valor: float):
		v.text = _formatar(valor, formato)
		Configuracoes.definir(chave, valor)
		_aplicar(chave))
	if ao_soltar.is_valid():
		s.drag_ended.connect(func(_mudou: bool): ao_soltar.call())
	_linha(pai, rotulo, caixa)

func _formatar(valor: float, formato: String) -> String:
	if formato == "x":
		return "x%.2f" % valor
	return "%d%%" % int(round(valor * 100.0))

func _checkbox(pai: Container, rotulo: String, chave: String) -> void:
	var c := CheckButton.new()
	c.text = rotulo
	c.button_pressed = bool(Configuracoes.obter(chave))
	c.toggled.connect(func(ligado: bool):
		Som.sfx("ui_click")
		Configuracoes.definir(chave, ligado)
		_aplicar(chave))
	pai.add_child(c)

func _opcao(pai: Container, rotulo: String, chave: String, itens: Array[String]) -> void:
	var o := OptionButton.new()
	for t in itens:
		o.add_item(t)
	o.selected = clampi(int(Configuracoes.obter(chave)), 0, itens.size() - 1)
	o.item_selected.connect(func(i: int):
		Som.sfx("ui_click")
		Configuracoes.definir(chave, i)
		_aplicar(chave))
	_linha(pai, rotulo, o)
