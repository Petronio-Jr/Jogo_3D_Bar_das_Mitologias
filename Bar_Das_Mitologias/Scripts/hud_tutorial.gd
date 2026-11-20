class_name HudTutorial
extends CanvasLayer
## Textos pequenos do tutorial, montados por código (não precisa de cena):
##  - painel de INFORMAÇÃO no canto superior direito (comandos, cartas, explicação das habilidades);
## 
##  - linha de STATUS embaixo ("Sua vez!", "Poder ativado!"...);
##  - fade preto (usado ao sair do tutorial).
## Tudo começa escondido: use mostrar(true) quando o tutorial começar.

var _raiz: Control
var _info: PanelContainer
var _info_titulo: Label
var _info_texto: RichTextLabel
var _info_rodape: Label
var _status: Label
var _fade: ColorRect
var _tween_info: Tween

func _ready() -> void:
	layer = 120
	_construir()
	mostrar(false)

func mostrar(ativo: bool) -> void:
	visible = ativo
	if not ativo:
		esconder_info()
		definir_status("")
		_fade.color.a = 0.0

# ------------------------------------------------------------------ Painel de informação

## Troca o texto do painel (com um fade rápido). `texto` aceita BBCode: [b]negrito[/b], [color=gold]cor[/color].
func mostrar_info(titulo: String, texto: String, rodape: String = "") -> void:
	_info_titulo.text = titulo
	_info_texto.text = texto
	_info_rodape.text = rodape
	_info_rodape.visible = rodape != ""
	_info.visible = true
	_info.modulate.a = 0.0
	if _tween_info != null and _tween_info.is_valid():
		_tween_info.kill()
	_tween_info = create_tween()
	_tween_info.tween_property(_info, "modulate:a", 1.0, 0.25)

func esconder_info() -> void:
	if _tween_info != null and _tween_info.is_valid():
		_tween_info.kill()
	_info.visible = false

# ------------------------------------------------------------------ Objetivo e status

func definir_status(texto: String) -> void:
	_status.text = texto

## alvo 1.0 = tela preta, 0.0 = tela livre.
func fade(alvo: float, duracao: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", alvo, maxf(duracao, 0.01))
	await tw.finished

# ------------------------------------------------------------------ Montagem

func _caixa(borda: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.07, 0.82)
	s.border_color = borda
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s

func _ignorar(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	_ignorar(l)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _construir() -> void:
	var dourado := Color(1.0, 0.82, 0.3)

	_raiz = Control.new()
	_ignorar(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	# --- Informação (canto superior direito) ---
	_info = PanelContainer.new()
	_ignorar(_info)
	_info.add_theme_stylebox_override("panel", _caixa(dourado))
	_info.anchor_left = 1.0
	_info.anchor_right = 1.0
	_info.anchor_top = 0.0
	_info.anchor_bottom = 0.0
	_info.offset_left = -20.0 - 290.0
	_info.offset_right = -20.0
	_info.offset_top = 20.0
	_info.grow_vertical = Control.GROW_DIRECTION_END
	_raiz.add_child(_info)
	var v := VBoxContainer.new()
	_ignorar(v)
	v.add_theme_constant_override("separation", 6)
	_info.add_child(v)
	_info_titulo = _rotulo(17, dourado)
	v.add_child(_info_titulo)
	_info_texto = RichTextLabel.new()
	_ignorar(_info_texto)
	_info_texto.bbcode_enabled = true
	_info_texto.fit_content = true
	_info_texto.scroll_active = false
	_info_texto.custom_minimum_size.x = 266
	_info_texto.add_theme_font_size_override("normal_font_size", 15)
	_info_texto.add_theme_font_size_override("bold_font_size", 15)
	v.add_child(_info_texto)
	_info_rodape = _rotulo(14, Color(1, 1, 1, 0.55))
	_info_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_info_rodape)

	# --- Status (embaixo) ---
	_status = _rotulo(20, Color(1, 1, 1, 0.9))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = -400.0
	_status.offset_right = 400.0
	_status.offset_top = -90.0
	_status.offset_bottom = -24.0
	_raiz.add_child(_status)

	# --- Fade ---
	_fade = ColorRect.new()
	_ignorar(_fade)
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(_fade)
