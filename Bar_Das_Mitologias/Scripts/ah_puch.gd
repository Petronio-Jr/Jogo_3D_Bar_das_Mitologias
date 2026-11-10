extends Node3D
## Ah Puch: NPC de conversa.
## - Chegue perto (Area3D) e aperte E para começar a falar.
## - Cada E seguinte pula para a próxima fala (se o texto ainda estiver sendo
##   digitado, o 1º E completa a fala; veja `completar_antes_de_avancar`).
##
## COMO MONTAR NA CENA (tudo editável no editor):
##   AhPuch (este script)
##   ├─ Area3D
##   ├─ AnimationPlayer2            <- tem a animação idle (veja `animation_player`)
##   ├─ Balao  (Label3D)            <- fala do NPC; posicione/estilize como quiser
##   │   └─ Fundo (MeshInstance3D)  <- opcional, QuadMesh; é redimensionado pelo script
##   └─ Prompt (Label3D)            <- "Pressione E para falar"
## Arraste os nós para os campos `label_balao`, `fundo_balao` e `label_prompt`
## (se estiverem vazios, o script procura filhos chamados Balao, Fundo e Prompt).

signal conversa_iniciada
signal conversa_terminada

# --- Falas ---
@export var falas: Array[String] = [
	"Ah, um visitante... poucos chegam até aqui.",
	"Eu sou Ah Puch, senhor de Mitnal, o mundo dos mortos.",
	"Se você esta aqui é porque se recusa a morrer, não é mesmo?",
	"Bom.. é seu dia de sorte, as cartas estão na mesa",
	"E a aposta?",
	"Sua alma",
	"Pegue essa chave... E que os deuses tenham piedade",
]
# (Opcional) animação de cada fala, na mesma ordem de "falas". Vazio = usa animacao_falando.
@export var animacoes_falas: Array[String] = []

# --- Animações ---
# AnimationPlayer usado pelo script. Vazio = procura "AnimationPlayer2" e, se não
# existir, o primeiro AnimationPlayer filho.
@export var animation_player: AnimationPlayer
# Animação idle única: começa ao iniciar o jogo, em loop, e volta quando ele para de falar.
@export var animacao_idle: String = "idle"
@export var animacao_falando: String = "FALANDO"

# --- Áudio ---
@export_group("Áudio")
# (Opcional) voz de cada fala, na mesma ordem de "falas". Se vazio, procura
# res://audio/voz_ahpuch/fala_01, fala_02... automaticamente.
@export var sons_falas: Array[AudioStream] = []
@export var voz_automatica: bool = true
# Sem voz gravada, cada letra digitada faz um "blip" grave (estilo RPG)
@export var blip_ativo: bool = true
@export var letras_por_blip: int = 2
@export var abafar_musica_ao_falar: bool = true

# --- Interação ---
@export var tecla_interagir: Key = KEY_E
@export var completar_antes_de_avancar: bool = true
@export var travar_jogador: bool = true          # o jogador não anda durante a conversa
@export var olhar_para_jogador: bool = true
@export var giro_offset_graus: float = 0.0       # se o modelo olhar para o lado errado, ajuste (ex.: 180)
@export var area: Area3D                         # vazio = procura a primeira Area3D filha

# --- Balão (nós da cena) ---
@export_group("Balão")
@export var label_balao: Label3D                 # vazio = filho chamado "Balao"
@export var fundo_balao: MeshInstance3D          # vazio = filho do balão chamado "Fundo" (opcional)
@export var label_prompt: Label3D                # vazio = filho chamado "Prompt"
@export var velocidade_texto: float = 45.0       # caracteres por segundo
@export var ajustar_fundo_ao_texto: bool = true  # redimensiona o Fundo conforme o texto
@export var margem_fundo: float = 0.05
@export_subgroup("Quebra de linha")
@export var quebra_automatica: bool = true       # quebra as frases em várias linhas
@export var largura_quebra_px: float = 520.0     # largura máxima da linha (em pixels do Label3D); 0 = usa a do Inspector
@export var modo_quebra: TextServer.AutowrapMode = TextServer.AUTOWRAP_WORD_SMART
@export var seguir_sem_herdar_rotacao: bool = true  # balão não gira junto quando o NPC vira

const NOME_PLAYER_PADRAO: String = "AnimationPlayer2"

var _player: AnimationPlayer
var _nome_idle: String = ""
var _jogador: Node3D
var _jogador_na_area: bool = false
var _conversando: bool = false
var _indice: int = 0
var _id_fala: int = 0

var _texto_completo: String = ""
var _voz_da_fala: AudioStream = null
var _digitando: bool = false
var _acum: float = 0.0
var _chars_mostrados: int = 0

var _yaw_original: float = 0.0
var _tween_giro: Tween

# Offsets (mundo) dos nós em relação ao NPC, guardados no início
var _offset_balao: Vector3 = Vector3.ZERO
var _offset_prompt: Vector3 = Vector3.ZERO

func _ready() -> void:
	_yaw_original = rotation.y

	_preparar_animacao()
	_tocar_idle()

	if area == null:
		area = _achar_area()
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		push_warning("[AhPuch] Nenhuma Area3D encontrada.")

	_preparar_balao()

# --- Entrada ---

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == tecla_interagir):
		return
	if _conversando:
		get_viewport().set_input_as_handled()
		_avancar()
	elif _jogador_na_area and not falas.is_empty():
		get_viewport().set_input_as_handled()
		_iniciar()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_jogador = body
		_jogador_na_area = true
		_set_prompt(not _conversando)

func _on_body_exited(body: Node3D) -> void:
	if body == _jogador:
		_jogador_na_area = false
		_set_prompt(false)
		if _conversando:
			_encerrar()

# --- Conversa ---

func _iniciar() -> void:
	_conversando = true
	_indice = 0
	_set_prompt(false)
	if travar_jogador and _jogador != null:
		_jogador.set_physics_process(false)
		if _jogador is CharacterBody3D:
			(_jogador as CharacterBody3D).velocity = Vector3.ZERO
	if olhar_para_jogador:
		_virar_para_jogador()
	Som.sfx("fala_inicio", -4.0)
	if abafar_musica_ao_falar:
		Som.abafar(-10.0, 0.6)
	conversa_iniciada.emit()
	_mostrar_fala()

func _avancar() -> void:
	if _digitando and completar_antes_de_avancar:
		_completar_texto()
		return
	_indice += 1
	if _indice >= falas.size():
		_encerrar()
	else:
		_mostrar_fala()

func _encerrar() -> void:
	_conversando = false
	_digitando = false
	_id_fala += 1
	Som.parar_voz()
	Som.sfx("fala_fim", -4.0)
	if abafar_musica_ao_falar:
		Som.soltar(1.2)
	_balao_visivel(false)
	_tocar_idle()
	if travar_jogador and _jogador != null and is_instance_valid(_jogador):
		_jogador.set_physics_process(true)
	if olhar_para_jogador:
		_girar_para(_yaw_original)
	_set_prompt(_jogador_na_area)
	conversa_terminada.emit()

func _mostrar_fala() -> void:
	_id_fala += 1
	var id: int = _id_fala
	_texto_completo = falas[_indice]
	Som.parar_voz()
	_voz_da_fala = _resolver_voz(_indice)

	var anim: String = animacao_falando
	if _indice < animacoes_falas.size() and animacoes_falas[_indice] != "":
		anim = animacoes_falas[_indice]
	_tocar(anim)

	if label_balao == null:
		return

	# Mede o balão com o texto inteiro (para o fundo não "crescer" enquanto digita)
	_digitando = false
	_balao_visivel(false)
	label_balao.text = _texto_completo
	await get_tree().process_frame
	await get_tree().process_frame
	if id != _id_fala or not _conversando:
		return

	if ajustar_fundo_ao_texto and fundo_balao != null:
		var caixa: AABB = label_balao.get_aabb()
		var m: float = margem_fundo
		if fundo_balao.mesh == null:
			fundo_balao.mesh = QuadMesh.new()
		if fundo_balao.mesh is QuadMesh:
			(fundo_balao.mesh as QuadMesh).size = Vector2(caixa.size.x + m * 2.0, caixa.size.y + m * 2.0)
		fundo_balao.position = Vector3(caixa.get_center().x, caixa.get_center().y, fundo_balao.position.z)

	label_balao.text = ""
	_chars_mostrados = 0
	_acum = 0.0
	_digitando = true
	_balao_visivel(true)
	if _voz_da_fala != null:
		Som.voz(_voz_da_fala)   # voz gravada começa junto com o texto

func _resolver_voz(indice: int) -> AudioStream:
	if indice < sons_falas.size() and sons_falas[indice] != null:
		return sons_falas[indice]
	return Som.stream_fala(indice) if voz_automatica else null

func _completar_texto() -> void:
	_digitando = false
	if label_balao != null:
		label_balao.text = _texto_completo
	_tocar_idle()

func _process(delta: float) -> void:
	# Mantém balão e prompt na posição relativa ao NPC (sem herdar o giro dele)
	if seguir_sem_herdar_rotacao:
		if label_balao != null:
			label_balao.global_position = global_position + _offset_balao
		if label_prompt != null:
			label_prompt.global_position = global_position + _offset_prompt

	if _digitando and label_balao != null:
		_acum += delta * velocidade_texto
		var n: int = mini(int(_acum), _texto_completo.length())
		if n != _chars_mostrados:
			_chars_mostrados = n
			label_balao.text = _texto_completo.substr(0, n)
			# "Blip" a cada N letras (pula espaços), só se não houver voz gravada
			if blip_ativo and _voz_da_fala == null and n > 0 and n % maxi(letras_por_blip, 1) == 0 and _texto_completo[n - 1] != " ":
				Som.blip()
		if n >= _texto_completo.length():
			_digitando = false
			_tocar_idle()

# --- Balão (nós da cena) ---

func _preparar_balao() -> void:
	if label_balao == null:
		label_balao = get_node_or_null("Balao") as Label3D
		if label_balao == null:
			label_balao = find_child("Balao", true, false) as Label3D
	if label_prompt == null:
		label_prompt = find_child("Prompt", true, false) as Label3D
	if fundo_balao == null and label_balao != null:
		fundo_balao = label_balao.find_child("Fundo", true, false) as MeshInstance3D

	if label_balao == null:
		push_warning("[AhPuch] Label3D do balão não encontrado (crie um filho chamado 'Balao' ou atribua em label_balao).")
	if label_prompt == null:
		push_warning("[AhPuch] Label3D do prompt não encontrado (crie um filho chamado 'Prompt' ou atribua em label_prompt).")

	_configurar_quebra()

	if seguir_sem_herdar_rotacao:
		_offset_balao = _destacar(label_balao)
		_offset_prompt = _destacar(label_prompt)

	_balao_visivel(false)
	_set_prompt(false)

func _configurar_quebra() -> void:
	if label_balao == null:
		return
	if quebra_automatica:
		label_balao.autowrap_mode = modo_quebra
		if largura_quebra_px > 0.0:
			label_balao.width = largura_quebra_px
		label_balao.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		label_balao.autowrap_mode = TextServer.AUTOWRAP_OFF

# Torna o nó top_level mantendo sua posição/escala atuais no mundo.
# Retorna o deslocamento dele em relação ao NPC.
func _destacar(n: Node3D) -> Vector3:
	if n == null:
		return Vector3.ZERO
	var t: Transform3D = n.global_transform
	n.top_level = true
	n.global_transform = t
	return t.origin - global_position

func _balao_visivel(v: bool) -> void:
	if label_balao != null:
		label_balao.visible = v
	if fundo_balao != null:
		fundo_balao.visible = v

func _set_prompt(v: bool) -> void:
	if label_prompt != null:
		label_prompt.visible = v

# --- Animação / giro ---

func _preparar_animacao() -> void:
	_player = animation_player
	if _player == null:
		_player = find_child(NOME_PLAYER_PADRAO, true, false) as AnimationPlayer
	if _player == null:
		var lista := find_children("*", "AnimationPlayer", true, false)
		if not lista.is_empty():
			_player = lista[0] as AnimationPlayer
	if _player == null:
		push_warning("[AhPuch] Nenhum AnimationPlayer encontrado; atribua em `animation_player`.")
		return

	print("[AhPuch] ", _player.name, " tem as animações: ", _player.get_animation_list())
	_nome_idle = AnimUtil.resolver(_player, animacao_idle)
	if _nome_idle == "":
		push_warning("[AhPuch] Animação idle '%s' não encontrada em %s." % [animacao_idle, _player.name])
		return
	var dados: Animation = _player.get_animation(_nome_idle)
	if dados.loop_mode == Animation.LOOP_NONE:
		dados.loop_mode = Animation.LOOP_LINEAR

# Toca (ou retoma) a animação idle
func _tocar_idle() -> void:
	if _player == null or _nome_idle == "":
		return
	if _player.current_animation != _nome_idle or not _player.is_playing():
		_player.play(_nome_idle)

# Toca uma animação pontual (ex.: fala)
func _tocar(nome: String) -> void:
	if _player == null or nome == "":
		return
	var anim: String = AnimUtil.resolver(_player, nome)
	if anim != "" and (_player.current_animation != anim or not _player.is_playing()):
		_player.play(anim)

func _achar_area() -> Area3D:
	var lista := find_children("*", "Area3D", true, false)
	return lista[0] as Area3D if not lista.is_empty() else null

func _virar_para_jogador() -> void:
	if _jogador == null:
		return
	var dir: Vector3 = _jogador.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	_girar_para(atan2(dir.x, dir.z) + deg_to_rad(giro_offset_graus))

func _girar_para(yaw: float) -> void:
	if _tween_giro != null and _tween_giro.is_valid():
		_tween_giro.kill()
	_tween_giro = create_tween()
	_tween_giro.tween_method(func(t: float): rotation.y = lerp_angle(rotation.y, yaw, t), 0.0, 1.0, 0.4)
