extends Node2D

@onready var button_node: Button = $Button
@onready var highlight_node: ColorRect = $Highlight

@export var lane: int = 1

# Configurações de timing em segundos
const PERFECT_WINDOW = 0.05
const GREAT_WINDOW = 0.1
const GOOD_WINDOW = 0.1
const BAD_WINDOW = 0.3
const NOTE_PRELOAD_TIME = 1.0
const MISS_EARLY_OFFSET = 0.1 # segundos antes do BAD_WINDOW para Miss

# Estado
var active_notes: Array = []
var key_pressed: bool = false

func _ready():
    button_node.disabled = true
    button_node.modulate = Color(0.6, 0.6, 0.6)
    button_node.text = str(lane)
    highlight_node.visible = false

func add_note(note: Dictionary):
    note["hit"] = false
    note["hold_active"] = false
    note["sprite"] = null
    note["hold_highlight"] = null
    active_notes.append(note)

    # Sprite da nota
    var note_rect = ColorRect.new()
    note_rect.color = Color(1, 1, 1, 0.5)
    note_rect.size = Vector2(20, 20)
    button_node.add_child(note_rect)
    note_rect.position = (button_node.get_size() - note_rect.size) / 2
    note["sprite"] = note_rect

    # Barra amarela para hold notes
    if note["type"] == "hold":
        var hold_rect = ColorRect.new()
        hold_rect.color = Color(1, 1, 0, 0.5)
        hold_rect.size = Vector2(button_node.get_size().x, 0)
        hold_rect.position = Vector2(button_node.position.x, button_node.position.y + button_node.get_size().y)
        add_child(hold_rect) # independente do Button
        note["hold_highlight"] = hold_rect

# ------------------------------
# Entrada do jogador
func _input(event):
    if event is InputEventKey and not event.echo:
        if event.keycode == _lane_to_keycode():
            key_pressed = event.pressed
            if key_pressed:
                _hit_tap_note() # apenas notas tap são acertadas no momento do clique

func _lane_to_keycode() -> int:
    match lane:
        1: return Key.KEY_KP_1
        2: return Key.KEY_KP_2
        3: return Key.KEY_KP_3
        4: return Key.KEY_KP_4
        5: return Key.KEY_KP_5
        6: return Key.KEY_KP_6
        7: return Key.KEY_KP_7
        8: return Key.KEY_KP_8
        9: return Key.KEY_KP_9
    return 0

# ------------------------------
# Avaliação notas tap
func _hit_tap_note():
    var song_time = get_node("/root/Main").current_time
    for i in range(active_notes.size()):
        var note = active_notes[i]
        if note["type"] != "tap" or note.get("hit", false):
            continue
        var delta_time = song_time - note["time"]
        if delta_time >= -BAD_WINDOW and delta_time <= BAD_WINDOW:
            note["hit"] = true
            _evaluate_timing(delta_time)
            _remove_note_sprite(note)
            active_notes.remove_at(i)
            return

# ------------------------------
func _process(delta):
    var song_time = get_node("/root/Main").current_time

    # --------------------------
    # Processa notas Tap
    for i in range(active_notes.size() - 1, -1, -1):
        var note = active_notes[i]
        if note["type"] == "tap" and not note.get("hit", false):
            if song_time > note["time"] + BAD_WINDOW - MISS_EARLY_OFFSET:
                _evaluate_timing(BAD_WINDOW + 1) # força Miss
                _remove_note_sprite(note)
                active_notes.remove_at(i)
    
    _update_note_sprites()
    _process_hold_notes(delta)


# ------------------------------
# Avaliação notas hold
func _process_hold_notes(_delta):
    var song_time = get_node("/root/Main").current_time
    
    for i in range(active_notes.size() - 1, -1, -1):
        var note = active_notes[i]
        
        if note["type"] != "hold":
            continue
        
        # Calcula quanto tempo da nota já passou
        var elapsed = song_time - note["time"]
        var duration = note["duration"]
        
        # Barra amarela cresce proporcionalmente ao tempo da nota
        var full_size = button_node.get_size()
        if elapsed < 0:
            # Nota ainda não está “acertável”
            note["hold_highlight"].visible = false
        else:
            var ratio = clamp(elapsed / duration, 0, 1)
            note["hold_highlight"].size = Vector2(full_size.x, full_size.y * ratio)
            note["hold_highlight"].position = Vector2(button_node.position.x, button_node.position.y + full_size.y - note["hold_highlight"].size.y)
            note["hold_highlight"].visible = true
        
        # Avaliação de Perfect/Miss baseada em BPM
        if elapsed >= 0 and elapsed <= duration:
            var bpm = note.get("bpm", 120)
            var beat_duration = 60.0 / bpm
            
            # Cria contador de batidas dentro da nota
            if not note.has("last_beat_time"):
                note["last_beat_time"] = 0.0
            
            while note["last_beat_time"] + beat_duration <= elapsed:
                note["last_beat_time"] += beat_duration
                if key_pressed:
                    print("Perfect! (hold)")
                else:
                    print("Miss! (hold)")
        
        # Quando a nota termina, limpa
        if elapsed >= duration:
            _remove_note_sprite(note)
            if note.has("hold_highlight") and note["hold_highlight"] != null:
                note["hold_highlight"].queue_free()
            active_notes.remove_at(i)

# Avaliação de precisão
func _evaluate_timing(delta_time):
    delta_time = abs(delta_time)
    if delta_time <= PERFECT_WINDOW:
        print("Perfect!")
    elif delta_time <= GREAT_WINDOW:
        print("Great!")
    elif delta_time <= GOOD_WINDOW:
        print("Good!")
    elif delta_time <= BAD_WINDOW:
        print("Bad!")
    else:
        print("Miss!")

# Remove sprite da nota
func _remove_note_sprite(note):
    if note.has("sprite") and note["sprite"] != null:
        note["sprite"].queue_free()
        note["sprite"] = null

# Atualiza notas visuais (crescimento)
func _update_note_sprites():
    var song_time = get_node("/root/Main").current_time
    for note in active_notes:
        if note.has("sprite") and note["sprite"] != null:
            var sprite = note["sprite"]
            var progress = clamp((song_time - (note["time"] - NOTE_PRELOAD_TIME)) / NOTE_PRELOAD_TIME, 0, 1)
            var size = button_node.get_size() * progress
            sprite.size = size
            sprite.position = (button_node.get_size() - size) / 2
