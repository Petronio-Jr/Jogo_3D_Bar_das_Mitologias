extends Area3D

@export var mensagem_interacao: String = "Pressione E para sentar e iniciar o jogo"
var jogador_na_area: bool = false

func _ready() -> void:
	# Conecta os sinais de entrada e saída da área
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# Verifica se o corpo que entrou é o jogador (CharacterBody3D)
	if body is CharacterBody3D:
		jogador_na_area = true
		print(mensagem_interacao)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		jogador_na_area = false

func _input(event: InputEvent) -> void:
	# Quando o jogador está na área eprime a tecla 'E'
	if jogador_na_area and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		acionar_cadeira()

func acionar_cadeira() -> void:
	print("Jogador interagiu com a cadeira. A iniciar o jogo de cartas...")
	
	# Procura o controlador do jogo na árvore de nós através do grupo
	var controlador = get_tree().get_first_node_in_group("controlador_jogo")
	if controlador and controlador.has_method("iniciar_jogo_por_interacao"):
		controlador.iniciar_jogo_por_interacao()
	
	# Remove ou desativa a cadeira para evitar reinterações
	queue_free()
