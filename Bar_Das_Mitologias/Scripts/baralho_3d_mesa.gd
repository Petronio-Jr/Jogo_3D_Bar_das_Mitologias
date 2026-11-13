extends Node3D
 
signal baralho_clicado
 
@onready var area_3d: Area3D = $Area3D
 
# Quanto o baralho sobe quando a mira está sobre ele
@export var altura_hover: float = 0.03
@export var duracao_hover: float = 0.08
# "Inchada": escala no hover e no clique (mesmo efeito do baralho de poder)
@export var escala_hover: float = 1.01
@export var escala_pulso: float = 1.2
# Folga (em metros) somada ao volume da malha ao testar o raio da mira
@export var margem_mira: float = 0.01
 
var pos_y_original: float
var escala_original: Vector3 = Vector3.ONE
var tween: Tween
var _em_hover: bool = false
var _malhas: Array = []
 
func _ready():
	pos_y_original = position.y
	escala_original = scale
	_malhas = find_children("*", "MeshInstance3D", true, false)
 
# Chamado pelo controlador quando a mira entra/sai do baralho
func definir_hover(ativo: bool) -> void:
	_em_hover = ativo
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	var alvo_y: float = pos_y_original + (altura_hover if ativo else 0.0)
	tween.tween_property(self, "position:y", alvo_y, duracao_hover)
	tween.tween_property(self, "scale", escala_original * (escala_hover if ativo else 1.0), duracao_hover)

# Pulso ao clicar (chamado pelo controlador)
func pulsar() -> void:
	if tween and tween.is_running():
		tween.kill()
	var alvo_y: float = pos_y_original + (altura_hover if _em_hover else 0.0)
	var escala_final: Vector3 = escala_original * (escala_hover if _em_hover else 1.0)
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", escala_original * escala_pulso, 0.1)
	tween.parallel().tween_property(self, "position:y", alvo_y, 0.1)
	tween.tween_property(self, "scale", escala_final, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 
# Distância da origem do raio até o baralho (INF se o raio não acerta).
# O teste ignora a elevação do hover, para a área não "fugir" do dot ao subir.
func distancia_do_raio(origem: Vector3, direcao: Vector3) -> float:
	var melhor: float = INF
	
	var elevacao: Vector3 = Vector3(0, position.y - pos_y_original, 0)
	var pai := get_parent() as Node3D
	if pai != null:
		elevacao = pai.global_transform.basis * elevacao
	
	for m in _malhas:
		if not is_instance_valid(m) or m.mesh == null or not m.is_visible_in_tree():
			continue
		var t: Transform3D = m.global_transform
		t.origin -= elevacao
		var inv: Transform3D = t.affine_inverse()
		var caixa: AABB = m.get_aabb().grow(margem_mira)
		var hit = caixa.intersects_ray(inv * origem, inv.basis * direcao)
		if hit != null:
			melhor = minf(melhor, origem.distance_to(t * (hit as Vector3)))
	
	return melhor
