extends Node3D
## Rádio do cenário.
## - Chegue perto (Area3D) e aperte E para LIGAR. Enquanto estiver ligado toca as músicas da pasta
##   `pasta` em ordem aleatória (uma depois da outra, sem repetir até todas tocarem), até você
##   apertar E de novo para DESLIGAR.
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
@export var texto_desligar: String = "Pressione E para desligar o rádio"
@export var luz_ligado: Node3D                   # (opcional) aparece só com o rádio ligado

var ligado: bool = false
var faixa_atual: String = ""

var _player: AudioStreamPlayer3D
var _faixas: Array[AudioStream] = []
var _nomes: Array[String] = []
var _fila: Array[int] = []            # ordem aleatória das faixas que ainda vão tocar
var _ultima: int = -1
var _jogador: Node3D
var _jogador_na_area: bool = false

func _ready() -> void:
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
	_player.stop()
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

func _tocar_proxima() -> void:
	var i: int = _proximo_indice()
	_ultima = i
	faixa_atual = _nomes[i]
	_player.stream = _faixas[i]
	_player.play()
	faixa_mudou.emit(faixa_atual)

func _on_faixa_terminou() -> void:
	if ligado:
		_tocar_proxima()

# --- Visual ---

func _atualizar_prompt() -> void:
	if label_prompt == null:
		return
	label_prompt.visible = _jogador_na_area
	label_prompt.text = texto_desligar if ligado else texto_ligar

func _atualizar_luz() -> void:
	if luz_ligado != null:
		luz_ligado.visible = ligado
