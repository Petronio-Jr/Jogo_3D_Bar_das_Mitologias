class_name Configuracoes
extends RefCounted
## Opções do jogador (áudio, gráficos, controles, jogo). Salvas em user://opcoes.cfg.
## Os valores PADRÃO dos gráficos são ALTOS (MSAA 4x, resolução 100%, VSync, 60 FPS).

const ARQUIVO: String = "user://opcoes.cfg"
const FPS_OPCOES: Array[int] = [0, 30, 60, 90, 120, 144]   # 0 = sem limite
const VELOCIDADE_DEUSES: Array[float] = [1.8, 1.0, 0.5]    # multiplicador do tempo de resposta (lenta, normal, rápida)

const VERSAO: int = 2   # 2 = gráficos com padrão alto
const CHAVES_GRAFICOS: Array[String] = ["vsync", "msaa", "escala_3d", "fps_max"]

static var _dados: Dictionary = {}
static var _padrao: Dictionary = {}
static var _carregado: bool = false

static func _raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root

static func _modo_tela_atual() -> int:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN: return 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: return 2
	return 0

static func _indice_fps(v: int) -> int:
	var i: int = FPS_OPCOES.find(v)
	return i if i != -1 else 0

static func _montar_padrao() -> void:
	_padrao = {
		"vol_geral": 1.0, "vol_musica": 1.0, "vol_pagode": 1.0, "vol_efeitos": 1.0, "vol_vozes": 1.0, "mudo": false,
		"modo_tela": _modo_tela_atual(),
		# Gráficos: padrão ALTO (MSAA 4x, resolução 100%, VSync ligado, FPS máx. 60)
		"vsync": true,
		"msaa": 2,
		"escala_3d": 1.0,
		"fps_max": FPS_OPCOES.find(60),
		"mostrar_fps": false,
		"sens": 1.0, "inverter_y": false,
		"vel_deuses": 1, "combos_deuses": true, "mostrar_cartas_deuses": false,
	}

static func garantir() -> void:
	if _carregado:
		return
	_carregado = true
	_montar_padrao()
	_dados = _padrao.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	# Arquivos antigos (sem versão) guardaram os gráficos baixos: ignora só esses valores
	var versao: int = int(cfg.get_value("meta", "versao", 0))
	for k in _padrao.keys():
		if versao < VERSAO and k in CHAVES_GRAFICOS:
			continue
		if cfg.has_section_key("opcoes", k):
			var v = cfg.get_value("opcoes", k)
			var padrao_v = _padrao[k]
			if typeof(padrao_v) == TYPE_BOOL:
				_dados[k] = bool(v)
			elif typeof(padrao_v) == TYPE_INT:
				_dados[k] = int(v)
			elif typeof(padrao_v) == TYPE_FLOAT:
				_dados[k] = float(v)

static func obter(chave: String):
	garantir()
	return _dados.get(chave, _padrao.get(chave))

static func definir(chave: String, valor) -> void:
	garantir()
	_dados[chave] = valor
	salvar()

static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "versao", VERSAO)
	for k in _dados.keys():
		cfg.set_value("opcoes", k, _dados[k])
	cfg.save(ARQUIVO)

static func restaurar() -> void:
	garantir()
	_dados = _padrao.duplicate()
	salvar()
	aplicar_tudo()

# --- Atalhos usados pelo resto do jogo ---

## Volume (0..1) -> dB. 0 = mudo.
static func db(chave: String) -> float:
	var v: float = float(obter(chave))
	return -80.0 if v <= 0.001 else linear_to_db(v)

static func sens() -> float:
	return float(obter("sens"))

static func sinal_y() -> float:
	return -1.0 if bool(obter("inverter_y")) else 1.0

static func mult_velocidade_deuses() -> float:
	return VELOCIDADE_DEUSES[clampi(int(obter("vel_deuses")), 0, VELOCIDADE_DEUSES.size() - 1)]

# --- Aplicar ---

static func aplicar_tudo() -> void:
	aplicar_audio()
	aplicar_graficos()

static func aplicar_audio() -> void:
	var master: float = -80.0 if bool(obter("mudo")) else db("vol_geral")
	AudioServer.set_bus_volume_db(0, master)
	var m := Som.g()   # os barramentos Musica/Pagode/SFX/Voz leem os volumes daqui
	if m != null:
		m.reaplicar_volumes()

static func aplicar_graficos() -> void:
	var raiz: Window = _raiz()
	var modo: int = int(obter("modo_tela"))
	if modo != _modo_tela_atual():
		match modo:
			0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(obter("vsync")) else DisplayServer.VSYNC_DISABLED)
	raiz.msaa_3d = clampi(int(obter("msaa")), 0, 3) as Viewport.MSAA
	raiz.scaling_3d_scale = clampf(float(obter("escala_3d")), 0.5, 1.0)
	Engine.max_fps = FPS_OPCOES[clampi(int(obter("fps_max")), 0, FPS_OPCOES.size() - 1)]

	var existente: Node = raiz.get_node_or_null("MostradorFps")
	if bool(obter("mostrar_fps")):
		if existente == null:
			raiz.add_child.call_deferred(MostradorFps.new())
	elif existente != null:
		existente.queue_free()
