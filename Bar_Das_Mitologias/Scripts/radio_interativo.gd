extends Node3D
## Rádio do cenário.
## - Chegue perto (Area3D) e aperte E para LIGAR (E de novo desliga). Enquanto estiver ligado toca as
##   músicas da pasta `pasta` em ordem aleatória (sem repetir até todas tocarem).
## - Botão ESQUERDO do mouse perto do rádio ligado passa para outra música.
## - A cada troca toca o ruído de "mudar a frequência" (audio/sfx/radio_sintonia) e a música nova
##   começa num ponto aleatório, como se você tivesse sintonizado no meio da programação.
## - O som sai do próprio rádio (3D) com som de alto-falante (barramento "Radio") e o pagode de
##   fundo some enquanto o rádio está ligado.
##
## COMO MONTAR NA CENA:
##   Radio (Node3D ou MeshInstance3D, este script)
##   ├─ Area3D > CollisionShape3D   <- zona de interação (maior que o rádio)
##   └─ Prompt (Label3D)            <- opcional: "Pressione E para ligar"
## O jogador precisa ser um CharacterBody3D. Coloque as músicas em res://audio/pagode_radio/.

signal radio_ligou
signal radio_desligou
signal faixa_mudou(nome: String)

# --- Músicas ---
@export_dir var pasta: String = "res://audio/pagode_radio/"
@export var ligado_no_inicio: bool = false

# --- Som ---
@export var volume_db: float = 0.0
@export var distancia_unidade: float = 3.0      # quanto maior, mais longe o som alcança com força
@export var distancia_maxima: float = 25.0      # além disso não se ouve (0 = sem limite)
@export var esconder_pagode_ao_ligar: bool = true

# --- Interação ---
@export var tecla_interagir: Key = KEY_E
@export var area: Area3D                         # vazio = primeira Area3D filha
@export var label_prompt: Label3D                # vazio = filho chamado "Prompt"
@export var texto_ligar: String = "Pressione E para ligar o rádio"
@export var texto_desligar: String = "Clique para trocar de música  |  E para desligar o rádio"
@export var sintonia_som: String = "radio_sintonia"   # som da troca de estação (audio/sfx/)
@export var comeco_aleatorio: bool = true             # a música começa de qualquer ponto
@export var segundos_finais_evitados: float = 20.0    # não começa nos últimos segundos da música
@export var luz_ligado: Node3D                   # (opcional) aparece só com o rádio ligado

var ligado: bool = false
var faixa_atual: String = ""

var _player: AudioStreamPlayer3D
var _player_sintonia: AudioStreamPlayer3D
var _id_troca: int = 0
var _faixas: Array[AudioStream] = []
var _nomes: Array[String] = []
var _fila: Array[int] = []            # ordem aleatória das faixas que ainda vão tocar
var _ultima: int = -1
var _jogador: Node3D
var _jogador_na_area: bool = false

func _ready() -> void:
	add_to_group("radios")   # os créditos desligam o rádio
	Som.g()   # garante que o barramento "Radio" exista
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = distancia_unidade
	_player.max_distance = distancia_maxima
	_player.volume_db = volume_db
	_player.process_mode = Node.PROCESS_MODE_ALWAYS   # continua tocando com o menu de pausa aberto
	if AudioServer.get_bus_index("Radio") != -1:
		_player.bus = "Radio"
	add_child(_player)
	_player.finished.connect(_on_faixa_terminou)

	_player_sintonia = AudioStreamPlayer3D.new()
	_player_sintonia.unit_size = distancia_unidade
	_player_sintonia.max_distance = distancia_maxima
	_player_sintonia.volume_db = volume_db
	_player_sintonia.process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Radio") != -1:
		_player_sintonia.bus = "Radio"
	add_child(_player_sintonia)

	if area == null:
		var lista := find_children("*", "Area3D", true, false)
		if not lista.is_empty():
			area = lista[0] as Area3D
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		push_warning("[Rádio] Nenhuma Area3D encontrada.")

	if label_prompt == null:
		label_prompt = find_child("Prompt", true, false) as Label3D
	_atualizar_prompt()
	_atualizar_luz()

	_carregar_faixas()
	if ligado_no_inicio:
		ligar()

# --- Entrada ---

func _input(event: InputEvent) -> void:
	# Botão esquerdo perto do rádio ligado: outra música (fora de partidas, onde o clique é das cartas)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ligado and _jogador_na_area and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _jogo_em_andamento():
			get_viewport().set_input_as_handled()
			trocar_musica()
		return
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
		_atualizar_prompt()

# --- API pública ---

func alternar() -> void:
	if ligado:
		desligar()
	else:
		ligar()

func _jogo_em_andamento() -> bool:
	for c in get_tree().get_nodes_in_group("controlador_jogo"):
		if bool(c.get("jogo_ativo")) and not bool(c.get("levantado")):
			return true   # sentado jogando; se levantou no meio da partida, o clique é do rádio
	for c in get_tree().get_nodes_in_group("controlador_tutorial"):
		if bool(c.get("em_andamento")) and not bool(c.get("levantado")):
			return true
	return false

## Gira o dial: ruído de sintonia e uma música nova (de ponto aleatório).
func trocar_musica() -> void:
	if ligado:
		_tocar_proxima()

func ligar() -> void:
	if ligado:
		return
	if _faixas.is_empty():
		push_warning("[Rádio] Nenhuma música em %s (coloque arquivos .ogg/.mp3/.wav lá)." % pasta)
		return
	ligado = true
	Som.sfx("ui_click")
	if esconder_pagode_ao_ligar:
		Som.radio(true)
	_tocar_proxima()
	_atualizar_prompt()
	_atualizar_luz()
	radio_ligou.emit()

func desligar() -> void:
	if not ligado:
		return
	ligado = false
	_id_troca += 1   # cancela uma troca em andamento
	_player.stop()
	_player_sintonia.stop()
	faixa_atual = ""
	Som.sfx("ui_click")
	if esconder_pagode_ao_ligar:
		Som.radio(false)
	_atualizar_prompt()
	_atualizar_luz()
	radio_desligou.emit()

# --- Faixas ---

func _carregar_faixas() -> void:
	_faixas.clear()
	_nomes.clear()
	var dir: String = pasta if pasta.ends_with("/") else pasta + "/"
	if not DirAccess.dir_exists_absolute(dir):
		push_warning("[Rádio] Pasta não encontrada: " + dir)
		return
	var vistos: Dictionary = {}
	for arquivo in DirAccess.get_files_at(dir):
		# Num jogo exportado os arquivos aparecem como "x.mp3.import"/"x.mp3.remap"
		var nome: String = arquivo.trim_suffix(".import").trim_suffix(".remap")
		if vistos.has(nome) or not GerenciadorAudio.EXTENSOES.has(nome.get_extension().to_lower()):
			continue
		vistos[nome] = true
		var s := load(dir + nome) as AudioStream
		if s == null:
			continue
		_sem_loop(s)   # cada música toca uma vez e o rádio passa para a próxima
		_faixas.append(s)
		_nomes.append(nome.get_basename())

func _sem_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED

## Ordem aleatória sem repetir: sorteia todas, toca todas, e só então sorteia de novo.
func _proximo_indice() -> int:
	if _fila.is_empty():
		for i in range(_faixas.size()):
			_fila.append(i)
		_fila.shuffle()
		# a 1ª da nova rodada não pode ser igual à última que acabou de tocar
		if _fila.size() > 1 and _fila[0] == _ultima:
			var troca: int = 1 + randi() % (_fila.size() - 1)
			var t: int = _fila[0]
			_fila[0] = _fila[troca]
			_fila[troca] = t
	return _fila.pop_front()

## `girar_dial` = true (ao ligar ou ao clicar): ruído de sintonia e começo em ponto aleatório.
## false (a música acabou sozinha): a próxima toca normalmente, do começo.
func _tocar_proxima(girar_dial: bool = true) -> void:
	_id_troca += 1
	var id: int = _id_troca
	_player.stop()

	# Ruído de mudar a frequência antes da nova estação
	var s: AudioStream = Som.stream_sfx(sintonia_som) if girar_dial else null
	if s != null:
		_player_sintonia.stream = s
		_player_sintonia.pitch_scale = randf_range(0.9, 1.1)
		_player_sintonia.play()
		await get_tree().create_timer(s.get_length() * 0.85, true).timeout
		if id != _id_troca or not ligado:
			return

	var i: int = _proximo_indice()
	_ultima = i
	faixa_atual = _nomes[i]
	_player.stream = _faixas[i]
	var inicio: float = 0.0
	if girar_dial and comeco_aleatorio:
		var teto: float = _faixas[i].get_length() - segundos_finais_evitados
		if teto > 0.0:
			inicio = randf() * teto
	_player.play(inicio)
	faixa_mudou.emit(faixa_atual)

func _on_faixa_terminou() -> void:
	if ligado:
		_tocar_proxima(false)

# --- Visual ---

func _atualizar_prompt() -> void:
	if label_prompt == null:
		return
	label_prompt.visible = _jogador_na_area
	label_prompt.text = texto_desligar if ligado else texto_ligar

func _atualizar_luz() -> void:
	if luz_ligado != null:
		luz_ligado.visible = ligado
