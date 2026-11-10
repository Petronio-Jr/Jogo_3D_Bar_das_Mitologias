class_name Embriaguez
extends RefCounted
## Cerveja da mesa: cada clique é uma dose, contada desde o início do jogo
## (não precisa ser em sequência). Quanto mais o jogador bebe, mais forte e longa a tontura da câmera. Ao chegar em
## `limite_bebidas` (10), as pálpebras fecham aos poucos e a tela fica preta.

var ctrl: ControladorJogo

var cerveja: Node3D
var doses: int = 0
var apagado: bool = false    # true = olho fechando/fechado (sem interação)

var _id: int = 0
var _camada: CanvasLayer
var _palpebra_cima: ColorRect
var _palpebra_baixo: ColorRect

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	cerveja = ctrl.cerveja

func eh_cerveja(no: Node) -> bool:
	if no == null:
		return false
	if cerveja != null and is_instance_valid(cerveja) and (no == cerveja or cerveja.is_ancestor_of(no)):
		return true
	var nome: String = String(no.name).to_lower()
	return nome.contains("cerveja") or nome.contains("beer")

func resetar() -> void:
	_id += 1
	doses = 0
	apagado = false
	Som.tontura_fim()
	_abrir_instantaneo()

## Uma dose de cerveja.
func beber() -> void:
	if apagado:
		return
	doses += 1
	_id += 1
	var id: int = _id
	Som.sfx("cerveja_gole", 0.0, 0.05)

	var forca: float = ctrl.forca_tontura_base + (doses - 1) * ctrl.aumento_forca_por_dose
	var duracao: float = ctrl.duracao_tontura_base + doses * ctrl.duracao_extra_por_dose
	var cam: Node = ctrl.camera_jogador
	if cam != null and cam.has_method("ficar_tonto"):
		cam.ficar_tonto(duracao, forca)
	Som.tontura(duracao, forca)   # a música fica abafada enquanto estiver tonto

	if doses >= ctrl.limite_bebidas:
		ctrl.visual.mensagem("Você bebeu demais...")
		await _apagar(id)
		return

	# As doses valem para o jogo todo, mesmo com intervalos entre elas
	ctrl.visual.mensagem("Bebidas: %d/%d" % [doses, ctrl.limite_bebidas])

# --- Olho fechando ---

func _apagar(id: int) -> void:
	apagado = true
	_garantir_palpebras()
	Som.sfx("coracao", 0.0, 0.0, 0.5)
	Som.sfx("coracao", 0.0, 0.0, 2.5)
	var t: float = ctrl.tempo_fechar_olho
	var tw: Tween = ctrl.create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_palpebra_cima, "anchor_bottom", 0.51, t)
	tw.tween_property(_palpebra_baixo, "anchor_top", 0.49, t)
	await tw.finished
	if id != _id:
		return

	if not ctrl.reabrir_apos_apagar:
		return
	Som.sfx("coracao", 0.0, 0.0, 0.5)
	await ctrl.get_tree().create_timer(ctrl.tempo_olho_fechado).timeout
	if id != _id:
		return

	var tw2: Tween = ctrl.create_tween().set_parallel(true)
	tw2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(_palpebra_cima, "anchor_bottom", 0.0, ctrl.tempo_fechar_olho)
	tw2.tween_property(_palpebra_baixo, "anchor_top", 1.0, ctrl.tempo_fechar_olho)
	await tw2.finished
	if id != _id:
		return
	doses = 0
	apagado = false

func _garantir_palpebras() -> void:
	if _camada != null and is_instance_valid(_camada):
		return
	_camada = CanvasLayer.new()
	_camada.layer = 110
	ctrl.add_child(_camada)
	_palpebra_cima = _nova_palpebra(0.0, 0.0)
	_palpebra_baixo = _nova_palpebra(1.0, 1.0)

func _nova_palpebra(anc_topo: float, anc_base: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(r)
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = anc_topo
	r.anchor_bottom = anc_base
	r.offset_left = 0.0
	r.offset_right = 0.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	return r

func _abrir_instantaneo() -> void:
	if _palpebra_cima != null and is_instance_valid(_palpebra_cima):
		_palpebra_cima.anchor_bottom = 0.0
	if _palpebra_baixo != null and is_instance_valid(_palpebra_baixo):
		_palpebra_baixo.anchor_top = 1.0
