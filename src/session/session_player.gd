extends RefCounted
## One player in a session: who they are, where their input comes from, and their own state. The deck
## fills in the parts it builds. Scene-free apart from holding those references.

var id := 0
var crew := ""
var source := ""
## In join order: where they stand at the spawn.
var index := 0
var operator: Node3D
var suit: RefCounted
var run_log: RefCounted
var sight: Node
var flashlight: Node3D
var light_on := true
var leave_held := false
var brace_left := 0.0
var noise_left := 0.0


func _init(player_id: int, crew_name: String, input_source: String, join_index: int) -> void:
	id = player_id
	crew = crew_name
	source = input_source
	index = join_index
