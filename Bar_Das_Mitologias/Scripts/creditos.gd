extends Area3D
## CRÉDITOS: quando o personagem entra nesta área, a tela escurece, o texto sobe até sumir
## e o jogo volta ao MENU PRINCIPAL (a cena é recarregada).
##
## MONTAGEM: um Area3D com um CollisionShape3D e este script, no ponto do mapa que encerra o jogo.
## O personagem precisa ser um CharacterBody3D. Edite o texto em `texto_creditos` (Inspector).
##
## Formato do texto (BBCode simples):
##   "# Título"  -> linha grande e dourada (seção)
##   linha vazia -> espaço
##   outras linhas -> texto normal; dá para usar [b]negrito[/b] e [color=gold]cor[/color]
## Segurar ESPAÇO, ENTER ou o clique esquerdo acelera a rolagem.

signal creditos_iniciaram
signal creditos_terminaram

@export_multiline var texto_creditos: String = \
	"# UNO vs Três Deuses\n\n\n" \
	+ "# Desenvolvimento\nSeu Nome\n\n\n" \
	+ "# Arte e Animações\nSeu Nome\n\n\n" \
	+ "# Música e Sons\nSeu Nome\n\n\n" \
	+ "# Agradecimentos\nA todos que jogaram\n\n\n" \
	+ "Obrigado por jogar!"
@export var velocidade: float = 70.0            # pixels por segundo
@export var multiplicador_acelerar: float = 4.0 # segurando ESPAÇO/ENTER/clique
@export var tamanho_texto: int = 28
@export var tamanho_titulo: int = 44
@export var cor_titulo: Color = Color(1.0, 0.82, 0.3)
@export var largura_fracao: float = 0.6         # largura do bloco de texto (fração da tela)
@export var duracao_fade: float = 1.0
@export var pausa_no_fim: float = 1.5           # tempo de tela preta depois que o texto sumiu
@export var musica: String = "musica_creditos"  # arquivo em res://audio/musica/ (sem extensão; .ogg/.mp3/.wav); vazio = sem música

var _rodando: bool = false
var _camada: CanvasLayer
var _fundo: ColorRect
var _texto: RichTextLabel

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _rodando or not (body is CharacterBody3D):
		return
	for c in get_tree().get_nodes_in_group("controlador_jogo"):
		if bool(c.get("jogo_ativo")):
			return   # não corta uma partida em andamento
	for c in get_tree().get_nodes_in_group("controlador_tutorial"):
		if bool(c.get("em_andamento")):
			return
	_iniciar(body)

func _iniciar(jogador: Node3D) -> void:
	_rodando = true
	add_to_group("creditos_rolando")   # o menu de pausa não abre durante os créditos
	creditos_iniciaram.emit()
	jogador.process_mode = Node.PROCESS_MODE_DISABLED   # personagem parado
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_camada = CanvasLayer.new()
	_camada.layer = 200
	get_tree().root.add_child(_camada)
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(_fundo)

	var tw: Tween = create_tween()
	tw.tween_property(_fundo, "color:a", 1.0, duracao_fade)
	# Silencia o pagode de fundo e o rádio; entra a música dos créditos
	Som.pagode_pausar(1.0)
	for radio in get_tree().get_nodes_in_group("radios"):
		if radio.has_method("desligar"):
			radio.desligar()
	if musica != "":
		Som.musica(musica, 1.5)
	await tw.finished
	await _rolar()

	Som.musica_parar(pausa_no_fim)   # a música some junto com a tela preta final
	await get_tree().create_timer(pausa_no_fim).timeout
	creditos_terminaram.emit()
	_camada.queue_free()
	remove_from_group("creditos_rolando")
	get_tree().paused = false
	get_tree().reload_current_scene()   # volta ao menu principal (ele fica dentro da cena do jogo)

## Monta o texto abaixo da tela e sobe até sair por cima.
func _rolar() -> void:
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_size_override("normal_font_size", tamanho_texto)
	_texto.add_theme_font_size_override("bold_font_size", tamanho_texto)
	_texto.text = _converter(texto_creditos)
	var tela: Vector2 = _fundo.get_viewport_rect().size
	_texto.size = Vector2(tela.x * largura_fracao, 10.0)
	_texto.position = Vector2((tela.x - _texto.size.x) / 2.0, tela.y)
	_fundo.add_child(_texto)
	await get_tree().process_frame   # deixa o RichTextLabel calcular a altura
	await get_tree().process_frame

	while is_instance_valid(_texto) and _texto.position.y + _texto.size.y > 0.0:
		var v: float = velocidade
		if _acelerando():
			v *= multiplicador_acelerar
		_texto.position.y -= v * get_process_delta_time()
		await get_tree().process_frame

func _acelerando() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

## "# Título" vira linha grande e dourada; o resto fica centralizado.
func _converter(bruto: String) -> String:
	var saida: String = "[center]"
	for linha in bruto.split("\n"):
		if linha.begins_with("# "):
			saida += "[font_size=%d][color=#%s][b]%s[/b][/color][/font_size]\n" % [tamanho_titulo, cor_titulo.to_html(false), linha.substr(2)]
		else:
			saida += linha + "\n"
	return saida + "[/center]"
