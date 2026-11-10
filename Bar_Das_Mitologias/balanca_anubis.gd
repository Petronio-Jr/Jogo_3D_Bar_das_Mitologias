class_name BalancaAnubis
extends RefCounted
## Balança que desce, inclina (castigo/sorte) e é guardada na habilidade do Anubis.

var ctrl: ControladorJogo

var balanca: Node3D
var anim_player: AnimationPlayer

var _pos_mesa: Vector3 = Vector3.ZERO
var _pos_mesa_definida: bool = false
var _player_atual: AnimationPlayer = null
var _anim_inclinada: String = ""

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

## Chamar no _ready: localiza a balança e a deixa escondida.
func preparar() -> void:
	localizar()
	if balanca != null:
		balanca.visible = false

func localizar() -> void:
	if balanca == null:
		balanca = ctrl.get_node_or_null("Cenário/BalancaAnubis") as Node3D
	if balanca == null:
		balanca = ctrl.find_child("*alan*", true, false) as Node3D
	if balanca != null and not _pos_mesa_definida:
		_pos_mesa = balanca.global_position
		_pos_mesa_definida = true

func descer() -> Tween:
	localizar()
	if balanca == null:
		return null
	balanca.global_position = _pos_mesa + Vector3.UP * ctrl.altura_queda_balanca
	balanca.visible = true
	var t: Tween = ctrl.create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(balanca, "global_position", _pos_mesa, ctrl.duracao_descida_balanca)
	return t

## Retorna true se a balança decidiu "castigo".
func inclinar() -> bool:
	var castigo: bool = randf() < ctrl.chance_balanca_castigo
	var nome_anim: String = ctrl.anim_balanca_castigo if castigo else ctrl.anim_balanca_sorte
	await ctrl.get_tree().create_timer(0.6).timeout
	var player: AnimationPlayer = _player_com_animacao(nome_anim)
	if player == null:
		return castigo
	_player_atual = player
	_anim_inclinada = AnimUtil.resolver(player, nome_anim)
	await AnimUtil.tocar(ctrl.get_tree(), player, _anim_inclinada)
	return castigo

func guardar() -> void:
	if balanca == null:
		return
	if _player_atual != null and _anim_inclinada != "":
		await AnimUtil.tocar(ctrl.get_tree(), _player_atual, _anim_inclinada, true)
	var t: Tween = ctrl.create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN)
	t.tween_property(balanca, "global_position", _pos_mesa + Vector3.UP * ctrl.altura_queda_balanca, ctrl.duracao_descida_balanca)
	await t.finished
	balanca.visible = false
	_anim_inclinada = ""
	_player_atual = null

func _player_com_animacao(nome: String) -> AnimationPlayer:
	if balanca == null:
		return null
	var candidatos: Array = []
	if anim_player != null:
		candidatos.append(anim_player)
	for p in balanca.find_children("*", "AnimationPlayer", true, false):
		if not candidatos.has(p):
			candidatos.append(p)
	for p in candidatos:
		if AnimUtil.resolver(p, nome) != "":
			return p
	return null
