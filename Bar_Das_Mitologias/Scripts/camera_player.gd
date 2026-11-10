extends Camera3D

@export var sensibilidade_mouse: float = 0.003
@export var limite_pitch: float = 60.0 # Limite de olhar para cima/baixo em graus
 
# Configurações de Zoom
@export var fov_min: float = 35.0
@export var fov_max: float = 75.0
@export var fov_passo: float = 5.0
 
# Tontura: tempo (s) para o efeito entrar e sair
@export var entrada_tontura: float = 1.0
@export var saida_tontura: float = 2.5
 
var rot_x: float = 0.0
var rot_y: float = 0.0
var rot_z_base: float = 0.0
 
var _tontura_total: float = 0.0
var _tontura_restante: float = 0.0
var _tontura_forca: float = 1.0
var _tontura_tempo: float = 0.0
 
func _ready():
	# Mantém o rato sempre capturado para o estilo FPS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rot_x = rotation.x
	rot_y = rotation.y
	rot_z_base = rotation.z
 
# Deixa a câmera balançando sozinha por "duracao" segundos.
# O jogador continua controlando o olhar normalmente por cima do balanço.
func ficar_tonto(duracao: float = 10.0, forca: float = 1.0) -> void:
	# Se já estiver tonto, mantém o tempo decorrido: a intensidade não "cai a zero"
	# e sobe de novo a cada dose; só estende a duração e aumenta a força.
	var decorrido: float = (_tontura_total - _tontura_restante) if _tontura_restante > 0.0 else 0.0
	_tontura_total = decorrido + duracao
	_tontura_restante = duracao
	_tontura_forca = forca
 
func _unhandled_input(event):
	# Só a câmera ativa processa input. Sem isso, o mouse acumulava rotação
	# nesta câmera enquanto o jogador andava pelo mapa e ela aparecia
	# olhando para baixo ao sentar na cadeira.
	if not current:
		return

	# 1. Zoom na Câmera via Roda do Rato
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			fov = clamp(fov - fov_passo, fov_min, fov_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fov = clamp(fov + fov_passo, fov_min, fov_max)
 
	# 2. Processa a movimentação do mouse para olhar ao redor
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rot_y -= event.relative.x * sensibilidade_mouse
		rot_x -= event.relative.y * sensibilidade_mouse
		rot_x = clamp(rot_x, deg_to_rad(-limite_pitch), deg_to_rad(limite_pitch))
 
# A rotação final = olhar do jogador + balanço da tontura (se houver)
func _process(delta: float) -> void:
	var balanco: Vector3 = Vector3.ZERO
	
	if _tontura_restante > 0.0:
		_tontura_restante = maxf(_tontura_restante - delta, 0.0)
		_tontura_tempo += delta
		var decorrido: float = _tontura_total - _tontura_restante
		# Sobe suave no começo e some devagar no fim
		var intensidade: float = clampf(minf(decorrido / entrada_tontura, _tontura_restante / saida_tontura), 0.0, 1.0) * _tontura_forca
		var t: float = _tontura_tempo
		balanco.y = (sin(t * 0.9) * 0.07 + sin(t * 1.7 + 1.3) * 0.035) * intensidade   # guinada (esq/dir)
		balanco.x = (sin(t * 1.1 + 0.5) * 0.05 + sin(t * 2.3) * 0.02) * intensidade    # inclinação (cima/baixo)
		balanco.z = (sin(t * 0.7 + 2.0) * 0.10 + sin(t * 1.9) * 0.03) * intensidade    # rolagem (cabeça tombando)
	
	rotation = Vector3(rot_x + balanco.x, rot_y + balanco.y, rot_z_base + balanco.z)
