extends CharacterBody3D

@export var velocidade: float = 7.0
@export var gravidade: float = 9.8

@onready var camera: Camera3D = $CameraJogador

func _ready() -> void:
	# Garante que o rato começa capturado ao iniciar o jogo
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Pressionar ESC alterna entre soltar o rato e capturá-lo de novo
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Aplica a gravidade se não estiver no chão
	if not is_on_floor():
		velocity.y -= gravidade * delta

	# Lê as teclas WASD e as setas do teclado
# Lê as teclas WASD e as setas do teclado (com os valores corrigidos)
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_dir.y = 1   # Alterado para 1 (avança)
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_dir.y = -1  # Alterado para -1 (recua)
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input_dir.x += 1

	# Pega a direção para onde a câmara está apontada (ignorando o eixo Y para não voar)
	var forward = -camera.global_transform.basis.z
	var right = camera.global_transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	# Calcula a direção final do movimento com base na visão da câmara
	var direcao := (forward * input_dir.y + right * input_dir.x).normalized()
	
	if direcao:
		velocity.x = direcao.x * velocidade
		velocity.z = direcao.z * velocidade
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade)
		velocity.z = move_toward(velocity.z, 0, velocidade)

	move_and_slide()
