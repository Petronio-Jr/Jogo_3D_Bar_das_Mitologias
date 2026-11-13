extends MeshInstance3D
## Porta: abre e fecha girando em torno de uma dobradiça.
## - Chegue perto (Area3D) e aperte E para abrir/fechar.
##
## COMO MONTAR NA CENA:
##   Porta (MeshInstance3D, este script)
##   ├─ StaticBody3D > CollisionShape3D   <- colisão; gira junto com a porta
##   ├─ Area3D > CollisionShape3D         <- zona de interação (maior que a porta)
##   └─ Prompt (Label3D)                  <- opcional: "Pressione E"
## O jogador precisa ser um CharacterBody3D.
##
## DOBRADIÇA: por padrão é calculada sozinha a partir da malha. A largura é o maior
## eixo horizontal (X ou Z) e a dobradiça fica numa ponta dele; `lado_dobradica`
## escolhe qual ponta (Negativo/Positivo). Se ficar do lado errado, troque esse campo.
## Para controle manual, desligue `dobradica_automatica` e preencha `dobradica`
## (posição no espaço LOCAL da porta).

signal porta_abriu
signal porta_fechou
signal porta_trancada_tentativa

# --- Movimento ---
@export var dobradica_automatica: bool = true       # calcula a dobradiça pela malha (borda da largura)
@export_enum("Negativo:-1", "Positivo:1") var lado_dobradica: int = -1   # em qual ponta da largura fica a dobradiça
@export var dobradica: Vector3 = Vector3.ZERO       # só usado se dobradica_automatica estiver desligado
@export_range(0.0, 180.0, 1.0) var angulo_abertura: float = 120.0   # graus
@export var duracao: float = 1                                    # segundos
@export var transicao: Tween.TransitionType = Tween.TRANS_CUBIC
@export var abrir_para_longe_do_jogador: bool = true                # senão, sempre no mesmo sentido
@export var inverter_sentido: bool = false                          # troca o sentido de giro
@export var iniciar_aberta: bool = false

# --- Interação ---
@export var tecla_interagir: Key = KEY_E
@export var trancada: bool = false
@export var fechar_ao_sair: bool = false           # fecha sozinha quando o jogador se afasta
@export var area: Area3D                            # vazio = primeira Area3D filha
@export var label_prompt: Label3D                   # vazio = filho chamado "Prompt"
@export var texto_abrir: String = "Pressione E para abrir"
@export var texto_fechar: String = "Pressione E para fechar"
@export var texto_trancada: String = "Trancada"

# --- Áudio (opcional) ---
@export var som_abrir: AudioStream
@export var som_fechar: AudioStream
@export var som_trancada: AudioStream

var aberta: bool = false
var _largura_em_z: bool = false

var _fechada_xform: Transform3D
var _angulo_atual: float = 0.0     # radianos, em relação à porta fechada
var _angulo_alvo: float = 0.0
var _tween: Tween
var _jogador: Node3D
var _jogador_na_area: bool = false
var _audio: AudioStreamPlayer3D

func _ready() -> void:
	_fechada_xform = transform
	_calcular_dobradica()

	if area == null:
		var lista := find_children("*", "Area3D", true, false)
		if not lista.is_empty():
			area = lista[0] as Area3D
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		push_warning("[Porta] Nenhuma Area3D encontrada.")

	if label_prompt == null:
		label_prompt = find_child("Prompt", true, false) as Label3D
	_set_prompt(false)

	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 4.0
	add_child(_audio)
	Som.g()   # garante que o barramento "SFX" exista
	if AudioServer.get_bus_index("SFX") != -1:
		_audio.bus = "SFX"

	if iniciar_aberta:
		aberta = true
		_angulo_alvo = _sentido_padrao() * deg_to_rad(angulo_abertura)
		_aplicar_angulo(_angulo_alvo)

# --- Entrada ---

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == tecla_interagir):
		return
	if _jogador_na_area:
		get_viewport().set_input_as_handled()
		alternar()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_jogador = body
		_jogador_na_area = true
		_atualizar_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body == _jogador:
		_jogador_na_area = false
		_set_prompt(false)
		if fechar_ao_sair and aberta:
			fechar()

# --- API pública ---

func alternar() -> void:
	if aberta:
		fechar()
	else:
		abrir()

func abrir() -> void:
	if aberta:
		return
	if trancada:
		_tocar_som(som_trancada, "porta_trancada")
		porta_trancada_tentativa.emit()
		return
	aberta = true
	var sentido: float = _sentido_padrao()
	if abrir_para_longe_do_jogador and _jogador != null and is_instance_valid(_jogador):
		# Lado do jogador no espaço local da porta, no eixo da ESPESSURA
		var local: Vector3 = to_local(_jogador.global_position)
		var lado: float = signf(local.x if _largura_em_z else local.z)
		if lado != 0.0:
			sentido = -lado * (-1.0 if inverter_sentido else 1.0)
	_girar_para(sentido * deg_to_rad(angulo_abertura))
	_tocar_som(som_abrir, "porta_abrir")
	porta_abriu.emit()

func fechar() -> void:
	if not aberta:
		return
	aberta = false
	_girar_para(0.0)
	_tocar_som(som_fechar, "porta_fechar")
	porta_fechou.emit()

func trancar() -> void:
	trancada = true
	_atualizar_prompt()

func destrancar() -> void:
	trancada = false
	_atualizar_prompt()

# --- Internos ---

# A largura é o maior eixo horizontal da malha (X ou Z); a dobradiça fica na ponta dele.
func _calcular_dobradica() -> void:
	if mesh == null:
		return
	var caixa: AABB = mesh.get_aabb()
	_largura_em_z = caixa.size.z >= caixa.size.x
	if not dobradica_automatica:
		return
	var c: Vector3 = caixa.get_center()
	if _largura_em_z:
		dobradica = Vector3(c.x, c.y, c.z + lado_dobradica * caixa.size.z * 0.5)
	else:
		dobradica = Vector3(c.x + lado_dobradica * caixa.size.x * 0.5, c.y, c.z)

func _sentido_padrao() -> float:
	return -1.0 if inverter_sentido else 1.0

func _girar_para(alvo: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_angulo_alvo = alvo
	_tween = create_tween()
	_tween.set_trans(transicao).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_aplicar_angulo, _angulo_atual, alvo, duracao)
	_tween.finished.connect(_atualizar_prompt)
	_atualizar_prompt()

# Gira a porta fechada em torno da dobradiça (eixo Y do pai) pelo ângulo dado
func _aplicar_angulo(ang: float) -> void:
	_angulo_atual = ang
	var ponto: Vector3 = _fechada_xform * dobradica   # dobradiça no espaço do pai
	var rot := Transform3D(Basis(Vector3.UP, ang), Vector3.ZERO)
	var para_origem := Transform3D(Basis.IDENTITY, -ponto)
	var de_volta := Transform3D(Basis.IDENTITY, ponto)
	transform = de_volta * rot * para_origem * _fechada_xform

func _atualizar_prompt() -> void:
	if label_prompt == null or not _jogador_na_area:
		return
	if trancada:
		label_prompt.text = texto_trancada
	else:
		label_prompt.text = texto_fechar if aberta else texto_abrir
	label_prompt.visible = true

func _set_prompt(v: bool) -> void:
	if label_prompt != null:
		label_prompt.visible = v
		if v:
			_atualizar_prompt()

## Usa o som configurado no Inspector; se estiver vazio, usa o padrão de audio/sfx/.
func _tocar_som(som: AudioStream, nome_padrao: String = "") -> void:
	if som == null and nome_padrao != "":
		som = Som.stream_sfx(nome_padrao)
	if som == null or _audio == null:
		return
	_audio.stream = som
	_audio.play()
