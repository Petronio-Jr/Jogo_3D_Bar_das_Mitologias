class_name EfeitoInchar
extends RefCounted
## "Inchada" dos objetos interativos: cresce um pouco quando a mira passa por cima
## (hover) e dá um pulso maior quando é clicado. Não guarda estado próprio:
## a escala original e o tween ficam como metadados no próprio nó.

const FATOR_HOVER: float = 1.05
const FATOR_PULSO: float = 1.2

static func _base(no: Node3D) -> Vector3:
	if not no.has_meta("_inchar_base"):
		no.set_meta("_inchar_base", no.scale)
	return no.get_meta("_inchar_base")

static func _novo_tween(no: Node3D) -> Tween:
	if no.has_meta("_inchar_tween"):
		var antigo = no.get_meta("_inchar_tween")
		if antigo is Tween and antigo.is_valid():
			antigo.kill()
	var tw: Tween = no.create_tween()
	no.set_meta("_inchar_tween", tw)
	return tw

static func hover(alvo: Node, ativo: bool) -> void:
	var no := alvo as Node3D
	if no == null or not is_instance_valid(no):
		return
	var base: Vector3 = _base(no)
	no.set_meta("_inchar_hover", ativo)
	var tw: Tween = _novo_tween(no)
	tw.tween_property(no, "scale", base * (FATOR_HOVER if ativo else 1.0), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func pulsar(alvo: Node, fator: float = FATOR_PULSO) -> void:
	var no := alvo as Node3D
	if no == null or not is_instance_valid(no):
		return
	var base: Vector3 = _base(no)
	var em_hover: bool = no.get_meta("_inchar_hover", false)
	var final_: Vector3 = base * (FATOR_HOVER if em_hover else 1.0)
	var tw: Tween = _novo_tween(no)
	tw.tween_property(no, "scale", base * fator, 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(no, "scale", final_, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
