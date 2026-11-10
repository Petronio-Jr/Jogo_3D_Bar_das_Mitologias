extends Node3D

@export var duracao_giro: float = 0.4 # Tempo da animação em segundos

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var label_texto: Label3D = $TextoValor1
@onready var label_texto2: Label3D = $TextoValor2
@onready var label_texto3: Label3D = $TextoValor3

var tween_rotacao: Tween

const CORES_CARTA = {
	Carta.Cor.VERMELHA: Color(0.85, 0.15, 0.15),
	Carta.Cor.AZUL: Color(0.15, 0.45, 0.85),
	Carta.Cor.AMARELA: Color(0.95, 0.75, 0.1),
	Carta.Cor.VERDE: Color(0.15, 0.75, 0.25),
	Carta.Cor.PRETA: Color(0.1, 0.1, 0.1)
}

func _ready() -> void:
	if mesh_instance:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Gira a carta suavemente em direção ao próximo ângulo
func girar_graus(graus: float) -> void:
	# Cancela animação anterior se uma nova for iniciada antes de acabar
	if tween_rotacao and tween_rotacao.is_running():
		tween_rotacao.kill()

	var angulo_destino = rotation.y + deg_to_rad(graus)
	
	tween_rotacao = create_tween()
	# Transição suave com desaceleração no final (EASE_OUT) e curva suave (TRANS_CUBIC)
	tween_rotacao.set_ease(Tween.EASE_OUT)
	tween_rotacao.set_trans(Tween.TRANS_CUBIC)
	tween_rotacao.tween_property(self, "rotation:y", angulo_destino, duracao_giro)

func atualizar_visual_carta(carta_dado: Carta) -> void:
	if carta_dado == null:
		return
		
	if label_texto:
		label_texto.text = carta_dado.para_texto()
		label_texto2.text = carta_dado.para_texto()
		label_texto3.text = carta_dado.para_texto()
	
	if mesh_instance:
		var mat_original = mesh_instance.get_surface_override_material(0)
		var mat_unico: StandardMaterial3D = mat_original.duplicate() if mat_original else StandardMaterial3D.new()
		mat_unico.albedo_color = CORES_CARTA.get(carta_dado.cor, Color.WHITE)
		mesh_instance.set_surface_override_material(0, mat_unico)
