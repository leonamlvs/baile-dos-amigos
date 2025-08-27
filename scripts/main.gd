extends Node2D

@export var pad_scene: PackedScene
@export var grid_size: Vector2 = Vector2(3, 3)
@export var spacing: Vector2 = Vector2(120, 120)
@export var json_path: String = "res://assets/songs/song.json"

var pads: Array = []
var notes: Array = []
var current_time: float = 0.0
@onready var audio: AudioStreamPlayer = $Audio

func _ready():
	_generate_pads()
	_load_notes()
	if audio.stream != null:
		audio.play()

func _process(delta):
	current_time += delta
	_send_notes_to_pads()

# ------------------------------
# Geração automática do grid 3x3
func _generate_pads():
	var viewport_size = get_viewport().get_visible_rect().size
	var total_width = (grid_size.x - 1) * spacing.x
	var total_height = (grid_size.y - 1) * spacing.y
	var start_pos = Vector2(
		(viewport_size.x - total_width) / 2,
		(viewport_size.y - total_height) / 2
	)
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pad = pad_scene.instantiate()
			
			# Calcula lane de acordo com o layout do numpad
			pad.lane = (grid_size.y - 1 - y) * grid_size.x + x + 1
			
			# Posição: inverte verticalmente
			pad.position = start_pos + Vector2(x * spacing.x, y * spacing.y)
			
			$Pads.add_child(pad)
			pads.append(pad)
			print("Instanciado pad lane ", pad.lane, " em ", pad.position)

# ------------------------------
# Carrega notas do JSON
func _load_notes():
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file:
		var data_text = file.get_as_text()
		file.close()
		
		var data_result = JSON.parse_string(data_text)
		if typeof(data_result) == TYPE_DICTIONARY:
			var song_data = data_result
			notes = song_data.get("notes", [])
			var song_path = song_data.get("song", "")
			if song_path != "":
				audio.stream = load(song_path)
		else:
			push_error("Falha ao parsear JSON: " + str(data_result))


# ------------------------------
# Envia notas aos pads quando próximas
func _send_notes_to_pads():
	for note in notes:
		if not note.has("sent") and note["time"] <= current_time + 2.0:
			var pad = pads[note["lane"] - 1]
			pad.add_note(note)
			note["sent"] = true
