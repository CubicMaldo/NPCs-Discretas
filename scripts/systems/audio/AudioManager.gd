extends Node

## Sistema centralizado de gestión de audio del juego.
## Maneja música de fondo, efectos de sonido (SFX), y pooling de AudioStreamPlayer.

signal music_changed(track_name: String)
signal sfx_played(sfx_name: String)

## Music players
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var ambient_player: AudioStreamPlayer = AudioStreamPlayer.new()

## Pool de AudioStreamPlayer para SFX
var sfx_pool: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 16

## Catálogo de audio
var music_tracks: Dictionary = {} # track_name -> AudioStream
var sfx_sounds: Dictionary = {} # sfx_name -> AudioStream

## Estado actual
var current_music: String = ""
var current_ambient: String = ""
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.6

## Configuración
var music_enabled: bool = true
var sfx_enabled: bool = true


func _ready() -> void:
	print("[AudioManager] Inicializando...")
	add_to_group("audio_manager")
	
	# Setup music player
	music_player.name = "MusicPlayer"
	add_child(music_player)
	music_player.bus = "Music"
	music_player.volume_db = linear_to_db(music_volume)
	
	# Setup ambient player
	ambient_player.name = "AmbientPlayer"
	add_child(ambient_player)
	ambient_player.bus = "Ambient"
	ambient_player.volume_db = linear_to_db(ambient_volume)
	
	# Create SFX pool
	_initialize_sfx_pool()
	
	# Load audio resources (placeholder - expandir con recursos reales)
	_load_audio_catalog()
	
	print("[AudioManager] Inicializado con %d SFX players en pool" % MAX_SFX_PLAYERS)


## Inicializa el pool de reproductores SFX
func _initialize_sfx_pool() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		player.volume_db = linear_to_db(sfx_volume)
		add_child(player)
		sfx_pool.append(player)


## Carga el catálogo de audio (placeholder - añadir recursos reales)
func _load_audio_catalog() -> void:
	# TODO: Cargar recursos de audio desde disco
	# Ejemplo:
	# music_tracks["main_theme"] = preload("res://audio/music/main_theme.ogg")
	# sfx_sounds["talk"] = preload("res://audio/sfx/talk.wav")
	# sfx_sounds["fight"] = preload("res://audio/sfx/fight.wav")
	pass


## Registra una pista de música
func register_music(track_name: String, audio_stream: AudioStream) -> void:
	music_tracks[track_name] = audio_stream
	print("[AudioManager] Música registrada: %s" % track_name)


## Registra un efecto de sonido
func register_sfx(sfx_name: String, audio_stream: AudioStream) -> void:
	sfx_sounds[sfx_name] = audio_stream
	print("[AudioManager] SFX registrado: %s" % sfx_name)


## Reproduce música de fondo
func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if not music_enabled:
		return
	
	if not music_tracks.has(track_name):
		push_warning("AudioManager: Música '%s' no encontrada" % track_name)
		return
	
	# Fade out current music
	if music_player.playing and fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, fade_duration)
		tween.tween_callback(func():
			_start_music_track(track_name, fade_duration)
		)
	else:
		_start_music_track(track_name, fade_duration)


## Inicia reproducción de pista de música
func _start_music_track(track_name: String, fade_duration: float) -> void:
	music_player.stream = music_tracks[track_name]
	music_player.play()
	current_music = track_name
	music_changed.emit(track_name)
	
	# Fade in
	if fade_duration > 0:
		music_player.volume_db = -80
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), fade_duration)


## Detiene la música
func stop_music(fade_duration: float = 1.0) -> void:
	if not music_player.playing:
		return
	
	if fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, fade_duration)
		tween.tween_callback(func():
			music_player.stop()
			current_music = ""
		)
	else:
		music_player.stop()
		current_music = ""


## Reproduce un efecto de sonido
func play_sfx(sfx_name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	if not sfx_enabled:
		return
	
	if not sfx_sounds.has(sfx_name):
		push_warning("AudioManager: SFX '%s' no encontrado" % sfx_name)
		return
	
	var player = _get_available_sfx_player()
	if not player:
		# Pool agotado, interrumpir el más antiguo
		player = sfx_pool[0]
		player.stop()
	
	player.stream = sfx_sounds[sfx_name]
	player.volume_db = linear_to_db(sfx_volume * volume_scale)
	player.pitch_scale = pitch_scale
	player.play()
	
	sfx_played.emit(sfx_name)


## Reproduce SFX en una posición 2D (placeholder - requiere AudioStreamPlayer2D)
func play_sfx_at_position(sfx_name: String, _position: Vector2, volume_scale: float = 1.0) -> void:
	# TODO: Implementar con AudioStreamPlayer2D para audio posicional
	# Por ahora, usa el SFX normal
	play_sfx(sfx_name, volume_scale)


## Obtiene un reproductor SFX disponible del pool
func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	return null


## Reproduce audio ambiental (loops)
func play_ambient(ambient_name: String, fade_duration: float = 2.0) -> void:
	if not music_enabled:
		return
	
	if not music_tracks.has(ambient_name):
		push_warning("AudioManager: Ambiente '%s' no encontrado" % ambient_name)
		return
	
	if ambient_player.playing and fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80, fade_duration)
		tween.tween_callback(func():
			_start_ambient_track(ambient_name, fade_duration)
		)
	else:
		_start_ambient_track(ambient_name, fade_duration)


func _start_ambient_track(ambient_name: String, fade_duration: float) -> void:
	ambient_player.stream = music_tracks[ambient_name]
	ambient_player.play()
	current_ambient = ambient_name
	
	if fade_duration > 0:
		ambient_player.volume_db = -80
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", linear_to_db(ambient_volume), fade_duration)


## Detiene el ambiente
func stop_ambient(fade_duration: float = 2.0) -> void:
	if not ambient_player.playing:
		return
	
	if fade_duration > 0:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80, fade_duration)
		tween.tween_callback(func():
			ambient_player.stop()
			current_ambient = ""
		)
	else:
		ambient_player.stop()
		current_ambient = ""


## Ajusta volumen de música
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)


## Ajusta volumen de SFX
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in sfx_pool:
		player.volume_db = linear_to_db(sfx_volume)


## Ajusta volumen de ambiente
func set_ambient_volume(volume: float) -> void:
	ambient_volume = clamp(volume, 0.0, 1.0)
	ambient_player.volume_db = linear_to_db(ambient_volume)


## Toggle música on/off
func toggle_music(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled:
		stop_music(0.5)


## Toggle SFX on/off
func toggle_sfx(enabled: bool) -> void:
	sfx_enabled = enabled


## Detiene todos los sonidos
func stop_all() -> void:
	stop_music(0.5)
	stop_ambient(0.5)
	for player in sfx_pool:
		player.stop()


## DEBUG: Imprime estado del audio
func debug_print_state() -> void:
	print("\n[AudioManager] Estado:")
	print("  Música actual: ", current_music if current_music != "" else "ninguna")
	print("  Ambiente actual: ", current_ambient if current_ambient != "" else "ninguno")
	print("  SFX activos: ", _count_active_sfx())
	print("  Volumen música: %.2f" % music_volume)
	print("  Volumen SFX: %.2f" % sfx_volume)
	print("  Música habilitada: ", music_enabled)
	print("  SFX habilitado: ", sfx_enabled)


func _count_active_sfx() -> int:
	var count = 0
	for player in sfx_pool:
		if player.playing:
			count += 1
	return count
