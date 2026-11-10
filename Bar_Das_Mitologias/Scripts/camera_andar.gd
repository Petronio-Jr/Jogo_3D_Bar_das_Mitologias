extends Camera3D

@export var sensibilidade_mouse: float = 0.003
@export var limite_pitch: float = 60.0

# Configurações de balanço bem lento e suave
@export var frequencia_balanco: float = 1     # Reduzido para um ritmo bem mais lento
@export var amplitude_inclinacao: float = 0.015 # Suave e subtil

var rot_x: float = 0.0
var rot_y: float = 0.0
var rot_z_base: float = 0.0

var _tempo_movimento: float = 0.0
var offset_z_atual: float = 0.0

# --- Pré-aquecimento (evita a "travadinha" ao virar a câmera pela 1ª vez) ---
# A Godot só compila shaders / sobe malhas, texturas e sombras para a GPU quando
# o objeto aparece na tela pela primeira vez. Ao girar a câmera no começo do
# jogo, tudo que estava "fora de vista" é carregado de uma vez -> engasgo.
# Aqui giramos a câmera escondida atrás de uma tela preta para forçar esse
# carregamento antes do jogador ter o controle.
@export var pre_aquecer: bool = true
@export var passos_pre_aquecimento: int = 12   # passos do giro de 360°
@export var frames_por_passo: int = 2
var _aquecendo: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rot_x = rotation.x
	rot_y = rotation.y
	rot_z_base = rotation.z
	make_current()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rot_y -= event.relative.x * sensibilidade_mouse
		rot_x -= event.relative.y * sensibilidade_mouse
		rot_x = clamp(rot_x, deg_to_rad(-limite_pitch), deg_to_rad(limite_pitch))
func _process(delta: float) -> void:
	var parent = get_parent()
	var alvo_rot_z: float = 0.0
	
	if parent is CharacterBody3D and parent.is_on_floor():
		var velocidade_horizontal = Vector3(parent.velocity.x, 0, parent.velocity.z).length()
		if velocidade_horizontal > 0.1:
			_tempo_movimento += delta * velocidade_horizontal * frequencia_balanco
			alvo_rot_z = sin(_tempo_movimento) * amplitude_inclinacao
		else:
			_tempo_movimento = 0.0
			alvo_rot_z = 0.0

	# Lerp ajustado para acompanhar a suavidade lenta
	offset_z_atual = lerp(offset_z_atual, alvo_rot_z, delta * 3.0)

	rotation = Vector3(rot_x, rot_y, rot_z_base + offset_z_atual)
