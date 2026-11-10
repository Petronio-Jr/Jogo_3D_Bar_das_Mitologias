extends Node3D
 
# Anexe este script ao nó raiz da garrafa (Node3D ou MeshInstance3D).
# Passar o dot por cima faz a garrafa subir; clicar deixa a câmera "tonta".
 
signal garrafa_clicada
 
# Quanto a garrafa sobe no hover (em metros)
@export var altura_hover: float = 0.08
@export var duracao_hover: float = 0.15
# Folga (em metros) somada à malha ao testar o raio da mira
@export var margem_mira: float = 0.01
# Tontura da câmera
@export var duracao_tontura: float = 10.0
@export var forca_tontura: float = 1.0
 
var y_original: float
var tween: Tween
var _malhas: Array = []
 
func _ready() -> void:
	y_original = global_position.y
	# O controlador testa a mira contra tudo o que está neste grupo
	add_to_group("interativos_mira")
	_malhas = find_children("*", "MeshInstance3D", true, false)
	# Se o script estiver anexado direto a um MeshInstance3D, ele próprio entra na lista
	var este: Node = self
	if este is MeshInstance3D:
		_malhas.append(este)
 
# Chamado pelo controlador quando o dot entra/sai da garrafa
func definir_hover(ativo: bool) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	var alvo_y: float = y_original + (altura_hover if ativo else 0.0)
	tween.tween_property(self, "global_position:y", alvo_y, duracao_hover)
 
# Chamado pelo controlador quando o jogador clica na garrafa
func interagir_por_mira() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("ficar_tonto"):
		camera.ficar_tonto(duracao_tontura, forca_tontura)
	garrafa_clicada.emit()
 
# Distância da origem do raio até a garrafa (INF se o raio não acerta).
# Ignora a elevação do hover, para a área não "fugir" do dot quando a garrafa sobe.
func distancia_do_raio(origem: Vector3, direcao: Vector3) -> float:
	var melhor: float = INF
	var elevacao: float = global_position.y - y_original
	
	for m in _malhas:
		if not is_instance_valid(m) or m.mesh == null or not m.is_visible_in_tree():
			continue
		var t: Transform3D = m.global_transform
		t.origin.y -= elevacao
		var inv: Transform3D = t.affine_inverse()
		var caixa: AABB = m.get_aabb().grow(margem_mira)
		var hit = caixa.intersects_ray(inv * origem, inv.basis * direcao)
		if hit != null:
			melhor = minf(melhor, origem.distance_to(t * (hit as Vector3)))
	
	return melhor
