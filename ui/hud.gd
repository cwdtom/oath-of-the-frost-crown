extends CanvasLayer


@onready var life_counter: HBoxContainer = $MarginContainer/LifeCounter


func present_health(current_health: int, maximum_health: int) -> void:
	ensure_life_slots(maximum_health)
	var displayed_health := clampi(current_health, 0, maximum_health)
	for i in range(life_counter.get_child_count()):
		var heart := life_counter.get_child(i) as CanvasItem
		heart.visible = i < displayed_health


func is_presenting_health(current_health: int, maximum_health: int) -> bool:
	if maximum_health < 0 or life_counter.get_child_count() < maximum_health:
		return false

	var displayed_health := clampi(current_health, 0, maximum_health)
	for i in range(life_counter.get_child_count()):
		var heart := life_counter.get_child(i) as CanvasItem
		if heart.visible != (i < displayed_health):
			return false
	return true


func ensure_life_slots(maximum_health: int) -> void:
	if life_counter.get_child_count() == 0:
		return

	var target_count: int = maxi(maximum_health, 0)
	var template := life_counter.get_child(0)
	while life_counter.get_child_count() < target_count:
		life_counter.add_child(template.duplicate())
