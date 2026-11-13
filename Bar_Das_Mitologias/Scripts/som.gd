class_name Som
extends RefCounted
## Atalho estático para o áudio: de qualquer script, basta chamar
##   Som.sfx("carta_jogar")          Som.musica("musica_menu")      Som.pagode_passeio() ...
## O GerenciadorAudio é criado sozinho na primeira chamada (não precisa de Autoload).
## Se um arquivo de som não existir, nada toca (e o Godot avisa uma vez no console).

static var _gerenciador: GerenciadorAudio

## Devolve o gerenciador (cria e coloca na árvore se ainda não existir).
static func g() -> GerenciadorAudio:
	if _gerenciador != null and is_instance_valid(_gerenciador):
		return _gerenciador
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return null
	var existente := arvore.root.get_node_or_null("GerenciadorAudio") as GerenciadorAudio
	if existente != null:
		_gerenciador = existente
		return existente
	_gerenciador = GerenciadorAudio.new()
	# No _ready da cena principal a raiz está "ocupada": adiciona no fim do frame
	arvore.root.add_child.call_deferred(_gerenciador)
	return _gerenciador

# --- Efeitos ---
static func sfx(nome: String, volume_db: float = 0.0, variacao_pitch: float = 0.0, atraso: float = 0.0) -> void:
	var m := g()
	if m != null:
		m.sfx(nome, volume_db, variacao_pitch, atraso)

static func sfx_3d(nome: String, posicao: Vector3, volume_db: float = 0.0) -> void:
	var m := g()
	if m != null:
		m.sfx_3d(nome, posicao, volume_db)

## Stream de um efeito (para quem usa o próprio AudioStreamPlayer3D, como a porta).
static func stream_sfx(nome: String) -> AudioStream:
	var m := g()
	return m.carregar("sfx", nome) if m != null else null

## Voz do Ah Puch para a fala `indice` (0 = 1ª): res://audio/voz_ahpuch/fala_01.(ogg|mp3|wav)
static func stream_fala(indice: int) -> AudioStream:
	var m := g()
	if m == null:
		return null
	var nome: String = "fala_%02d" % (indice + 1)
	for ext in GerenciadorAudio.EXTENSOES:
		if ResourceLoader.exists("%svoz_ahpuch/%s.%s" % [GerenciadorAudio.PASTA, nome, ext]):
			return m.carregar("voz_ahpuch", nome)
	return null   # sem arquivo = usa os "blips" de digitação

# --- Música ---
static func musica(nome: String, fade: float = 1.5) -> void:
	var m := g()
	if m != null:
		m.musica(nome, fade)

static func musica_parar(fade: float = 1.5) -> void:
	musica("", fade)

## Andando pelo bar: só o pagode baixinho.
static func pagode_passeio() -> void:
	var m := g()
	if m != null:
		m.pagode_ligar(GerenciadorAudio.PAGODE_PASSEIO_DB)

## Sentou para jogar: música de jogo + pagode ainda mais baixo ao fundo.
static func partida() -> void:
	var m := g()
	if m != null:
		m.musica("musica_jogo" if GerenciadorAudio.MUSICA_NA_PARTIDA else "", 2.0)
		m.pagode_ligar(GerenciadorAudio.PAGODE_PARTIDA_DB)
		m.pagode_nivel(GerenciadorAudio.PAGODE_PARTIDA_DB, 2.0)

static func pagode_pausar(fade: float = 0.8) -> void:
	var m := g()
	if m != null:
		m.pagode_pausar(fade)

static func pagode_retomar(fade: float = 2.0) -> void:
	var m := g()
	if m != null:
		m.pagode_retomar(fade)

# --- Voz ---
static func voz(stream: AudioStream) -> void:
	var m := g()
	if m != null:
		m.voz(stream)

static func parar_voz() -> void:
	var m := g()
	if m != null:
		m.parar_voz()

static func blip() -> void:
	var m := g()
	if m != null:
		m.blip()

# --- Mixagem ---
static func abafar(db: float = -10.0, tempo: float = 0.6) -> void:
	var m := g()
	if m != null:
		m.abafar(db, tempo)

static func soltar(tempo: float = 1.0) -> void:
	var m := g()
	if m != null:
		m.soltar(tempo)

static func tontura(duracao: float, forca: float) -> void:
	var m := g()
	if m != null:
		m.tontura(duracao, forca)

static func tontura_fim() -> void:
	var m := g()
	if m != null:
		m.tontura_fim()

# --- Rádio do cenário ---
## Liga/desliga o "modo rádio": o pagode de fundo some enquanto o rádio toca.
static func radio(ligado: bool, fade: float = 1.0) -> void:
	var m := g()
	if m != null:
		m.radio_ativar(ligado, fade)
