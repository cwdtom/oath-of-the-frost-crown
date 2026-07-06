extends CanvasLayer


var current_health := 0

@onready var life_counter: HBoxContainer = $MarginContainer/LifeCounter


func _ready() -> void:
	current_health = life_counter.get_child_count()
	update_life_counter()


func set_health(value: int) -> void:
	ensure_life_slots(value)
	current_health = max(value, 0)
	update_life_counter()


func decrease_health() -> void:
	set_health(current_health - 1)


func update_life_counter() -> void:
	for i in range(life_counter.get_child_count()):
		var heart := life_counter.get_child(i) as CanvasItem
		heart.visible = i < current_health


func ensure_life_slots(value: int) -> void:
	if life_counter.get_child_count() == 0:
		return

	var target_count = max(value, 0)
	var template := life_counter.get_child(0)
	while life_counter.get_child_count() < target_count:
		life_counter.add_child(template.duplicate())
