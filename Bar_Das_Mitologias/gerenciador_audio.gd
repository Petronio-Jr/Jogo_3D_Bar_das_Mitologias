class_name GerenciadorAudio
extends Node
## Cérebro do áudio do jogo. Não precisa ser Autoload: o `Som` (som.gd) cria este nó
## sozinho na primeira vez que alguém pede um som.
##
## Barramentos (criados automaticamente): Musica, Pagode, SFX, Voz.
## Arquivos: res://audio/<subpasta>/<nome>.ogg|mp3|wav (a extensão é descoberta sozinha).
##   audio/sfx/          efeitos (carta_jogar, porta_abrir, ...)
##   audio/musica/       musica_menu, musica_jogo
##   audio/pagode/       TODAS as músicas aqui entram numa playlist aleatória de fundo
##   audio/voz_ahpuch/   fala_01, fala_02, ... (opcional: voz de cada fala do Ah Puch)

# ------------------------------------------------------------------ AJUSTES
# Volumes em dB (0 = original, -6 = metade do "volume", -20 = bem baixinho).
const VOLUME_MUSICA_DB: float = -8.0
const VOLUME_SFX_DB: float = 0.0
const VOLUME_VOZ_DB: float = 0.0
## Pagode de fundo: "baixinho" andando pelo bar e mais baixinho ainda jogando.
const PAGODE_PASSEIO_DB: float = -17.0
const PAGODE_PARTIDA_DB: float = -16.0
## false = durante a partida toca SÓ o pagode (sem a música de jogo por cima)
const MUSICA_NA_PARTIDA: bool = false
## Sons de cartas e efeitos de carta ficam mais baixos que o resto
const VOLUME_CARTAS_DB: float = -10.0

const PASTA: String = "res://audio/"
const EXTENSOES: Array[String] = ["ogg", "mp3", "wav"]
const TAMANHO_POOL_SFX: int = 12
const TECLA_MUDO_MUSICA: Key = KEY_M     # liga/desliga música e pagode
const CUTOFF_LIVRE: float = 20500.0

var _cache: Dictionary = {}
var _avisados: Dictionary = {}

var _musica: Array[AudioStreamPlayer] = []
var _musica_ativa: int = 0
var _musica_atual: String = ""
var _tweens_musica: Dictionary = {}

var _pagode: AudioStreamPlayer
var _pagode_ligado: bool = false
var _pagode_pausado: bool = false
var _pagode_nivel_db: float = PAGODE_PASSEIO_DB
var _playlist: Array[AudioStream] = []
var _indice_playlist: int = -1
var _primeira_faixa: bool = true
var _tween_pagode: Tween
var _tween_nivel_pagode: Tween

var _voz: AudioStreamPlayer
var _blip: AudioStreamPlayer
var _pool_sfx: Array[AudioStreamPlayer] = []
var _proximo_sfx: int = 0

var _duck_db: float = 0.0
var _tween_duck: Tween
var _tween_tontura: Tween
var _mudo_musica: bool = false


func _init() -> void:
	name = "GerenciadorAudio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_criar_barramentos()
	_criar_players()


func _ready() -> void:
	_aplicar_volumes()

# Vigia: se a música de fundo parar sozinha (acabou, trocou de faixa...), religa.
var _vigia: float = 0.0

func _process(delta: float) -> void:
	_vigia += delta
	if _vigia < 1.0:
		return
	_vigia = 0.0
	if _musica_atual != "":
		var p: AudioStreamPlayer = _musica[_musica_ativa]
		if p.stream != null and not p.playing:
			p.play()
			_novo_tween_musica(p).tween_property(p, "volume_db", 0.0, 1.0)
	if _pagode_ligado and not _pagode_pausado and not _pagode.stream_paused and not _pagode.playing:
		_tocar_proxima_faixa(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TECLA_MUDO_MUSICA:
		_mudo_musica = not _mudo_musica
		_aplicar_volumes()

# ------------------------------------------------------------------ SETUP

func _criar_barramentos() -> void:
	for nome in ["Musica", "Pagode", "SFX", "Voz"]:
		if AudioServer.get_bus_index(nome) == -1:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nome)
			AudioServer.set_bus_send(i, "Master")
	# Filtro passa-baixa nas músicas: "abafa" o som quando o jogador está bêbado
	for nome in ["Musica", "Pagode"]:
		var i: int = AudioServer.get_bus_index(nome)
		if AudioServer.get_bus_effect_count(i) == 0:
			var f := AudioEffectLowPassFilter.new()
			f.cutoff_hz = CUTOFF_LIVRE
			AudioServer.add_bus_effect(i, f)

func _criar_players() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Musica"
		p.volume_db = -60.0
		add_child(p)
		_musica.append(p)
	_pagode = AudioStreamPlayer.new()
	_pagode.bus = "Pagode"
	add_child(_pagode)
	_pagode.finished.connect(_on_pagode_terminou)

	_voz = AudioStreamPlayer.new()
	_voz.bus = "Voz"
	add_child(_voz)
	_blip = AudioStreamPlayer.new()
	_blip.bus = "Voz"
	add_child(_blip)

	for i in TAMANHO_POOL_SFX:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_sfx.append(p)

func _aplicar_volumes() -> void:
	var mudo: float = -80.0
	_set_bus("Musica", mudo if _mudo_musica else VOLUME_MUSICA_DB + _duck_db)
	_set_bus("Pagode", mudo if _mudo_musica else _pagode_nivel_db + _duck_db)
	_set_bus("SFX", VOLUME_SFX_DB)
	_set_bus("Voz", VOLUME_VOZ_DB)

func _set_bus(nome: String, db: float) -> void:
	var i: int = AudioServer.get_bus_index(nome)
	if i != -1:
		AudioServer.set_bus_volume_db(i, db)

# ------------------------------------------------------------------ CARREGAR

## Procura res://audio/<subpasta>/<nome>.(ogg|mp3|wav). Devolve null (e avisa 1x) se não existir.
func carregar(subpasta: String, nome: String) -> AudioStream:
	var chave: String = subpasta + "/" + nome
	if _cache.has(chave):
		return _cache[chave]
	var s: AudioStream = null
	for ext in EXTENSOES:
		var caminho: String = "%s%s/%s.%s" % [PASTA, subpasta, nome, ext]
		if ResourceLoader.exists(caminho):
			s = load(caminho) as AudioStream
			break
	if s == null and not _avisados.has(chave):
		_avisados[chave] = true
		push_warning("[Áudio] Arquivo não encontrado: %s%s/%s.(ogg|mp3|wav)" % [PASTA, subpasta, nome])
	_cache[chave] = s
	return s

func _loop(s: AudioStream, ligado: bool) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = ligado
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = ligado
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if ligado:
			var bytes: int = (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / bytes
		else:
			w.loop_mode = AudioStreamWAV.LOOP_DISABLED

# ------------------------------------------------------------------ SFX

## Toca um efeito (2D, sem posição). `variacao_pitch` = 0.1 varia o tom ±10% (evita repetição chata).
func sfx(nome: String, volume_db: float = 0.0, variacao_pitch: float = 0.0, atraso: float = 0.0) -> void:
	if not is_inside_tree():
		return
	if atraso > 0.0:
		get_tree().create_timer(atraso).timeout.connect(sfx.bind(nome, volume_db, variacao_pitch, 0.0))
		return
	var s: AudioStream = carregar("sfx", nome)
	if s == null:
		return
	var p: AudioStreamPlayer = _player_livre()
	p.stream = s
	if nome.begins_with("carta_") or nome.begins_with("efeito_"):
		volume_db += VOLUME_CARTAS_DB
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-variacao_pitch, variacao_pitch)
	p.play()

func _player_livre() -> AudioStreamPlayer:
	for p in _pool_sfx:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _pool_sfx[_proximo_sfx]
	_proximo_sfx = (_proximo_sfx + 1) % _pool_sfx.size()
	return p

## Efeito posicional (vem de um ponto do mundo 3D).
func sfx_3d(nome: String, posicao: Vector3, volume_db: float = 0.0, unidade: float = 4.0) -> void:
	var s: AudioStream = carregar("sfx", nome)
	var cena: Node = get_tree().current_scene if is_inside_tree() else null
	if s == null or cena == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = unidade
	cena.add_child(p)
	p.global_position = posicao
	p.finished.connect(p.queue_free)
	p.play()

# ------------------------------------------------------------------ MÚSICA (menu / jogo)

## Troca a música com crossfade. `nome` = arquivo em audio/musica/. "" = só para a atual.
func musica(nome: String, fade: float = 1.5) -> void:
	if not is_inside_tree() or nome == _musica_atual:
		return
	_musica_atual = nome
	var velho: AudioStreamPlayer = _musica[_musica_ativa]
	_musica_ativa = 1 - _musica_ativa
	var novo: AudioStreamPlayer = _musica[_musica_ativa]

	if velho.playing:
		var tv: Tween = _novo_tween_musica(velho)
		tv.tween_property(velho, "volume_db", -60.0, fade)
		tv.tween_callback(velho.stop)

	if nome == "":
		return
	var s: AudioStream = carregar("musica", nome)
	if s == null:
		return
	_loop(s, true)
	novo.stream = s
	novo.volume_db = -60.0
	novo.play()
	_novo_tween_musica(novo).tween_property(novo, "volume_db", 0.0, fade)

func _novo_tween_musica(p: AudioStreamPlayer) -> Tween:
	if _tweens_musica.has(p) and (_tweens_musica[p] as Tween).is_valid():
		(_tweens_musica[p] as Tween).kill()
	var t: Tween = create_tween()
	_tweens_musica[p] = t
	return t

# ------------------------------------------------------------------ PAGODE DE FUNDO

## Liga a playlist de pagode (aleatória, em sequência). `nivel_db` = volume do pagode.
func pagode_ligar(nivel_db: float = PAGODE_PASSEIO_DB, fade: float = 3.0) -> void:
	if not is_inside_tree():
		return
	pagode_nivel(nivel_db, fade)
	if _pagode_ligado:
		return
	if _playlist.is_empty():
		_montar_playlist()
	if _playlist.is_empty():
		if not _avisados.has("pagode"):
			_avisados["pagode"] = true
			push_warning("[Áudio] Nenhuma música em %spagode/ — coloque seus arquivos .ogg/.mp3/.wav lá." % PASTA)
		return
	_pagode_ligado = true
	_pagode_pausado = false
	_tocar_proxima_faixa(fade)

func pagode_desligar(fade: float = 2.0) -> void:
	_pagode_ligado = false
	if _tween_pagode != null and _tween_pagode.is_valid():
		_tween_pagode.kill()
	if _pagode.playing:
		_tween_pagode = create_tween()
		_tween_pagode.tween_property(_pagode, "volume_db", -60.0, fade)
		_tween_pagode.tween_callback(_pagode.stop)

## Muda o volume do pagode com suavidade (passeio -> partida).
func pagode_nivel(db: float, tempo: float = 2.0) -> void:
	if _tween_nivel_pagode != null and _tween_nivel_pagode.is_valid():
		_tween_nivel_pagode.kill()
	_tween_nivel_pagode = create_tween()
	_tween_nivel_pagode.tween_method(_set_nivel_pagode, _pagode_nivel_db, db, maxf(tempo, 0.01))

## Pausa com fade (ex.: Anubis apaga as luzes).
func pagode_pausar(fade: float = 0.8) -> void:
	if not _pagode_ligado or _pagode_pausado:
		return
	_pagode_pausado = true
	if _tween_pagode != null and _tween_pagode.is_valid():
		_tween_pagode.kill()
	_tween_pagode = create_tween()
	_tween_pagode.tween_property(_pagode, "volume_db", -60.0, fade)
	_tween_pagode.tween_callback(func(): _pagode.stream_paused = true)

func pagode_retomar(fade: float = 2.0) -> void:
	if not _pagode_ligado or not _pagode_pausado:
		return
	_pagode_pausado = false
	_pagode.stream_paused = false
	if _tween_pagode != null and _tween_pagode.is_valid():
		_tween_pagode.kill()
	_tween_pagode = create_tween()
	_tween_pagode.tween_property(_pagode, "volume_db", 0.0, fade)

func _montar_playlist() -> void:
	_playlist.clear()
	var vistos: Dictionary = {}
	for arquivo in DirAccess.get_files_at(PASTA + "pagode"):
		# Num jogo exportado os arquivos aparecem como "x.ogg.import"/"x.ogg.remap"
		var nome: String = arquivo.trim_suffix(".import").trim_suffix(".remap")
		if vistos.has(nome) or not EXTENSOES.has(nome.get_extension().to_lower()):
			continue
		vistos[nome] = true
		var s := load(PASTA + "pagode/" + nome) as AudioStream
		if s != null:
			_loop(s, false)   # cada faixa toca uma vez e a playlist segue
			_playlist.append(s)
	_playlist.shuffle()
	_indice_playlist = -1
	if _playlist.size() == 1:
		_loop(_playlist[0], true)   # uma faixa só: repete sem emendas

func _tocar_proxima_faixa(fade: float = 0.0) -> void:
	if _playlist.is_empty():
		return
	_indice_playlist = (_indice_playlist + 1) % _playlist.size()
	_pagode.stream = _playlist[_indice_playlist]
	_pagode.volume_db = -60.0 if fade > 0.0 else 0.0
	# Na 1ª vez começa num ponto aleatório: parece um rádio que já estava ligado
	var inicio: float = 0.0
	if _primeira_faixa:
		_primeira_faixa = false
		inicio = randf() * minf(_pagode.stream.get_length() * 0.5, 60.0)
	_pagode.play(inicio)
	if fade > 0.0:
		if _tween_pagode != null and _tween_pagode.is_valid():
			_tween_pagode.kill()
		_tween_pagode = create_tween()
		_tween_pagode.tween_property(_pagode, "volume_db", 0.0, fade)

func _on_pagode_terminou() -> void:
	if _pagode_ligado and not _pagode_pausado:
		_tocar_proxima_faixa()

# ------------------------------------------------------------------ VOZ / FALAS

func voz(stream: AudioStream) -> void:
	if stream == null or not is_inside_tree():
		return
	_voz.stream = stream
	_voz.play()

func parar_voz() -> void:
	_voz.stop()

## "Blip" de cada letra do Ah Puch, em tom grave com variação.
func blip(nome: String = "fala_blip", variacao: float = 0.18) -> void:
	var s: AudioStream = carregar("sfx", nome)
	if s == null or not is_inside_tree():
		return
	_blip.stream = s
	_blip.pitch_scale = 1.0 + randf_range(-variacao, variacao)
	_blip.play()

# ------------------------------------------------------------------ EFEITOS DE MIXAGEM

## Abaixa músicas e pagode (ex.: durante a fala do Ah Puch).
func abafar(db: float = -10.0, tempo: float = 0.6) -> void:
	_mudar_duck(db, tempo)

func soltar(tempo: float = 1.0) -> void:
	_mudar_duck(0.0, tempo)

func _set_nivel_pagode(v: float) -> void:
	_pagode_nivel_db = v
	_aplicar_volumes()

func _set_duck(v: float) -> void:
	_duck_db = v
	_aplicar_volumes()

func _mudar_duck(alvo: float, tempo: float) -> void:
	if _tween_duck != null and _tween_duck.is_valid():
		_tween_duck.kill()
	_tween_duck = create_tween()
	_tween_duck.tween_method(_set_duck, _duck_db, alvo, maxf(tempo, 0.01))

## Cerveja: a música fica "abafada" (passa-baixa) enquanto dura a tontura.
func tontura(duracao: float, forca: float) -> void:
	var alvo: float = lerpf(2500.0, 450.0, clampf(forca / 4.0, 0.0, 1.0))
	if _tween_tontura != null and _tween_tontura.is_valid():
		_tween_tontura.kill()
	_tween_tontura = create_tween()
	_tween_tontura.tween_method(_set_cutoff, _cutoff_atual(), alvo, 1.0)
	_tween_tontura.tween_interval(maxf(duracao - 4.0, 0.0))
	_tween_tontura.tween_method(_set_cutoff, alvo, CUTOFF_LIVRE, 3.0)

func tontura_fim() -> void:
	if _tween_tontura != null and _tween_tontura.is_valid():
		_tween_tontura.kill()
	_tween_tontura = create_tween()
	_tween_tontura.tween_method(_set_cutoff, _cutoff_atual(), CUTOFF_LIVRE, 1.0)

func _cutoff_atual() -> float:
	var i: int = AudioServer.get_bus_index("Musica")
	var f := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	return f.cutoff_hz if f != null else CUTOFF_LIVRE

func _set_cutoff(hz: float) -> void:
	for nome in ["Musica", "Pagode"]:
		var i: int = AudioServer.get_bus_index(nome)
		var f := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
		if f != null:
			f.cutoff_hz = hz
