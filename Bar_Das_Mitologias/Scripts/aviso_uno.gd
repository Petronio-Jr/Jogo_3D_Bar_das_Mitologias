class_name AvisoUno
extends RefCounted
## Escrita "UNO!" em 3D acima de onde as cartas ficam na mesa.
## Aparece sempre que alguém (você ou um deus) está com exatamente 1 carta na mão
## e some quando isso deixa de ser verdade. Chame `atualizar()` quando uma mão mudar.

var ctrl: ControladorJogo

var _raiz: Node3D
var _titulo: Label3D
var _sub: Label3D
var _chave: String = ""
var _tween: Tween

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	_raiz = Node3D.new()
	_raiz.visible = false
	ctrl.add_child(_raiz)

	_titulo = _novo_label("UNO!", 150, Color(1.0, 0.88, 0.1))
	_sub = _novo_label("\n", 52, Color(1, 1, 1))
	_sub.position = Vector3(0.0, -0.19, 0.0)
	_raiz.add_child(_titulo)
	_raiz.add_child(_sub)

func _novo_label(texto: String, tamanho: int, cor: Color) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tamanho
	l.pixel_size = 0.0015
	l.modulate = cor
	l.outline_size = 28
	l.outline_modulate = Color(0.1, 0.0, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # sempre de frente para a câmera
	l.no_depth_test = true                           # não some atrás de cartas/mesa
	l.double_sided = true
	return l

## Reavalia as mãos: mostra o UNO se alguém tem exatamente 1 carta.
func atualizar() -> void:
	var nomes: Array[String] = []
	for j in ctrl.jogadores:
		if j.mao.size() == 1:
			nomes.append("Você" if j.eh_o_player else j.nome)
	var chave: String = ", ".join(nomes)
	if chave == _chave:
		return
	var tinha: bool = _chave != ""
	_chave = chave
	if nomes.is_empty():
		_esconder()
	else:
		_mostrar(chave, not tinha)

func limpar() -> void:
	_chave = ""
	_esconder()

func _mostrar(texto_sub: String, tocar_som: bool) -> void:
	if ctrl.pilha == null or not ctrl.pilha.esta_pronta():
		return
	_raiz.global_position = ctrl.pilha.posicao_centro() + Vector3.UP * ctrl.altura_aviso_uno
	_sub.text = texto_sub
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var alvo: Vector3 = Vector3.ONE * ctrl.tamanho_aviso_uno
	_raiz.visible = true
	_raiz.scale = Vector3.ZERO
	_tween = ctrl.create_tween()
	_tween.tween_property(_raiz, "scale", alvo, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_pulsar)
	if tocar_som:
		Som.sfx("aviso_uno", -2.0)

# Fica "respirando" enquanto o UNO está na tela
func _pulsar() -> void:
	var base: Vector3 = Vector3.ONE * ctrl.tamanho_aviso_uno
	_tween = ctrl.create_tween().set_loops()
	_tween.tween_property(_raiz, "scale", base * 1.12, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_raiz, "scale", base, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _esconder() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not _raiz.visible:
		return
	_tween = ctrl.create_tween()
	_tween.tween_property(_raiz, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _raiz.visible = false)
